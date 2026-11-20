-- =============================================================================
-- 03_functions.sql
-- Các hàm nghiệp vụ tính báo giá đặt phòng và tính tiền hoàn hủy
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. fn_calculate_booking_quote (nhận p_items JSONB nhiều hạng phòng cùng khách sạn)
--    Ví dụ p_items: '[{"room_type_id": 1, "quantity": 2}]'::jsonb
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calculate_booking_quote(
    p_hotel_id   BIGINT,
    p_items      JSONB,
    p_check_in   DATE,
    p_check_out  DATE,
    p_promo_code VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    room_subtotal     NUMERIC(18, 0),
    discount_amount   NUMERIC(18, 0),
    total_amount      NUMERIC(18, 0),
    commission_rate   NUMERIC(5, 2),
    commission_amount NUMERIC(18, 0),
    nights            INT,
    promo_id          BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_nights           INT;
    v_commission_rate  NUMERIC(5, 2);
    v_hotel_ok         BOOLEAN;
    v_subtotal         NUMERIC(18, 0) := 0;
    v_discount         NUMERIC(18, 0) := 0;
    v_promo_id         BIGINT := NULL;
    v_promo_type       VARCHAR(20);
    v_promo_value      NUMERIC(18, 2);
    v_promo_max        NUMERIC(18, 0);
    v_promo_min_order  NUMERIC(18, 0);
    v_item             RECORD;
    v_avail_nights     INT;
    v_item_subtotal    NUMERIC(18, 0);
BEGIN
    IF p_check_in IS NULL OR p_check_out IS NULL OR p_check_out <= p_check_in THEN
        RAISE EXCEPTION 'CHECK_OUT_MUST_BE_AFTER_CHECK_IN'
            USING ERRCODE = 'P0001',
                  DETAIL = 'Ngày trả phòng phải lớn hơn ngày nhận phòng.';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'INVALID_BOOKING_ITEMS'
            USING ERRCODE = 'P0001',
                  DETAIL = 'Danh sách hạng phòng đặt phải là mảng JSON khác rỗng.';
    END IF;

    SELECT (h.approval_status = 'APPROVED' AND h.is_active), h.commission_rate
      INTO v_hotel_ok, v_commission_rate
      FROM hotels h
     WHERE h.id = p_hotel_id;

    IF NOT FOUND OR NOT v_hotel_ok THEN
        RAISE EXCEPTION 'HOTEL_NOT_AVAILABLE'
            USING ERRCODE = 'P0001',
                  DETAIL = 'Khách sạn không tồn tại hoặc chưa được phê duyệt hoạt động.';
    END IF;

    v_nights := (p_check_out - p_check_in);

    FOR v_item IN
        SELECT (elem->>'room_type_id')::BIGINT AS room_type_id,
               SUM((elem->>'quantity')::INT)  AS quantity
          FROM jsonb_array_elements(p_items) AS elem
         GROUP BY (elem->>'room_type_id')::BIGINT
         ORDER BY (elem->>'room_type_id')::BIGINT ASC
    LOOP
        IF v_item.room_type_id IS NULL OR v_item.quantity IS NULL OR v_item.quantity <= 0 THEN
            RAISE EXCEPTION 'INVALID_ITEM_QUANTITY'
                USING ERRCODE = 'P0001',
                      DETAIL = 'Mã loại phòng và số lượng phòng phải lớn hơn 0.';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM room_types rt
             WHERE rt.id = v_item.room_type_id
               AND rt.hotel_id = p_hotel_id
               AND rt.is_active = TRUE
        ) THEN
            RAISE EXCEPTION 'ROOM_TYPE_NOT_IN_HOTEL'
                USING ERRCODE = 'P0001',
                      DETAIL = format('Loại phòng %s không thuộc khách sạn %s hoặc đang ngừng bán.', v_item.room_type_id, p_hotel_id);
        END IF;

        SELECT COUNT(*)::INT,
               COALESCE(SUM(ri.nightly_price * v_item.quantity), 0)::NUMERIC(18, 0)
          INTO v_avail_nights, v_item_subtotal
          FROM room_inventory ri
         WHERE ri.room_type_id = v_item.room_type_id
           AND ri.stay_date >= p_check_in
           AND ri.stay_date < p_check_out
           AND ri.is_closed = FALSE
           AND (ri.total_allotment - ri.booked_count - ri.held_count) >= v_item.quantity;

        IF v_avail_nights <> v_nights THEN
            RAISE EXCEPTION 'INSUFFICIENT_ROOM_INVENTORY'
                USING ERRCODE = 'P0002',
                      DETAIL = format('Loại phòng %s không đủ %s phòng trống cho tất cả %s đêm.', v_item.room_type_id, v_item.quantity, v_nights);
        END IF;

        v_subtotal := v_subtotal + v_item_subtotal;
    END LOOP;

    IF p_promo_code IS NOT NULL AND BTRIM(p_promo_code) <> '' THEN
        SELECT p.id, p.discount_type, p.discount_value, p.max_discount_amount, p.min_order_amount
          INTO v_promo_id, v_promo_type, v_promo_value, v_promo_max, v_promo_min_order
          FROM promotions p
         WHERE p.code = BTRIM(p_promo_code)
           AND p.is_active = TRUE
           AND NOW() BETWEEN p.valid_from AND p.valid_to
           AND p.used_count < p.usage_limit;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'PROMO_CODE_INVALID_OR_EXPIRED'
                USING ERRCODE = 'P0001',
                      DETAIL = format('Mã khuyến mãi %s không hợp lệ, đã hết hạn hoặc hết lượt.', p_promo_code);
        END IF;

        IF v_subtotal < v_promo_min_order THEN
            RAISE EXCEPTION 'PROMO_MIN_ORDER_NOT_MET'
                USING ERRCODE = 'P0001',
                      DETAIL = format('Đơn đặt cần tối thiểu %s VND để áp dụng mã %s.', v_promo_min_order, p_promo_code);
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
    END IF;

    room_subtotal     := v_subtotal;
    discount_amount   := v_discount;
    total_amount      := GREATEST(v_subtotal - v_discount, 0);
    commission_rate   := v_commission_rate;
    commission_amount := ROUND(v_subtotal * v_commission_rate / 100.0, 0);
    nights            := v_nights;
    promo_id          := v_promo_id;
    RETURN NEXT;
END;
$$;

-- Nạp chồng 1 loại phòng giữ tương thích chữ ký hàm trong đề cương
CREATE OR REPLACE FUNCTION fn_calculate_booking_quote(
    p_room_type_id BIGINT,
    p_check_in     DATE,
    p_check_out    DATE,
    p_qty          INT,
    p_promo_code   VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    room_subtotal     NUMERIC(18, 0),
    discount_amount   NUMERIC(18, 0),
    total_amount      NUMERIC(18, 0),
    commission_rate   NUMERIC(5, 2),
    commission_amount NUMERIC(18, 0),
    nights            INT,
    promo_id          BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_hotel_id BIGINT;
BEGIN
    SELECT rt.hotel_id
      INTO v_hotel_id
      FROM room_types rt
     WHERE rt.id = p_room_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ROOM_TYPE_NOT_FOUND'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN QUERY
    SELECT q.room_subtotal, q.discount_amount, q.total_amount,
           q.commission_rate, q.commission_amount, q.nights, q.promo_id
      FROM fn_calculate_booking_quote(
               v_hotel_id,
               jsonb_build_array(jsonb_build_object('room_type_id', p_room_type_id, 'quantity', p_qty)),
               p_check_in,
               p_check_out,
               p_promo_code
           ) AS q;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. fn_calculate_refund_amount(p_booking_id, p_cancel_time)
--    Tính số tiền hoàn và phí phạt theo chính sách hủy đã chốt trên đơn
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calculate_refund_amount(
    p_booking_id  BIGINT,
    p_cancel_time TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
    refundable_amount NUMERIC(18, 0),
    penalty_amount    NUMERIC(18, 0),
    penalty_percent   NUMERIC(5, 2),
    paid_amount       NUMERIC(18, 0),
    is_free_cancel    BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_check_in          DATE;
    v_free_hours        INT;
    v_policy_penalty    NUMERIC(5, 2);
    v_free_deadline     TIMESTAMPTZ;
    v_net_paid          NUMERIC(18, 0);
BEGIN
    SELECT b.check_in_date, cp.free_cancel_hours, cp.penalty_percent
      INTO v_check_in, v_free_hours, v_policy_penalty
      FROM bookings b
      JOIN cancellation_policies cp ON cp.id = b.policy_id
     WHERE b.id = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'BOOKING_NOT_FOUND'
            USING ERRCODE = 'P0001',
                  DETAIL = format('Không tìm thấy đơn đặt phòng id = %s.', p_booking_id);
    END IF;

    SELECT GREATEST(
               COALESCE(SUM(CASE WHEN payment_type = 'CHARGE' THEN amount ELSE 0 END), 0) -
               COALESCE(SUM(CASE WHEN payment_type = 'REFUND' THEN amount ELSE 0 END), 0),
               0
           )::NUMERIC(18, 0)
      INTO v_net_paid
      FROM payments
     WHERE booking_id = p_booking_id
       AND status = 'SUCCESS';

    -- Giờ nhận phòng chuẩn 14:00 theo múi giờ Việt Nam
    v_free_deadline := ((v_check_in::TIMESTAMP + INTERVAL '14 hours') AT TIME ZONE 'Asia/Ho_Chi_Minh')
                       - make_interval(hours => v_free_hours);

    paid_amount := v_net_paid;

    IF p_cancel_time <= v_free_deadline THEN
        is_free_cancel    := TRUE;
        penalty_percent   := 0.00;
        penalty_amount    := 0;
        refundable_amount := v_net_paid;
    ELSE
        is_free_cancel    := FALSE;
        penalty_percent   := v_policy_penalty;
        penalty_amount    := ROUND(v_net_paid * v_policy_penalty / 100.0, 0);
        refundable_amount := GREATEST(v_net_paid - penalty_amount, 0);
    END IF;

    RETURN NEXT;
END;
$$;
