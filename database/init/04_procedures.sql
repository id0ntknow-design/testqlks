-- =============================================================================
-- 04_procedures.sql
-- Stored Procedures giao dịch nguyên tử:
--   1. sp_create_booking_hold (đa loại phòng JSONB + nạp chồng 1 loại phòng)
--   2. sp_confirm_booking_payment (idempotency_key + chuyển held -> booked)
--   3. sp_cancel_booking (hủy theo chính sách / ngoại lệ + hoàn tồn kho)
--   4. sp_generate_settlement_batch (đối soát hoa hồng & tạo payout không trùng)
--   5. sp_release_expired_holds (giải phóng giữ chỗ hết hạn)
--   6. sp_check_in_booking & sp_check_out_booking (vận hành lưu trú)
-- =============================================================================

CREATE SEQUENCE IF NOT EXISTS seq_booking_code START 1000;
CREATE SEQUENCE IF NOT EXISTS seq_batch_code START 100;

-- -----------------------------------------------------------------------------
-- 1. sp_create_booking_hold: Khóa tồn kho mọi đêm tăng dần & tạo đơn HOLD
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_create_booking_hold(
    IN  p_customer_id  BIGINT,
    IN  p_hotel_id     BIGINT,
    IN  p_items        JSONB,
    IN  p_check_in     DATE,
    IN  p_check_out    DATE,
    IN  p_guest_count  SMALLINT,
    IN  p_promo_code   VARCHAR,
    IN  p_hold_minutes INT,
    OUT p_booking_id   BIGINT,
    OUT p_booking_code VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_hold_mins        INT := COALESCE(p_hold_minutes, 15);
    v_nights           INT;
    v_hotel_ok         BOOLEAN;
    v_commission_rate  NUMERIC(5, 2);
    v_policy_id        BIGINT;
    v_subtotal         NUMERIC(18, 0) := 0;
    v_discount         NUMERIC(18, 0) := 0;
    v_total            NUMERIC(18, 0) := 0;
    v_commission_amt   NUMERIC(18, 0) := 0;
    v_total_capacity   INT := 0;
    v_promo_id         BIGINT := NULL;
    v_promo_type       VARCHAR(20);
    v_promo_value      NUMERIC(18, 2);
    v_promo_max        NUMERIC(18, 0);
    v_promo_min        NUMERIC(18, 0);
    v_item             RECORD;
    v_night_row        RECORD;
    v_locked_nights    INT;
    v_item_room_sum    NUMERIC(18, 0);
    v_line_no          INT := 0;
    v_i                INT;
BEGIN
    PERFORM set_config('app.current_actor_id', p_customer_id::TEXT, TRUE);

    IF p_check_in IS NULL OR p_check_out IS NULL OR p_check_out <= p_check_in THEN
        RAISE EXCEPTION 'CHECK_OUT_MUST_BE_AFTER_CHECK_IN' USING ERRCODE = 'P0001';
    END IF;
    IF p_check_in < CURRENT_DATE THEN
        RAISE EXCEPTION 'CHECK_IN_DATE_IN_PAST' USING ERRCODE = 'P0001';
    END IF;
    IF p_guest_count IS NULL OR p_guest_count <= 0 THEN
        RAISE EXCEPTION 'INVALID_GUEST_COUNT' USING ERRCODE = 'P0001';
    END IF;
    IF v_hold_mins <= 0 THEN
        RAISE EXCEPTION 'INVALID_HOLD_MINUTES' USING ERRCODE = 'P0001';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'INVALID_BOOKING_ITEMS' USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_customer_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'CUSTOMER_NOT_ACTIVE' USING ERRCODE = 'P0001';
    END IF;

    SELECT (h.approval_status = 'APPROVED' AND h.is_active), h.commission_rate
      INTO v_hotel_ok, v_commission_rate
      FROM hotels h
     WHERE h.id = p_hotel_id;

    IF NOT FOUND OR NOT v_hotel_ok THEN
        RAISE EXCEPTION 'HOTEL_NOT_AVAILABLE' USING ERRCODE = 'P0001';
    END IF;

    SELECT cp.id
      INTO v_policy_id
      FROM cancellation_policies cp
     WHERE cp.hotel_id = p_hotel_id
     ORDER BY cp.is_default DESC, cp.id ASC
     LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CANCELLATION_POLICY_MISSING' USING ERRCODE = 'P0001';
    END IF;

    v_nights := (p_check_out - p_check_in);

    -- Khóa tất cả dòng room_inventory liên quan theo thứ tự (room_type_id ASC, stay_date ASC) để chống deadlock
    FOR v_item IN
        SELECT (elem->>'room_type_id')::BIGINT AS room_type_id,
               SUM((elem->>'quantity')::INT)  AS quantity
          FROM jsonb_array_elements(p_items) AS elem
         GROUP BY (elem->>'room_type_id')::BIGINT
         ORDER BY (elem->>'room_type_id')::BIGINT ASC
    LOOP
        IF v_item.room_type_id IS NULL OR v_item.quantity IS NULL OR v_item.quantity <= 0 THEN
            RAISE EXCEPTION 'INVALID_ITEM_QUANTITY' USING ERRCODE = 'P0001';
        END IF;

        PERFORM 1
          FROM room_types rt
         WHERE rt.id = v_item.room_type_id
           AND rt.hotel_id = p_hotel_id
           AND rt.is_active = TRUE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ROOM_TYPE_NOT_IN_HOTEL' USING ERRCODE = 'P0001';
        END IF;

        SELECT v_total_capacity + ((rt.max_adults + rt.max_children) * v_item.quantity)
          INTO v_total_capacity
          FROM room_types rt
         WHERE rt.id = v_item.room_type_id;

        v_locked_nights := 0;
        FOR v_night_row IN
            SELECT ri.stay_date, ri.total_allotment, ri.booked_count, ri.held_count, ri.nightly_price, ri.is_closed
              FROM room_inventory ri
             WHERE ri.room_type_id = v_item.room_type_id
               AND ri.stay_date >= p_check_in
               AND ri.stay_date < p_check_out
             ORDER BY ri.stay_date ASC
             FOR UPDATE
        LOOP
            IF v_night_row.is_closed THEN
                RAISE EXCEPTION 'ROOM_INVENTORY_CLOSED'
                    USING ERRCODE = 'P0002',
                          DETAIL = format('Loại phòng %s đã đóng bán ngày %s.', v_item.room_type_id, v_night_row.stay_date);
            END IF;
            IF (v_night_row.booked_count + v_night_row.held_count + v_item.quantity) > v_night_row.total_allotment THEN
                RAISE EXCEPTION 'INSUFFICIENT_ROOM_INVENTORY'
                    USING ERRCODE = 'P0002',
                          DETAIL = format('Loại phòng %s không đủ %s phòng trống ngày %s.', v_item.room_type_id, v_item.quantity, v_night_row.stay_date);
            END IF;
            v_locked_nights := v_locked_nights + 1;
            v_subtotal := v_subtotal + (v_night_row.nightly_price * v_item.quantity);
        END LOOP;

        IF v_locked_nights <> v_nights THEN
            RAISE EXCEPTION 'MISSING_INVENTORY_CALENDAR'
                USING ERRCODE = 'P0002',
                      DETAIL = format('Loại phòng %s chưa mở đủ lịch quỹ phòng cho %s đêm.', v_item.room_type_id, v_nights);
        END IF;
    END LOOP;

    IF v_total_capacity < p_guest_count THEN
        RAISE EXCEPTION 'EXCEEDS_MAX_OCCUPANCY'
            USING ERRCODE = 'P0001',
                  DETAIL = format('Sức chứa tối đa %s khách không đủ cho %s khách.', v_total_capacity, p_guest_count);
    END IF;

    -- Khóa & tiêu thụ lượt mã khuyến mãi nếu có
    IF p_promo_code IS NOT NULL AND BTRIM(p_promo_code) <> '' THEN
        SELECT p.id, p.discount_type, p.discount_value, p.max_discount_amount, p.min_order_amount
          INTO v_promo_id, v_promo_type, v_promo_value, v_promo_max, v_promo_min
          FROM promotions p
         WHERE p.code = BTRIM(p_promo_code)
           AND p.is_active = TRUE
           AND NOW() BETWEEN p.valid_from AND p.valid_to
           AND p.used_count < p.usage_limit
         FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'PROMO_CODE_INVALID_OR_EXPIRED' USING ERRCODE = 'P0001';
        END IF;
        IF v_subtotal < v_promo_min THEN
            RAISE EXCEPTION 'PROMO_MIN_ORDER_NOT_MET' USING ERRCODE = 'P0001';
        END IF;

        IF v_promo_type = 'FIXED' THEN
            v_discount := LEAST(ROUND(v_promo_value, 0), v_subtotal);
        ELSE
            v_discount := ROUND(v_subtotal * v_promo_value / 100.0, 0);
            IF v_promo_max IS NOT NULL THEN
                v_discount := LEAST(v_discount, v_promo_max);
            END IF;
            v_discount := LEAST(v_discount, v_subtotal);
        END IF;

        UPDATE promotions
           SET used_count = used_count + 1
         WHERE id = v_promo_id;
    END IF;

    v_total := GREATEST(v_subtotal - v_discount, 0);
    v_commission_amt := ROUND(v_subtotal * v_commission_rate / 100.0, 0);
    p_booking_code := 'BK-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('seq_booking_code')::TEXT, 6, '0');

    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount,
        total_amount, commission_amount, hold_expires_at
    )
    VALUES (
        p_booking_code, p_customer_id, p_hotel_id, v_promo_id, v_policy_id,
        p_check_in, p_check_out, p_guest_count, 'HOLD',
        v_commission_rate, v_subtotal, v_discount,
        v_total, v_commission_amt, NOW() + make_interval(mins => v_hold_mins)
    )
    RETURNING id INTO p_booking_id;

    -- Tăng held_count và lưu snapshot giá đêm + tách booking_items mỗi phòng 1 dòng
    FOR v_item IN
        SELECT (elem->>'room_type_id')::BIGINT AS room_type_id,
               SUM((elem->>'quantity')::INT)  AS quantity
          FROM jsonb_array_elements(p_items) AS elem
         GROUP BY (elem->>'room_type_id')::BIGINT
         ORDER BY (elem->>'room_type_id')::BIGINT ASC
    LOOP
        UPDATE room_inventory
           SET held_count = held_count + v_item.quantity,
               updated_at = NOW()
         WHERE room_type_id = v_item.room_type_id
           AND stay_date >= p_check_in
           AND stay_date < p_check_out;

        INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot)
        SELECT p_booking_id, ri.room_type_id, ri.stay_date, v_item.quantity, ri.nightly_price
          FROM room_inventory ri
         WHERE ri.room_type_id = v_item.room_type_id
           AND ri.stay_date >= p_check_in
           AND ri.stay_date < p_check_out
         ORDER BY ri.stay_date ASC;

        SELECT COALESCE(SUM(ri.nightly_price), 0)::NUMERIC(18, 0)
          INTO v_item_room_sum
          FROM room_inventory ri
         WHERE ri.room_type_id = v_item.room_type_id
           AND ri.stay_date >= p_check_in
           AND ri.stay_date < p_check_out;

        FOR v_i IN 1..v_item.quantity LOOP
            v_line_no := v_line_no + 1;
            INSERT INTO booking_items (
                booking_id, line_no, hotel_id, room_type_id, assigned_room_id,
                quantity, nights, unit_price_avg, line_total
            )
            VALUES (
                p_booking_id, v_line_no, p_hotel_id, v_item.room_type_id, NULL,
                1, v_nights, ROUND(v_item_room_sum / v_nights, 0), v_item_room_sum
            );
        END LOOP;
    END LOOP;
END;
$$;

-- Nạp chồng đơn giản 1 loại phòng
CREATE OR REPLACE PROCEDURE sp_create_booking_hold(
    IN  p_customer_id  BIGINT,
    IN  p_hotel_id     BIGINT,
    IN  p_room_type_id BIGINT,
    IN  p_check_in     DATE,
    IN  p_check_out    DATE,
    IN  p_qty          INT,
    IN  p_guest_count  SMALLINT,
    IN  p_promo_code   VARCHAR,
    IN  p_hold_minutes INT,
    OUT p_booking_id   BIGINT,
    OUT p_booking_code VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL sp_create_booking_hold(
        p_customer_id,
        p_hotel_id,
        jsonb_build_array(jsonb_build_object('room_type_id', p_room_type_id, 'quantity', p_qty)),
        p_check_in,
        p_check_out,
        p_guest_count,
        p_promo_code,
        p_hold_minutes,
        p_booking_id,
        p_booking_code
    );
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. sp_confirm_booking_payment: Xác nhận thanh toán chống lặp (idempotency_key)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_confirm_booking_payment(
    IN  p_booking_id      BIGINT,
    IN  p_method          VARCHAR,
    IN  p_idempotency_key VARCHAR,
    OUT p_payment_id      BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_pay RECORD;
    v_booking      RECORD;
    v_bnr          RECORD;
BEGIN
    IF p_idempotency_key IS NULL OR BTRIM(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_REQUIRED' USING ERRCODE = 'P0001';
    END IF;

    SELECT id, booking_id, status
      INTO v_existing_pay
      FROM payments
     WHERE idempotency_key = p_idempotency_key
     FOR UPDATE;

    IF FOUND THEN
        IF v_existing_pay.booking_id <> p_booking_id THEN
            RAISE EXCEPTION 'IDEMPOTENCY_KEY_BOOKING_MISMATCH' USING ERRCODE = 'P0001';
        END IF;
        IF v_existing_pay.status = 'SUCCESS' THEN
            p_payment_id := v_existing_pay.id;
            RETURN;
        ELSIF v_existing_pay.status = 'FAILED' THEN
            RAISE EXCEPTION 'IDEMPOTENCY_KEY_ALREADY_FAILED' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    SELECT id, customer_id, status, total_amount, hold_expires_at
      INTO v_booking
      FROM bookings
     WHERE id = p_booking_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0001';
    END IF;

    PERFORM set_config('app.current_actor_id', v_booking.customer_id::TEXT, TRUE);

    IF v_booking.status NOT IN ('HOLD', 'PENDING_PAYMENT') THEN
        RAISE EXCEPTION 'BOOKING_NOT_PAYABLE_IN_CURRENT_STATUS'
            USING ERRCODE = 'P0001',
                  DETAIL = format('Trạng thái đơn hiện tại là %s.', v_booking.status);
    END IF;

    IF v_booking.hold_expires_at IS NOT NULL AND v_booking.hold_expires_at < NOW() THEN
        RAISE EXCEPTION 'BOOKING_HOLD_EXPIRED' USING ERRCODE = 'P0001';
    END IF;

    -- Khóa room_inventory tăng dần theo (room_type_id, stay_date) rồi chuyển held_count -> booked_count
    FOR v_bnr IN
        SELECT bnr.room_type_id, bnr.stay_date, bnr.quantity
          FROM booking_night_rates bnr
         WHERE bnr.booking_id = p_booking_id
         ORDER BY bnr.room_type_id ASC, bnr.stay_date ASC
    LOOP
        PERFORM 1
          FROM room_inventory ri
         WHERE ri.room_type_id = v_bnr.room_type_id
           AND ri.stay_date = v_bnr.stay_date
         FOR UPDATE;

        UPDATE room_inventory
           SET held_count   = held_count - v_bnr.quantity,
               booked_count = booked_count + v_bnr.quantity,
               updated_at   = NOW()
         WHERE room_type_id = v_bnr.room_type_id
           AND stay_date = v_bnr.stay_date;
    END LOOP;

    IF v_existing_pay.id IS NOT NULL AND v_existing_pay.status = 'PENDING' THEN
        UPDATE payments
           SET method  = p_method,
               amount  = v_booking.total_amount,
               status  = 'SUCCESS',
               paid_at = NOW()
         WHERE id = v_existing_pay.id
         RETURNING id INTO p_payment_id;
    ELSE
        INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at)
        VALUES (p_booking_id, 'CHARGE', p_method, v_booking.total_amount, 'SUCCESS', p_idempotency_key, NOW())
        RETURNING id INTO p_payment_id;
    END IF;

    UPDATE bookings
       SET status = 'CONFIRMED',
           hold_expires_at = NULL
     WHERE id = p_booking_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. sp_cancel_booking: Hủy đơn theo chính sách / ngoại lệ & giải phóng tồn kho
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cancel_booking(
    IN  p_booking_id      BIGINT,
    IN  p_actor_id        BIGINT,
    IN  p_reason          TEXT,
    IN  p_is_exception    BOOLEAN,
    IN  p_idempotency_key VARCHAR,
    OUT p_refund_amount   NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_exception BOOLEAN := COALESCE(p_is_exception, FALSE);
    v_booking      RECORD;
    v_bnr          RECORD;
    v_paid_amt     NUMERIC(18, 0) := 0;
    v_refund_key   VARCHAR(100);
BEGIN
    PERFORM set_config('app.current_actor_id', COALESCE(p_actor_id::TEXT, ''), TRUE);

    SELECT *
      INTO v_booking
      FROM bookings
     WHERE id = p_booking_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0001';
    END IF;

    IF v_booking.status IN ('COMPLETED', 'CANCELLED') THEN
        RAISE EXCEPTION 'BOOKING_CANNOT_BE_CANCELLED'
            USING ERRCODE = 'P0001',
                  DETAIL = format('Không thể hủy đơn ở trạng thái %s.', v_booking.status);
    END IF;

    IF v_booking.status = 'CHECKED_IN' AND NOT v_is_exception THEN
        RAISE EXCEPTION 'CHECKED_IN_REQUIRES_EXCEPTION_CANCEL' USING ERRCODE = 'P0001';
    END IF;

    -- Khóa & hoàn trả tồn phòng theo thứ tự (room_type_id, stay_date)
    FOR v_bnr IN
        SELECT bnr.room_type_id, bnr.stay_date, bnr.quantity
          FROM booking_night_rates bnr
         WHERE bnr.booking_id = p_booking_id
         ORDER BY bnr.room_type_id ASC, bnr.stay_date ASC
    LOOP
        IF v_booking.status IN ('HOLD', 'PENDING_PAYMENT') THEN
            PERFORM 1 FROM room_inventory
             WHERE room_type_id = v_bnr.room_type_id AND stay_date = v_bnr.stay_date FOR UPDATE;
            UPDATE room_inventory
               SET held_count = held_count - v_bnr.quantity,
                   updated_at = NOW()
             WHERE room_type_id = v_bnr.room_type_id AND stay_date = v_bnr.stay_date;
        ELSIF v_booking.status = 'CONFIRMED' THEN
            PERFORM 1 FROM room_inventory
             WHERE room_type_id = v_bnr.room_type_id AND stay_date = v_bnr.stay_date FOR UPDATE;
            UPDATE room_inventory
               SET booked_count = booked_count - v_bnr.quantity,
                   updated_at = NOW()
             WHERE room_type_id = v_bnr.room_type_id AND stay_date = v_bnr.stay_date;
        ELSIF v_booking.status = 'CHECKED_IN' AND v_bnr.stay_date >= GREATEST(CURRENT_DATE, v_booking.check_in_date) THEN
            PERFORM 1 FROM room_inventory
             WHERE room_type_id = v_bnr.room_type_id AND stay_date = v_bnr.stay_date FOR UPDATE;
            UPDATE room_inventory
               SET booked_count = booked_count - v_bnr.quantity,
                   updated_at = NOW()
             WHERE room_type_id = v_bnr.room_type_id AND stay_date = v_bnr.stay_date;
        END IF;
    END LOOP;

    -- Giải phóng phòng vật lý nếu hủy ngoại lệ từ CHECKED_IN
    IF v_booking.status = 'CHECKED_IN' THEN
        UPDATE rooms r
           SET status = 'AVAILABLE'
          FROM booking_items bi
         WHERE bi.booking_id = p_booking_id
           AND bi.assigned_room_id = r.id
           AND r.status = 'OCCUPIED';
    END IF;

    -- Hoàn lượt mã khuyến mãi nếu đơn chưa thanh toán
    IF v_booking.status IN ('HOLD', 'PENDING_PAYMENT') AND v_booking.promotion_id IS NOT NULL THEN
        UPDATE promotions
           SET used_count = GREATEST(used_count - 1, 0)
         WHERE id = v_booking.promotion_id;
    END IF;

    SELECT COALESCE(r.paid_amount, 0), COALESCE(r.refundable_amount, 0)
      INTO v_paid_amt, p_refund_amount
      FROM fn_calculate_refund_amount(p_booking_id, NOW()) AS r;

    IF v_is_exception THEN
        p_refund_amount := v_paid_amt;
    END IF;

    IF p_refund_amount > 0 THEN
        v_refund_key := COALESCE(
            NULLIF(BTRIM(p_idempotency_key), ''),
            'refund-' || p_booking_id::TEXT || '-' || REPLACE(clock_timestamp()::TEXT, ' ', 'T')
        );
        INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at)
        VALUES (p_booking_id, 'REFUND', 'INTERNAL_ADJUSTMENT', p_refund_amount, 'SUCCESS', v_refund_key, NOW());
    ELSE
        p_refund_amount := 0;
    END IF;

    UPDATE bookings
       SET status        = 'CANCELLED',
           cancelled_at  = NOW(),
           cancel_reason = p_reason
     WHERE id = p_booking_id;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4. sp_generate_settlement_batch: Tổng hợp COMPLETED chưa chi trả & tạo payout
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_generate_settlement_batch(
    IN  p_period_start DATE,
    IN  p_period_end   DATE,
    IN  p_created_by   BIGINT,
    OUT p_batch_id     BIGINT,
    OUT p_batch_code   VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_partner_rec RECORD;
    v_payout_id   BIGINT;
    v_locked_ids  BIGINT[];
BEGIN
    PERFORM set_config('app.current_actor_id', p_created_by::TEXT, TRUE);

    IF p_period_end < p_period_start THEN
        RAISE EXCEPTION 'INVALID_SETTLEMENT_PERIOD' USING ERRCODE = 'P0001';
    END IF;

    -- Khóa tất cả đơn COMPLETED đủ điều kiện (check_out_date <= p_period_end) chưa từng xuất hiện trong payout_items
    SELECT ARRAY_AGG(sub.id ORDER BY sub.id)
      INTO v_locked_ids
      FROM (
          SELECT b.id
            FROM bookings b
           WHERE b.status = 'COMPLETED'
             AND b.check_out_date <= p_period_end
             AND NOT EXISTS (
                 SELECT 1 FROM payout_items pi WHERE pi.booking_id = b.id
             )
           ORDER BY b.id ASC
           FOR UPDATE OF b
      ) AS sub;

    p_batch_code := 'STL-' || TO_CHAR(p_period_end, 'YYYYMMDD') || '-' || LPAD(nextval('seq_batch_code')::TEXT, 4, '0');

    INSERT INTO settlement_batches (batch_code, period_start, period_end, created_by, status)
    VALUES (p_batch_code, p_period_start, p_period_end, p_created_by, 'FINALIZED')
    RETURNING id INTO p_batch_id;

    IF v_locked_ids IS NULL OR array_length(v_locked_ids, 1) IS NULL THEN
        RETURN;
    END IF;

    FOR v_partner_rec IN
        SELECT h.partner_id,
               SUM(b.room_subtotal)::NUMERIC(18, 0)     AS gross_amount,
               SUM(b.commission_amount)::NUMERIC(18, 0) AS commission_total,
               SUM(b.room_subtotal - b.commission_amount)::NUMERIC(18, 0) AS net_payout
          FROM bookings b
          JOIN hotels h ON h.id = b.hotel_id
         WHERE b.id = ANY(v_locked_ids)
         GROUP BY h.partner_id
         ORDER BY h.partner_id ASC
    LOOP
        INSERT INTO partner_payouts (
            batch_id, partner_id, gross_amount, commission_total, net_payout, status
        )
        VALUES (
            p_batch_id, v_partner_rec.partner_id,
            v_partner_rec.gross_amount, v_partner_rec.commission_total,
            v_partner_rec.net_payout, 'PENDING'
        )
        RETURNING id INTO v_payout_id;

        INSERT INTO payout_items (payout_id, booking_id, booking_amount, commission_amount, net_amount)
        SELECT v_payout_id,
               b.id,
               b.room_subtotal,
               b.commission_amount,
               (b.room_subtotal - b.commission_amount)
          FROM bookings b
          JOIN hotels h ON h.id = b.hotel_id
         WHERE b.id = ANY(v_locked_ids)
           AND h.partner_id = v_partner_rec.partner_id
         ORDER BY b.id ASC;
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 5. sp_release_expired_holds: Giải phóng các đơn HOLD/PENDING_PAYMENT quá hạn
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_release_expired_holds(
    OUT p_released_count INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec    RECORD;
    v_refund NUMERIC(18, 0);
BEGIN
    p_released_count := 0;
    FOR v_rec IN
        SELECT b.id
          FROM bookings b
         WHERE b.status IN ('HOLD', 'PENDING_PAYMENT')
           AND b.hold_expires_at < NOW()
         ORDER BY b.id ASC
         FOR UPDATE SKIP LOCKED
    LOOP
        CALL sp_cancel_booking(v_rec.id, NULL, 'Hết thời gian giữ chỗ tự động giải phóng', FALSE, NULL, v_refund);
        p_released_count := p_released_count + 1;
    END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 6. sp_check_in_booking & sp_check_out_booking: Nhận & trả phòng vật lý
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_check_in_booking(
    IN p_booking_id BIGINT,
    IN p_room_ids   BIGINT[],
    IN p_actor_id   BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_booking   RECORD;
    v_item_cnt  INT;
    v_idx       INT := 0;
    v_item_rec  RECORD;
    v_room_id   BIGINT;
BEGIN
    PERFORM set_config('app.current_actor_id', COALESCE(p_actor_id::TEXT, ''), TRUE);

    SELECT id, status INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0001';
    END IF;
    IF v_booking.status <> 'CONFIRMED' THEN
        RAISE EXCEPTION 'CHECKIN_REQUIRES_CONFIRMED_STATUS' USING ERRCODE = 'P0001';
    END IF;

    SELECT COUNT(*)::INT INTO v_item_cnt FROM booking_items WHERE booking_id = p_booking_id;
    IF p_room_ids IS NULL
       OR COALESCE(array_ndims(p_room_ids), 0) <> 1
       OR COALESCE(array_length(p_room_ids, 1), 0) <> v_item_cnt
       OR NULL = ANY(p_room_ids)
       OR (SELECT COUNT(DISTINCT x) FROM UNNEST(p_room_ids) AS x) <> v_item_cnt THEN
        RAISE EXCEPTION 'INVALID_OR_DUPLICATE_ROOM_IDS' USING ERRCODE = 'P0001';
    END IF;

    -- Khóa tất cả phòng vật lý theo thứ tự id tăng dần trước khi gán
    PERFORM 1 FROM rooms WHERE id = ANY(p_room_ids) ORDER BY id ASC FOR UPDATE;

    FOR v_item_rec IN
        SELECT line_no, room_type_id, quantity
          FROM booking_items
         WHERE booking_id = p_booking_id
         ORDER BY line_no ASC
    LOOP
        IF v_item_rec.quantity <> 1 THEN
            RAISE EXCEPTION 'BULK_ITEM_CANNOT_ASSIGN_SINGLE_ROOM' USING ERRCODE = 'P0001';
        END IF;
        v_idx := v_idx + 1;
        v_room_id := p_room_ids[v_idx];

        UPDATE booking_items
           SET assigned_room_id = v_room_id
         WHERE booking_id = p_booking_id
           AND line_no = v_item_rec.line_no;

        UPDATE rooms
           SET status = 'OCCUPIED'
         WHERE id = v_room_id;
    END LOOP;

    UPDATE bookings SET status = 'CHECKED_IN' WHERE id = p_booking_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_check_out_booking(
    IN p_booking_id BIGINT,
    IN p_actor_id   BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    PERFORM set_config('app.current_actor_id', COALESCE(p_actor_id::TEXT, ''), TRUE);

    SELECT status INTO v_status FROM bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE = 'P0001';
    END IF;
    IF v_status <> 'CHECKED_IN' THEN
        RAISE EXCEPTION 'CHECKOUT_REQUIRES_CHECKED_IN_STATUS' USING ERRCODE = 'P0001';
    END IF;

    UPDATE rooms r
       SET status = 'AVAILABLE'
      FROM booking_items bi
     WHERE bi.booking_id = p_booking_id
       AND bi.assigned_room_id = r.id
       AND r.status = 'OCCUPIED';

    UPDATE bookings SET status = 'COMPLETED' WHERE id = p_booking_id;
END;
$$;
