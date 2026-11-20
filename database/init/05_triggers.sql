-- =============================================================================
-- 05_triggers.sql
-- Triggers nghiệp vụ, đồng bộ phi chuẩn hóa, kiểm toán & bất biến tài chính
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tự động cập nhật cột updated_at
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_partner_profiles_updated_at
    BEFORE UPDATE ON partner_profiles FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_hotels_updated_at
    BEFORE UPDATE ON hotels FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_room_types_updated_at
    BEFORE UPDATE ON room_types FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_rooms_updated_at
    BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_room_inventory_updated_at
    BEFORE UPDATE ON room_inventory FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_bookings_updated_at
    BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_reviews_updated_at
    BEFORE UPDATE ON reviews FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();
CREATE TRIGGER trg_support_tickets_updated_at
    BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at();

-- -----------------------------------------------------------------------------
-- 2. trg_validate_and_sync_review (BR13 & BR14)
--    - BEFORE: Chỉ cho phép đánh giá đơn COMPLETED của đúng customer_id & hotel_id
--    - AFTER : Đồng bộ hotels.avg_rating và hotels.review_count từ review VISIBLE
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_review_before()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT id, customer_id, hotel_id, status
      INTO v_booking
      FROM bookings
     WHERE id = NEW.booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'REVIEW_BOOKING_NOT_FOUND' USING ERRCODE = 'P0001';
    END IF;

    IF v_booking.status <> 'COMPLETED' THEN
        RAISE EXCEPTION 'REVIEW_REQUIRES_COMPLETED_BOOKING'
            USING ERRCODE = 'P0001',
                  DETAIL = format('Chỉ được đánh giá đơn đã COMPLETED (hiện tại: %s).', v_booking.status);
    END IF;

    IF NEW.customer_id <> v_booking.customer_id THEN
        RAISE EXCEPTION 'REVIEW_CUSTOMER_MISMATCH' USING ERRCODE = 'P0001';
    END IF;

    IF NEW.hotel_id <> v_booking.hotel_id THEN
        RAISE EXCEPTION 'REVIEW_HOTEL_MISMATCH' USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_recompute_hotel_rating(p_hotel_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Khóa dòng hotels trước khi đọc reviews để tránh lost update khi nhiều review cùng cập nhật
    PERFORM 1 FROM hotels WHERE id = p_hotel_id FOR UPDATE;

    UPDATE hotels h
       SET avg_rating = sub.avg_val,
           review_count = sub.cnt_val
      FROM (
          SELECT COALESCE(ROUND(AVG(r.rating)::NUMERIC, 2), 0.00)::NUMERIC(3, 2) AS avg_val,
                 COUNT(*)::INT AS cnt_val
            FROM reviews r
           WHERE r.hotel_id = p_hotel_id
             AND r.moderation_status = 'VISIBLE'
      ) AS sub
     WHERE h.id = p_hotel_id;
END;
$$;

CREATE OR REPLACE FUNCTION fn_sync_hotel_rating_after()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM fn_recompute_hotel_rating(OLD.hotel_id);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.hotel_id IS DISTINCT FROM NEW.hotel_id THEN
            PERFORM fn_recompute_hotel_rating(OLD.hotel_id);
        END IF;
        PERFORM fn_recompute_hotel_rating(NEW.hotel_id);
        RETURN NEW;
    ELSE
        PERFORM fn_recompute_hotel_rating(NEW.hotel_id);
        RETURN NEW;
    END IF;
END;
$$;

CREATE TRIGGER trg_validate_and_sync_review_before
    BEFORE INSERT OR UPDATE ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_validate_review_before();

CREATE TRIGGER trg_validate_and_sync_review
    AFTER INSERT OR UPDATE OF rating, moderation_status, hotel_id OR DELETE ON reviews
    FOR EACH ROW EXECUTE FUNCTION fn_sync_hotel_rating_after();

-- -----------------------------------------------------------------------------
-- 3. trg_audit_log_changes: Tự động ghi JSONB old_data / new_data vào audit_logs
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_log_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor_id   BIGINT;
    v_entity_id  VARCHAR(64);
    v_old_json   JSONB;
    v_new_json   JSONB;
    v_action     VARCHAR(50);
BEGIN
    v_actor_id := NULLIF(current_setting('app.current_actor_id', TRUE), '')::BIGINT;

    IF TG_OP = 'INSERT' THEN
        v_entity_id := NEW.id::TEXT;
        v_old_json  := NULL;
        v_new_json  := to_jsonb(NEW);
        v_action    := 'INSERT';
    ELSIF TG_OP = 'UPDATE' THEN
        v_entity_id := NEW.id::TEXT;
        v_old_json  := to_jsonb(OLD);
        v_new_json  := to_jsonb(NEW);
        IF TG_TABLE_NAME = 'hotels' THEN
            IF (v_new_json - 'updated_at' - 'avg_rating' - 'review_count')
             = (v_old_json - 'updated_at' - 'avg_rating' - 'review_count') THEN
                RETURN NEW;
            END IF;
        ELSE
            IF (v_new_json - 'updated_at') = (v_old_json - 'updated_at') THEN
                RETURN NEW;
            END IF;
        END IF;
        v_action := 'UPDATE';
    ELSE
        v_entity_id := OLD.id::TEXT;
        v_old_json  := to_jsonb(OLD);
        v_new_json  := NULL;
        v_action    := 'DELETE';
    END IF;

    INSERT INTO audit_logs (actor_id, action, entity_type, entity_id, old_data, new_data)
    VALUES (v_actor_id, v_action, TG_TABLE_NAME, v_entity_id, v_old_json, v_new_json);

    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_audit_log_bookings
    AFTER INSERT OR UPDATE OR DELETE ON bookings
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log_changes();

CREATE TRIGGER trg_audit_log_hotels
    AFTER INSERT OR UPDATE OR DELETE ON hotels
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log_changes();

CREATE TRIGGER trg_audit_log_partner_payouts
    AFTER INSERT OR UPDATE OR DELETE ON partner_payouts
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log_changes();

-- -----------------------------------------------------------------------------
-- 4. trg_validate_support_ticket (BR15): Ticket gắn booking_id phải thuộc khách hoặc đối tác
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_support_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id BIGINT;
    v_partner_id  BIGINT;
BEGIN
    IF NEW.booking_id IS NOT NULL THEN
        SELECT b.customer_id, h.partner_id
          INTO v_customer_id, v_partner_id
          FROM bookings b
          JOIN hotels h ON h.id = b.hotel_id
         WHERE b.id = NEW.booking_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'TICKET_BOOKING_NOT_FOUND' USING ERRCODE = 'P0001';
        END IF;

        IF NEW.customer_id <> v_customer_id AND NEW.customer_id <> v_partner_id THEN
            RAISE EXCEPTION 'TICKET_REQUESTER_NOT_RELATED_TO_BOOKING'
                USING ERRCODE = 'P0001',
                      DETAIL = 'Người gửi ticket không phải khách hàng hoặc đối tác của đơn đặt phòng này.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_support_ticket
    BEFORE INSERT OR UPDATE ON support_tickets
    FOR EACH ROW EXECUTE FUNCTION fn_validate_support_ticket();

-- -----------------------------------------------------------------------------
-- 5. trg_enforce_financial_immutability (BR18): Chống xóa & sửa chứng từ tài chính/audit
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_enforce_financial_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'IMMUTABLE_RECORD_DELETE_FORBIDDEN'
            USING ERRCODE = 'P0003',
                  DETAIL = format('Không được phép xóa vật lý bản ghi trên bảng %s.', TG_TABLE_NAME);
    END IF;

    IF TG_TABLE_NAME IN ('audit_logs', 'payout_items') THEN
        RAISE EXCEPTION 'IMMUTABLE_RECORD_UPDATE_FORBIDDEN'
            USING ERRCODE = 'P0003',
                  DETAIL = format('Không được phép sửa trực tiếp bản ghi trên bảng %s.', TG_TABLE_NAME);
    ELSIF TG_TABLE_NAME = 'payments' THEN
        IF OLD.status IN ('SUCCESS', 'FAILED') THEN
            RAISE EXCEPTION 'IMMUTABLE_FINALIZED_PAYMENT'
                USING ERRCODE = 'P0003',
                      DETAIL = format('Chứng từ thanh toán ở trạng thái %s không được phép chỉnh sửa.', OLD.status);
        END IF;
        IF NEW.booking_id IS DISTINCT FROM OLD.booking_id
           OR NEW.payment_type IS DISTINCT FROM OLD.payment_type
           OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
           OR NEW.amount IS DISTINCT FROM OLD.amount THEN
            RAISE EXCEPTION 'IMMUTABLE_PENDING_PAYMENT_CORE_FIELDS'
                USING ERRCODE = 'P0003',
                      DETAIL = 'Không được sửa booking_id, payment_type, idempotency_key hoặc amount trên thanh toán PENDING.';
        END IF;
    ELSIF TG_TABLE_NAME = 'partner_payouts' THEN
        IF OLD.status IN ('PAID', 'CANCELLED') THEN
            RAISE EXCEPTION 'IMMUTABLE_FINALIZED_PAYOUT'
                USING ERRCODE = 'P0003',
                      DETAIL = format('Phiếu payout ở trạng thái %s không được phép chỉnh sửa.', OLD.status);
        END IF;
        IF NEW.batch_id IS DISTINCT FROM OLD.batch_id
           OR NEW.partner_id IS DISTINCT FROM OLD.partner_id
           OR NEW.gross_amount IS DISTINCT FROM OLD.gross_amount
           OR NEW.commission_total IS DISTINCT FROM OLD.commission_total
           OR NEW.net_payout IS DISTINCT FROM OLD.net_payout THEN
            RAISE EXCEPTION 'IMMUTABLE_PENDING_PAYOUT_AMOUNTS'
                USING ERRCODE = 'P0003',
                      DETAIL = 'Không được sửa số tiền hoặc đối tác trên phiếu payout PENDING; chỉ được cập nhật trạng thái chi trả.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_immutable_payments
    BEFORE UPDATE OR DELETE ON payments
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_financial_immutability();

CREATE TRIGGER trg_immutable_payout_items
    BEFORE UPDATE OR DELETE ON payout_items
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_financial_immutability();

CREATE TRIGGER trg_immutable_partner_payouts
    BEFORE UPDATE OR DELETE ON partner_payouts
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_financial_immutability();

CREATE TRIGGER trg_immutable_audit_logs
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_financial_immutability();

-- -----------------------------------------------------------------------------
-- 6. trg_validate_room_assignment (BR10): Phòng vật lý gán phải AVAILABLE & chưa CHECKED_IN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_room_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_status VARCHAR(20);
BEGIN
    IF NEW.assigned_room_id IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.assigned_room_id IS DISTINCT FROM NEW.assigned_room_id) THEN
        SELECT r.status
          INTO v_room_status
          FROM rooms r
         WHERE r.id = NEW.assigned_room_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'ASSIGNED_ROOM_NOT_FOUND' USING ERRCODE = 'P0001';
        END IF;

        IF v_room_status <> 'AVAILABLE' THEN
            RAISE EXCEPTION 'ASSIGNED_ROOM_NOT_AVAILABLE'
                USING ERRCODE = 'P0002',
                      DETAIL = format('Phòng vật lý id=%s đang ở trạng thái %s, không thể gán.', NEW.assigned_room_id, v_room_status);
        END IF;

        IF EXISTS (
            SELECT 1
              FROM booking_items bi
              JOIN bookings b ON b.id = bi.booking_id
             WHERE bi.assigned_room_id = NEW.assigned_room_id
               AND bi.booking_id <> NEW.booking_id
               AND b.status = 'CHECKED_IN'
        ) THEN
            RAISE EXCEPTION 'ASSIGNED_ROOM_ALREADY_OCCUPIED'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_room_assignment
    BEFORE INSERT OR UPDATE ON booking_items
    FOR EACH ROW EXECUTE FUNCTION fn_validate_room_assignment();
