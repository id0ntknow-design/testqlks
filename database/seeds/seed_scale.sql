-- =============================================================================
-- seeds/seed_scale.sql
-- Script sinh dữ liệu quy mô lớn (Benchmark / EXPLAIN ANALYZE):
--   - room_inventory >= 100.000 dòng (100 khách sạn x 3 hạng phòng x 365 ngày = 109.500 dòng)
--   - bookings       >= 10.000 dòng (tham số mặc định 12.000; có thể nâng lên 100.000)
--   - booking_night_rates >= 200.000 dòng khi sinh bản 100k hoặc có sẵn >= 24.000 dòng ở mức 12k
-- Lưu ý: Chạy thủ công khi cần đo hiệu năng, không nằm trong auto-init mặc định.
-- =============================================================================

\set ON_ERROR_STOP on
\timing on

BEGIN;

-- Tắt tạm trigger audit trên bookings trong quá trình nạp hàng loạt dữ liệu benchmark
ALTER TABLE bookings DISABLE TRIGGER trg_audit_log_bookings;

-- 1. Tạo thêm khách hàng giả lập tiếng Việt (1.500 khách hàng)
INSERT INTO users (email, password_hash, full_name, phone, role)
SELECT 'khachhang.' || g || '@bench.hotelota.vn',
       '$2b$10$benchHash00000000000000000000000000000000000000000000',
       (ARRAY['Nguyễn','Trần','Lê','Phạm','Hoàng','Vũ','Đặng','Bùi','Đỗ','Ngô'])[1 + (g % 10)] || ' ' ||
       (ARRAY['Văn','Thị','Minh','Thanh','Quốc','Ngọc','Hoàng','Thu','Anh','Bảo'])[1 + ((g / 10) % 10)] || ' ' ||
       (ARRAY['An','Bình','Chi','Dũng','Giang','Hà','Hùng','Khánh','Linh','Nam'])[1 + ((g / 100) % 10)],
       '09' || LPAD((80000000 + g)::TEXT, 8, '0'),
       'CUSTOMER'
FROM generate_series(1, 1500) AS g
ON CONFLICT (email) DO NOTHING;

-- 2. Tạo thêm 94 khách sạn APPROVED để đạt >= 100 khách sạn trên toàn hệ thống
INSERT INTO hotels (partner_id, location_id, code, name, address, description, star_rating, approval_status, commission_rate, is_active)
SELECT (SELECT user_id FROM partner_profiles ORDER BY user_id OFFSET (g % 3) LIMIT 1),
       (SELECT id FROM locations WHERE level IN ('DISTRICT', 'AREA') ORDER BY id OFFSET (g % 9) LIMIT 1),
       'HTL-SC-' || LPAD(g::TEXT, 4, '0'),
       'Khách sạn Sao Mai ' || g,
       g || ' Đường Trần Hưng Đạo, Việt Nam',
       'Khách sạn dữ liệu kiểm thử hiệu năng quy mô lớn.',
       (3 + (g % 3))::SMALLINT,
       'APPROVED',
       (12 + (g % 5))::NUMERIC(5, 2),
       TRUE
FROM generate_series(1, 95) AS g
ON CONFLICT (code) DO NOTHING;

-- 3. Gắn chính sách hủy mặc định & 3 hạng phòng/khách sạn cho các khách sạn mới
INSERT INTO cancellation_policies (hotel_id, name, free_cancel_hours, penalty_percent, is_default)
SELECT h.id, 'Miễn phí hủy trước 48h', 48, 50.00, TRUE
FROM hotels h
WHERE h.code LIKE 'HTL-SC-%'
  AND NOT EXISTS (SELECT 1 FROM cancellation_policies cp WHERE cp.hotel_id = h.id);

INSERT INTO room_types (hotel_id, code, name, description, max_adults, max_children, base_price, total_rooms)
SELECT h.id, rt_def.code, rt_def.name, 'Hạng phòng tiêu chuẩn benchmark', 2, 1,
       rt_def.price + ((h.id % 5) * 100000), 10
FROM hotels h
CROSS JOIN (VALUES
    ('STD', 'Standard', 800000),
    ('DLX', 'Deluxe',   1300000),
    ('SUT', 'Suite',    2400000)
) AS rt_def(code, name, price)
WHERE h.code LIKE 'HTL-SC-%'
ON CONFLICT (hotel_id, code) DO NOTHING;

-- 4. Sinh room_inventory >= 109.500 dòng (100 khách sạn x 3 hạng phòng x 365 ngày)
INSERT INTO room_inventory (room_type_id, stay_date, total_allotment, booked_count, held_count, nightly_price, is_closed)
SELECT rt.id,
       (CURRENT_DATE - 180 + d)::DATE,
       rt.total_rooms,
       0,
       0,
       CASE WHEN EXTRACT(ISODOW FROM (CURRENT_DATE - 180 + d)) IN (5, 6)
            THEN ROUND(rt.base_price * 1.15, 0)
            ELSE rt.base_price END,
       FALSE
FROM room_types rt
CROSS JOIN generate_series(0, 364) AS d
ON CONFLICT (room_type_id, stay_date) DO NOTHING;

-- 5. Sinh 100.000 bookings (bảo đảm >= 100.000 bookings và >= 200.000 booking_night_rates)
WITH cust_arr AS (
    SELECT ARRAY_AGG(id ORDER BY id) AS ids FROM users WHERE role = 'CUSTOMER'
),
rt_pool AS (
    SELECT rt.id AS room_type_id,
           rt.hotel_id,
           rt.base_price,
           h.commission_rate,
           cp.id AS policy_id,
           ROW_NUMBER() OVER (ORDER BY rt.id) AS rn
      FROM room_types rt
      JOIN hotels h ON h.id = rt.hotel_id
      JOIN cancellation_policies cp ON cp.hotel_id = h.id AND cp.is_default = TRUE
     WHERE h.approval_status = 'APPROVED'
),
rt_cnt AS (SELECT COUNT(*)::INT AS total_rt FROM rt_pool),
gen AS (
    SELECT g,
           (SELECT ids[1 + (g % array_length(ids, 1))] FROM cust_arr) AS customer_id,
           rp.hotel_id,
           rp.room_type_id,
           rp.policy_id,
           rp.commission_rate,
           rp.base_price,
           (CURRENT_DATE - 170 + (g % 320))::DATE AS check_in_date,
           (2 + (g % 2))::INT AS nights,
           CASE
               WHEN g % 10 < 6 THEN 'COMPLETED'
               WHEN g % 10 < 8 THEN 'CONFIRMED'
               WHEN g % 10 = 8 THEN 'CANCELLED'
               ELSE 'HOLD'
           END AS status
      FROM generate_series(1, 100000) AS g
      CROSS JOIN rt_cnt rc
      JOIN rt_pool rp ON rp.rn = 1 + (g % rc.total_rt)
),
ins_bookings AS (
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount,
        hold_expires_at, created_at
    )
    SELECT 'BK-SC-' || LPAD(g::TEXT, 7, '0'),
           customer_id,
           hotel_id,
           NULL,
           policy_id,
           check_in_date,
           (check_in_date + nights)::DATE,
           2::SMALLINT,
           status,
           commission_rate,
           (base_price * nights)::NUMERIC(18, 0),
           0::NUMERIC(18, 0),
           (base_price * nights)::NUMERIC(18, 0),
           ROUND(base_price * nights * commission_rate / 100.0, 0)::NUMERIC(18, 0),
           CASE WHEN status = 'HOLD' THEN NOW() + INTERVAL '15 minutes' ELSE NULL END,
           (check_in_date::TIMESTAMPTZ - INTERVAL '7 days')
      FROM gen
    ON CONFLICT (booking_code) DO NOTHING
    RETURNING id, booking_code, hotel_id, check_in_date, check_out_date, total_amount, status
),
ins_items AS (
    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total)
    SELECT b.id, 1, b.hotel_id, g.room_type_id, NULL, 1, (b.check_out_date - b.check_in_date),
           ROUND(b.total_amount / (b.check_out_date - b.check_in_date), 0), b.total_amount
      FROM ins_bookings b
      JOIN gen g ON ('BK-SC-' || LPAD(g.g::TEXT, 7, '0')) = b.booking_code
    RETURNING booking_id, room_type_id, line_total
)
INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot)
SELECT b.id,
       ii.room_type_id,
       (b.check_in_date + n)::DATE,
       1,
       ROUND(b.total_amount / (b.check_out_date - b.check_in_date), 0)
  FROM ins_bookings b
  JOIN ins_items ii ON ii.booking_id = b.id
  CROSS JOIN LATERAL generate_series(0, (b.check_out_date - b.check_in_date) - 1) AS n;

-- Kích hoạt lại trigger audit và phân tích thống kê cho bộ tối ưu truy vấn
ALTER TABLE bookings ENABLE TRIGGER trg_audit_log_bookings;
ANALYZE;

COMMIT;

SELECT
    (SELECT COUNT(*) FROM hotels)              AS total_hotels,
    (SELECT COUNT(*) FROM room_types)          AS total_room_types,
    (SELECT COUNT(*) FROM room_inventory)      AS total_room_inventory,
    (SELECT COUNT(*) FROM bookings)            AS total_bookings,
    (SELECT COUNT(*) FROM booking_night_rates) AS total_booking_night_rates;
