-- =============================================================================
-- 08_seed_demo.sql
-- Dữ liệu mẫu tiếng Việt chuẩn ràng buộc cho 22 bảng (chạy nhanh khi khởi tạo Docker)
-- Bao gồm ví dụ đối chứng Mục III.4 (4.400.000 / 4.200.000 / 660.000 / 3.740.000 VND)
-- =============================================================================

BEGIN;

-- 1. Tài khoản 05 vai trò (mật khẩu mẫu dạng hash bcrypt giả lập)
INSERT INTO users (email, password_hash, full_name, phone, role) VALUES
('admin@hotelota.vn',          '$2b$10$demoHashAdmin0000000000000000000000000000000000001', 'Quản trị viên Hệ thống',  '0901000001', 'ADMIN'),
('doitac.hanoi@hotelota.vn',   '$2b$10$demoHashPartner00000000000000000000000000000000002', 'Trần Minh Quang',         '0902000002', 'PARTNER'),
('doitac.danang@hotelota.vn',  '$2b$10$demoHashPartner00000000000000000000000000000000003', 'Lê Thị Thu Hà',           '0902000003', 'PARTNER'),
('doitac.hcm@hotelota.vn',     '$2b$10$demoHashPartner00000000000000000000000000000000004', 'Phạm Quốc Bảo',           '0902000004', 'PARTNER'),
('hotro1@hotelota.vn',         '$2b$10$demoHashSupport00000000000000000000000000000000005', 'Nguyễn Ngọc Linh',        '0903000005', 'SUPPORT'),
('hotro2@hotelota.vn',         '$2b$10$demoHashSupport00000000000000000000000000000000006', 'Vũ Hoàng Nam',            '0903000006', 'SUPPORT'),
('ketoan@hotelota.vn',         '$2b$10$demoHashAccount00000000000000000000000000000000007', 'Đặng Thị Mai Phương',     '0904000007', 'ACCOUNTANT'),
('an.nguyen@example.vn',       '$2b$10$demoHashCust00000000000000000000000000000000000008', 'Nguyễn Văn An',           '0911000008', 'CUSTOMER'),
('binh.tran@example.vn',       '$2b$10$demoHashCust00000000000000000000000000000000000009', 'Trần Thanh Bình',         '0911000009', 'CUSTOMER'),
('chi.le@example.vn',          '$2b$10$demoHashCust00000000000000000000000000000000000010', 'Lê Kim Chi',              '0911000010', 'CUSTOMER'),
('dung.pham@example.vn',       '$2b$10$demoHashCust00000000000000000000000000000000000011', 'Phạm Tiến Dũng',          '0911000011', 'CUSTOMER'),
('em.hoang@example.vn',        '$2b$10$demoHashCust00000000000000000000000000000000000012', 'Hoàng Thị Minh Tâm',      '0911000012', 'CUSTOMER');

-- 2. Hồ sơ đối tác (1-1 với users role PARTNER)
INSERT INTO partner_profiles (user_id, business_name, tax_code, bank_account, bank_name, bank_branch, kyc_status, verified_by, verified_at)
SELECT u.id, v.business_name, v.tax_code, v.bank_account, v.bank_name, v.bank_branch, 'APPROVED',
       (SELECT id FROM users WHERE email = 'admin@hotelota.vn'), NOW() - INTERVAL '90 days'
FROM (VALUES
    ('doitac.hanoi@hotelota.vn',  'Công ty TNHH Lưu trú Ánh Dương Hà Nội',  '0108111222', '19031112223331', 'Techcombank',  'Chi nhánh Hoàn Kiếm'),
    ('doitac.danang@hotelota.vn', 'Công ty CP Du lịch Biển Xanh Đà Nẵng',    '0408333444', '00410003334442', 'Vietcombank',  'Chi nhánh Đà Nẵng'),
    ('doitac.hcm@hotelota.vn',    'Công ty TNHH Khách sạn Bến Thành SG',     '0308555666', '10201000555666', 'VietinBank',   'Chi nhánh Quận 1')
) AS v(email, business_name, tax_code, bank_account, bank_name, bank_branch)
JOIN users u ON u.email = v.email;

-- 3. Cây địa điểm phân cấp 4 tầng: COUNTRY -> PROVINCE -> DISTRICT -> AREA
INSERT INTO locations (parent_id, code, name, level) VALUES (NULL, 'VN', 'Việt Nam', 'COUNTRY');

INSERT INTO locations (parent_id, code, name, level)
SELECT (SELECT id FROM locations WHERE code = 'VN'), v.code, v.name, 'PROVINCE'
FROM (VALUES
    ('VN-HN',  'Thành phố Hà Nội'),
    ('VN-DN',  'Thành phố Đà Nẵng'),
    ('VN-HCM', 'Thành phố Hồ Chí Minh'),
    ('VN-KG',  'Tỉnh Kiên Giang')
) AS v(code, name);

INSERT INTO locations (parent_id, code, name, level)
SELECT p.id, v.code, v.name, 'DISTRICT'
FROM (VALUES
    ('VN-HN',  'VN-HN-HK',  'Quận Hoàn Kiếm'),
    ('VN-HN',  'VN-HN-TH',  'Quận Tây Hồ'),
    ('VN-DN',  'VN-DN-ST',  'Quận Sơn Trà'),
    ('VN-DN',  'VN-DN-HC',  'Quận Hải Châu'),
    ('VN-HCM', 'VN-HCM-Q1', 'Quận 1'),
    ('VN-KG',  'VN-KG-PQ',  'Thành phố Phú Quốc')
) AS v(parent_code, code, name)
JOIN locations p ON p.code = v.parent_code;

INSERT INTO locations (parent_id, code, name, level)
SELECT p.id, v.code, v.name, 'AREA'
FROM (VALUES
    ('VN-HN-HK',  'VN-HN-HK-PC', 'Khu vực Phố Cổ'),
    ('VN-DN-ST',  'VN-DN-ST-MK', 'Bãi biển Mỹ Khê'),
    ('VN-HCM-Q1', 'VN-HCM-Q1-NH','Phố đi bộ Nguyễn Huệ')
) AS v(parent_code, code, name)
JOIN locations p ON p.code = v.parent_code;

-- 4. Tiện ích toàn sàn
INSERT INTO amenities (code, name, category) VALUES
('FREE_WIFI',        'Wi-Fi miễn phí',           'GENERAL'),
('POOL',             'Hồ bơi ngoài trời',        'WELLNESS'),
('PARKING',          'Bãi đỗ xe miễn phí',       'GENERAL'),
('BREAKFAST',        'Bữa sáng tự chọn',         'DINING'),
('AIR_CONDITIONING', 'Điều hòa hai chiều',       'ROOM'),
('GYM',              'Phòng tập thể hình',       'WELLNESS'),
('AIRPORT_SHUTTLE',  'Đưa đón sân bay',          'GENERAL'),
('SEA_VIEW',         'Tầm nhìn hướng biển',      'ROOM');

-- 5. Mã khuyến mãi toàn sàn
INSERT INTO promotions (code, name, discount_type, discount_value, max_discount_amount, min_order_amount, valid_from, valid_to, usage_limit, used_count) VALUES
('GIAM200K', 'Ưu đãi giảm thẳng 200.000đ',   'FIXED',   200000.00, NULL,    1000000, NOW() - INTERVAL '60 days', NOW() + INTERVAL '365 days', 500, 1),
('HE2026',   'Giảm 10% tối đa 500.000đ',      'PERCENT', 10.00,     500000,  1500000, NOW() - INTERVAL '60 days', NOW() + INTERVAL '365 days', 300, 1),
('VIP15',    'Ưu đãi thành viên VIP 15%',     'PERCENT', 15.00,     800000,  2000000, NOW() - INTERVAL '60 days', NOW() + INTERVAL '365 days', 100, 0);

-- 6. Khách sạn (5 APPROVED + 1 PENDING)
INSERT INTO hotels (partner_id, location_id, code, name, address, description, star_rating, approval_status, commission_rate, is_active)
SELECT u.id, l.id, v.code, v.name, v.address, v.description, v.star_rating, v.approval_status, v.commission_rate, TRUE
FROM (VALUES
    ('doitac.hanoi@hotelota.vn',  'VN-HN-HK-PC',  'HTL-HN-01',  'Khách sạn Hoàng Gia Hà Nội',       '12 Hàng Trống, Hoàn Kiếm, Hà Nội',       'Khách sạn boutique trung tâm Phố Cổ, cách Hồ Gươm 2 phút đi bộ.', 4, 'APPROVED', 15.00),
    ('doitac.hanoi@hotelota.vn',  'VN-HN-TH',     'HTL-HN-02',  'Khách sạn Hồ Tây Serenity',        '88 Quảng An, Tây Hồ, Hà Nội',            'Không gian yên tĩnh ven Hồ Tây với hồ bơi vô cực.',                 5, 'APPROVED', 12.00),
    ('doitac.danang@hotelota.vn', 'VN-DN-ST-MK',  'HTL-DN-01',  'Khu nghỉ dưỡng Mỹ Khê Xanh',       '199 Võ Nguyên Giáp, Sơn Trà, Đà Nẵng',   'Resort mặt biển Mỹ Khê đạt chuẩn 5 sao quốc tế.',                    5, 'APPROVED', 15.00),
    ('doitac.danang@hotelota.vn', 'VN-DN-HC',     'HTL-DN-02',  'Khách sạn Sông Hàn Boutique',      '45 Bạch Đằng, Hải Châu, Đà Nẵng',        'Tiện nghi công tác trung tâm thành phố nhìn ra cầu Rồng.',          3, 'APPROVED', 10.00),
    ('doitac.hcm@hotelota.vn',    'VN-HCM-Q1-NH', 'HTL-HCM-01', 'Khách sạn Sài Gòn Bến Thành',      '62 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh', 'Khách sạn trung tâm Quận 1 gần Nhà hát Thành phố.',                 4, 'APPROVED', 14.00),
    ('doitac.hcm@hotelota.vn',    'VN-KG-PQ',     'HTL-PQ-01',  'Khu nghỉ dưỡng Ngọc Biển Phú Quốc', 'Bãi Trường, Dương Tơ, Phú Quốc',         'Đang chờ thẩm định hồ sơ vận hành trước khi mở bán.',               5, 'PENDING',  15.00)
) AS v(partner_email, loc_code, code, name, address, description, star_rating, approval_status, commission_rate)
JOIN users u ON u.email = v.partner_email
JOIN locations l ON l.code = v.loc_code;

-- 7. Gắn tiện ích khách sạn (HTL-HN-02, HTL-DN-01, HTL-HCM-01 có đủ FREE_WIFI + POOL + PARKING)
INSERT INTO hotel_amenities (hotel_id, amenity_id)
SELECT h.id, a.id
FROM (VALUES
    ('HTL-HN-01', 'FREE_WIFI'), ('HTL-HN-01', 'BREAKFAST'), ('HTL-HN-01', 'AIR_CONDITIONING'), ('HTL-HN-01', 'AIRPORT_SHUTTLE'),
    ('HTL-HN-02', 'FREE_WIFI'), ('HTL-HN-02', 'POOL'), ('HTL-HN-02', 'PARKING'), ('HTL-HN-02', 'BREAKFAST'), ('HTL-HN-02', 'GYM'),
    ('HTL-DN-01', 'FREE_WIFI'), ('HTL-DN-01', 'POOL'), ('HTL-DN-01', 'PARKING'), ('HTL-DN-01', 'BREAKFAST'), ('HTL-DN-01', 'SEA_VIEW'),
    ('HTL-DN-02', 'FREE_WIFI'), ('HTL-DN-02', 'PARKING'), ('HTL-DN-02', 'AIR_CONDITIONING'),
    ('HTL-HCM-01', 'FREE_WIFI'), ('HTL-HCM-01', 'POOL'), ('HTL-HCM-01', 'PARKING'), ('HTL-HCM-01', 'GYM'), ('HTL-HCM-01', 'BREAKFAST')
) AS v(hotel_code, amenity_code)
JOIN hotels h ON h.code = v.hotel_code
JOIN amenities a ON a.code = v.amenity_code;

-- 8. Chính sách hủy phòng
INSERT INTO cancellation_policies (hotel_id, name, free_cancel_hours, penalty_percent, is_default)
SELECT h.id,
       CASE WHEN h.code IN ('HTL-HN-01', 'HTL-DN-01') THEN 'Miễn phí hủy trước 48 giờ (phạt 50% nếu trễ)'
            ELSE 'Miễn phí hủy trước 24 giờ (phạt 100% nếu trễ)' END,
       CASE WHEN h.code IN ('HTL-HN-01', 'HTL-DN-01') THEN 48 ELSE 24 END,
       CASE WHEN h.code IN ('HTL-HN-01', 'HTL-DN-01') THEN 50.00 ELSE 100.00 END,
       TRUE
FROM hotels h;

-- 9. Hạng phòng (room_types)
INSERT INTO room_types (hotel_id, code, name, description, max_adults, max_children, base_price, total_rooms)
SELECT h.id, v.code, v.name, v.description, v.max_adults, v.max_children, v.base_price, v.total_rooms
FROM (VALUES
    ('HTL-HN-01',  'STD', 'Phòng Standard Phố Cổ',      '22m2, giường đôi Queen',                2, 1, 800000,  5),
    ('HTL-HN-01',  'DLX', 'Phòng Deluxe Ban Công',      '30m2, ban công nhìn Phố Cổ',            2, 1, 1000000, 5),
    ('HTL-HN-02',  'DLX', 'Phòng Deluxe Hướng Hồ Tây',  '38m2, bồn tắm đứng & ban công',         2, 1, 1800000, 5),
    ('HTL-HN-02',  'SUT', 'Suite Gia Đình Hồ Tây',      '60m2, phòng khách riêng',               4, 2, 3200000, 3),
    ('HTL-DN-01',  'DLX', 'Deluxe Hướng Biển Mỹ Khê',   '40m2, ban công hướng biển trực diện',   2, 2, 2200000, 6),
    ('HTL-DN-01',  'SUT', 'Ocean Suite Cao Cấp',        '72m2, hồ bơi mini riêng',               4, 2, 4500000, 3),
    ('HTL-DN-02',  'STD', 'Standard Sông Hàn',          '24m2, tiện nghi công tác',              2, 0, 650000,  6),
    ('HTL-HCM-01', 'DLX', 'Deluxe Trung Tâm Quận 1',    '32m2, cửa sổ kính toàn cảnh',           2, 1, 1600000, 6),
    ('HTL-PQ-01',  'DLX', 'Deluxe Bãi Trường',          '42m2, sát biển',                        2, 1, 2400000, 4)
) AS v(hotel_code, code, name, description, max_adults, max_children, base_price, total_rooms)
JOIN hotels h ON h.code = v.hotel_code;

-- 10. Phòng vật lý (rooms) tự động theo total_rooms mỗi hạng phòng
INSERT INTO rooms (room_type_id, room_number, floor, status)
SELECT rt.id,
       rt.code || '-' || LPAD(gs.n::TEXT, 2, '0'),
       ((gs.n - 1) / 3 + 1)::SMALLINT,
       'AVAILABLE'
FROM room_types rt
CROSS JOIN LATERAL generate_series(1, rt.total_rooms) AS gs(n);

-- 11. Quỹ phòng theo ngày (60 ngày: -30 -> +29)
INSERT INTO room_inventory (room_type_id, stay_date, total_allotment, booked_count, held_count, nightly_price, is_closed)
SELECT rt.id,
       d::DATE AS stay_date,
       rt.total_rooms,
       0,
       0,
       CASE
           WHEN EXTRACT(ISODOW FROM d) IN (5, 6) THEN ROUND(rt.base_price * 1.2, 0)
           ELSE rt.base_price
       END AS nightly_price,
       FALSE
FROM room_types rt
CROSS JOIN generate_series(CURRENT_DATE - 30, CURRENT_DATE + 29, INTERVAL '1 day') AS d;

-- Thiết lập chính xác mức giá 1.000.000 (đêm 1) và 1.200.000 (đêm 2) cho ví dụ đối chứng HTL-HN-01 DLX
UPDATE room_inventory ri
   SET nightly_price = 1000000
  FROM room_types rt
  JOIN hotels h ON h.id = rt.hotel_id
 WHERE ri.room_type_id = rt.id
   AND h.code = 'HTL-HN-01' AND rt.code = 'DLX'
   AND ri.stay_date = CURRENT_DATE - 10;

UPDATE room_inventory ri
   SET nightly_price = 1200000
  FROM room_types rt
  JOIN hotels h ON h.id = rt.hotel_id
 WHERE ri.room_type_id = rt.id
   AND h.code = 'HTL-HN-01' AND rt.code = 'DLX'
   AND ri.stay_date = CURRENT_DATE - 9;

-- 12. Dữ liệu nghiệp vụ đặt phòng mẫu (bao gồm ví dụ đối chứng III.4)
DO $$
DECLARE
    v_admin_id      BIGINT;
    v_accountant_id BIGINT;
    v_support_id    BIGINT;
    v_cust_an       BIGINT;
    v_cust_binh     BIGINT;
    v_cust_chi      BIGINT;
    v_cust_dung     BIGINT;
    v_cust_em       BIGINT;
    v_promo_200k    BIGINT;
    v_promo_he      BIGINT;

    v_htl_hn01      BIGINT;
    v_htl_hn02      BIGINT;
    v_htl_dn01      BIGINT;
    v_htl_hcm01     BIGINT;

    v_rt_hn01_dlx   BIGINT;
    v_rt_hn02_dlx   BIGINT;
    v_rt_dn01_dlx   BIGINT;
    v_rt_hcm01_dlx  BIGINT;

    v_pol_hn01      BIGINT;
    v_pol_hn02      BIGINT;
    v_pol_dn01      BIGINT;
    v_pol_hcm01     BIGINT;

    v_b_ref         BIGINT;
    v_b_unsettled   BIGINT;
    v_b_checked_in  BIGINT;
    v_b_confirmed   BIGINT;
    v_b_hold        BIGINT;
    v_b_cancelled   BIGINT;

    v_room_1        BIGINT;
    v_room_2        BIGINT;
    v_room_3        BIGINT;
    v_room_ci       BIGINT;

    v_batch_id      BIGINT;
    v_payout_id     BIGINT;
    v_ticket_id     BIGINT;
BEGIN
    SELECT id INTO v_admin_id      FROM users WHERE email = 'admin@hotelota.vn';
    SELECT id INTO v_accountant_id FROM users WHERE email = 'ketoan@hotelota.vn';
    SELECT id INTO v_support_id    FROM users WHERE email = 'hotro1@hotelota.vn';
    SELECT id INTO v_cust_an       FROM users WHERE email = 'an.nguyen@example.vn';
    SELECT id INTO v_cust_binh     FROM users WHERE email = 'binh.tran@example.vn';
    SELECT id INTO v_cust_chi      FROM users WHERE email = 'chi.le@example.vn';
    SELECT id INTO v_cust_dung     FROM users WHERE email = 'dung.pham@example.vn';
    SELECT id INTO v_cust_em       FROM users WHERE email = 'em.hoang@example.vn';
    SELECT id INTO v_promo_200k    FROM promotions WHERE code = 'GIAM200K';
    SELECT id INTO v_promo_he      FROM promotions WHERE code = 'HE2026';

    SELECT id INTO v_htl_hn01  FROM hotels WHERE code = 'HTL-HN-01';
    SELECT id INTO v_htl_hn02  FROM hotels WHERE code = 'HTL-HN-02';
    SELECT id INTO v_htl_dn01  FROM hotels WHERE code = 'HTL-DN-01';
    SELECT id INTO v_htl_hcm01 FROM hotels WHERE code = 'HTL-HCM-01';

    SELECT id INTO v_rt_hn01_dlx  FROM room_types WHERE hotel_id = v_htl_hn01  AND code = 'DLX';
    SELECT id INTO v_rt_hn02_dlx  FROM room_types WHERE hotel_id = v_htl_hn02  AND code = 'DLX';
    SELECT id INTO v_rt_dn01_dlx  FROM room_types WHERE hotel_id = v_htl_dn01  AND code = 'DLX';
    SELECT id INTO v_rt_hcm01_dlx FROM room_types WHERE hotel_id = v_htl_hcm01 AND code = 'DLX';

    SELECT id INTO v_pol_hn01  FROM cancellation_policies WHERE hotel_id = v_htl_hn01  AND is_default = TRUE;
    SELECT id INTO v_pol_hn02  FROM cancellation_policies WHERE hotel_id = v_htl_hn02  AND is_default = TRUE;
    SELECT id INTO v_pol_dn01  FROM cancellation_policies WHERE hotel_id = v_htl_dn01  AND is_default = TRUE;
    SELECT id INTO v_pol_hcm01 FROM cancellation_policies WHERE hotel_id = v_htl_hcm01 AND is_default = TRUE;

    SELECT id INTO v_room_1  FROM rooms WHERE room_type_id = v_rt_hn01_dlx  AND room_number = 'DLX-01';
    SELECT id INTO v_room_2  FROM rooms WHERE room_type_id = v_rt_hn01_dlx  AND room_number = 'DLX-02';
    SELECT id INTO v_room_3  FROM rooms WHERE room_type_id = v_rt_dn01_dlx  AND room_number = 'DLX-01';
    SELECT id INTO v_room_ci FROM rooms WHERE room_type_id = v_rt_hcm01_dlx AND room_number = 'DLX-01';

    PERFORM set_config('app.current_actor_id', v_cust_an::TEXT, TRUE);

    -- (A) Ví dụ đối chứng Mục III.4: 2 phòng Deluxe x 2 đêm (1.0M + 1.2M) = 4.4M; giảm 200k => 4.2M; hoa hồng 15% = 660k; payout = 3.74M
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount,
        created_at
    ) VALUES (
        'BK-DEMO-REF01', v_cust_an, v_htl_hn01, v_promo_200k, v_pol_hn01,
        CURRENT_DATE - 10, CURRENT_DATE - 8, 4, 'COMPLETED',
        15.00, 4400000, 200000, 4200000, 660000,
        NOW() - INTERVAL '15 days'
    ) RETURNING id INTO v_b_ref;

    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total) VALUES
    (v_b_ref, 1, v_htl_hn01, v_rt_hn01_dlx, v_room_1, 1, 2, 1100000, 2200000),
    (v_b_ref, 2, v_htl_hn01, v_rt_hn01_dlx, v_room_2, 1, 2, 1100000, 2200000);

    INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot) VALUES
    (v_b_ref, v_rt_hn01_dlx, CURRENT_DATE - 10, 2, 1000000),
    (v_b_ref, v_rt_hn01_dlx, CURRENT_DATE - 9,  2, 1200000);

    UPDATE room_inventory SET booked_count = booked_count + 2
     WHERE room_type_id = v_rt_hn01_dlx AND stay_date IN (CURRENT_DATE - 10, CURRENT_DATE - 9);

    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at) VALUES
    (v_b_ref, 'CHARGE', 'MOCK_CARD', 4200000, 'SUCCESS', 'seed-charge-ref01', NOW() - INTERVAL '15 days');

    -- Chốt kỳ đối soát đã PAID cho đơn ví dụ đối chứng (3.740.000đ)
    PERFORM set_config('app.current_actor_id', v_accountant_id::TEXT, TRUE);
    INSERT INTO settlement_batches (batch_code, period_start, period_end, created_by, status)
    VALUES ('STL-DEMO-001', CURRENT_DATE - 20, CURRENT_DATE - 7, v_accountant_id, 'PAID')
    RETURNING id INTO v_batch_id;

    INSERT INTO partner_payouts (batch_id, partner_id, gross_amount, commission_total, net_payout, status, paid_at, payment_reference)
    VALUES (
        v_batch_id,
        (SELECT partner_id FROM hotels WHERE id = v_htl_hn01),
        4400000, 660000, 3740000, 'PAID', NOW() - INTERVAL '5 days', 'UNC-DEMO-001'
    ) RETURNING id INTO v_payout_id;

    INSERT INTO payout_items (payout_id, booking_id, booking_amount, commission_amount, net_amount)
    VALUES (v_payout_id, v_b_ref, 4400000, 660000, 3740000);
    PERFORM set_config('app.current_actor_id', v_cust_an::TEXT, TRUE);

    -- (B) Đơn COMPLETED chưa đối soát tại Đà Nẵng (dùng cho Q15 & test T12)
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount,
        created_at
    ) VALUES (
        'BK-DEMO-CMP02', v_cust_binh, v_htl_dn01, v_promo_he, v_pol_dn01,
        CURRENT_DATE - 5, CURRENT_DATE - 3, 2, 'COMPLETED',
        15.00, 4400000, 440000, 3960000, 660000,
        NOW() - INTERVAL '12 days'
    ) RETURNING id INTO v_b_unsettled;

    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total) VALUES
    (v_b_unsettled, 1, v_htl_dn01, v_rt_dn01_dlx, v_room_3, 1, 2, 2200000, 4400000);

    INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot) VALUES
    (v_b_unsettled, v_rt_dn01_dlx, CURRENT_DATE - 5, 1, 2200000),
    (v_b_unsettled, v_rt_dn01_dlx, CURRENT_DATE - 4, 1, 2200000);

    UPDATE room_inventory SET booked_count = booked_count + 1
     WHERE room_type_id = v_rt_dn01_dlx AND stay_date IN (CURRENT_DATE - 5, CURRENT_DATE - 4);

    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at) VALUES
    (v_b_unsettled, 'CHARGE', 'MOCK_BANK_TRANSFER', 3960000, 'SUCCESS', 'seed-charge-cmp02', NOW() - INTERVAL '12 days');

    -- (C) Đơn CHECKED_IN đang lưu trú tại TP.HCM (phòng DLX-01 OCCUPIED -> dùng test Q19)
    --     Tính tổng tiền trực tiếp từ room_inventory để đồng bộ tuyệt đối với booking_night_rates (Q18)
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount
    )
    SELECT 'BK-DEMO-CKI03', v_cust_chi, v_htl_hcm01, NULL, v_pol_hcm01,
           CURRENT_DATE, CURRENT_DATE + 2, 2, 'CHECKED_IN',
           14.00, SUM(ri.nightly_price), 0, SUM(ri.nightly_price), ROUND(SUM(ri.nightly_price) * 14.00 / 100.0, 0)
      FROM room_inventory ri
     WHERE ri.room_type_id = v_rt_hcm01_dlx
       AND ri.stay_date IN (CURRENT_DATE, CURRENT_DATE + 1)
    RETURNING id INTO v_b_checked_in;

    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total)
    SELECT v_b_checked_in, 1, v_htl_hcm01, v_rt_hcm01_dlx, v_room_ci, 1, 2,
           ROUND(b.room_subtotal / 2.0, 0), b.room_subtotal
      FROM bookings b WHERE b.id = v_b_checked_in;

    UPDATE rooms SET status = 'OCCUPIED' WHERE id = v_room_ci;

    INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot)
    SELECT v_b_checked_in, ri.room_type_id, ri.stay_date, 1, ri.nightly_price
      FROM room_inventory ri
     WHERE ri.room_type_id = v_rt_hcm01_dlx
       AND ri.stay_date IN (CURRENT_DATE, CURRENT_DATE + 1);

    UPDATE room_inventory SET booked_count = booked_count + 1
     WHERE room_type_id = v_rt_hcm01_dlx AND stay_date IN (CURRENT_DATE, CURRENT_DATE + 1);

    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at)
    SELECT v_b_checked_in, 'CHARGE', 'MOCK_WALLET', b.total_amount, 'SUCCESS', 'seed-charge-cki03', NOW() - INTERVAL '2 days'
      FROM bookings b WHERE b.id = v_b_checked_in;

    -- (D) Đơn CONFIRMED sắp nhận phòng tại Hồ Tây
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount
    )
    SELECT 'BK-DEMO-CNF04', v_cust_dung, v_htl_hn02, NULL, v_pol_hn02,
           CURRENT_DATE + 5, CURRENT_DATE + 7, 2, 'CONFIRMED',
           12.00, SUM(ri.nightly_price), 0, SUM(ri.nightly_price), ROUND(SUM(ri.nightly_price) * 12.00 / 100.0, 0)
      FROM room_inventory ri
     WHERE ri.room_type_id = v_rt_hn02_dlx
       AND ri.stay_date IN (CURRENT_DATE + 5, CURRENT_DATE + 6)
    RETURNING id INTO v_b_confirmed;

    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total)
    SELECT v_b_confirmed, 1, v_htl_hn02, v_rt_hn02_dlx, NULL, 1, 2,
           ROUND(b.room_subtotal / 2.0, 0), b.room_subtotal
      FROM bookings b WHERE b.id = v_b_confirmed;

    INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot)
    SELECT v_b_confirmed, ri.room_type_id, ri.stay_date, 1, ri.nightly_price
      FROM room_inventory ri
     WHERE ri.room_type_id = v_rt_hn02_dlx
       AND ri.stay_date IN (CURRENT_DATE + 5, CURRENT_DATE + 6);

    UPDATE room_inventory SET booked_count = booked_count + 1
     WHERE room_type_id = v_rt_hn02_dlx AND stay_date IN (CURRENT_DATE + 5, CURRENT_DATE + 6);

    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at)
    SELECT v_b_confirmed, 'CHARGE', 'MOCK_CARD', b.total_amount, 'SUCCESS', 'seed-charge-cnf04', NOW() - INTERVAL '1 day'
      FROM bookings b WHERE b.id = v_b_confirmed;

    -- (E) Đơn HOLD đang giữ chỗ tại Hà Nội
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount,
        hold_expires_at
    )
    SELECT 'BK-DEMO-HLD05', v_cust_em, v_htl_hn01, NULL, v_pol_hn01,
           CURRENT_DATE + 3, CURRENT_DATE + 4, 2, 'HOLD',
           15.00, ri.nightly_price, 0, ri.nightly_price, ROUND(ri.nightly_price * 15.00 / 100.0, 0),
           NOW() + INTERVAL '15 minutes'
      FROM room_inventory ri
     WHERE ri.room_type_id = v_rt_hn01_dlx
       AND ri.stay_date = CURRENT_DATE + 3
    RETURNING id INTO v_b_hold;

    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total)
    SELECT v_b_hold, 1, v_htl_hn01, v_rt_hn01_dlx, NULL, 1, 1, b.room_subtotal, b.room_subtotal
      FROM bookings b WHERE b.id = v_b_hold;

    INSERT INTO booking_night_rates (booking_id, room_type_id, stay_date, quantity, nightly_price_snapshot)
    SELECT v_b_hold, ri.room_type_id, ri.stay_date, 1, ri.nightly_price
      FROM room_inventory ri
     WHERE ri.room_type_id = v_rt_hn01_dlx AND ri.stay_date = CURRENT_DATE + 3;

    UPDATE room_inventory SET held_count = held_count + 1
     WHERE room_type_id = v_rt_hn01_dlx AND stay_date = CURRENT_DATE + 3;

    -- (F) Đơn CANCELLED có giao dịch CHARGE + REFUND
    INSERT INTO bookings (
        booking_code, customer_id, hotel_id, promotion_id, policy_id,
        check_in_date, check_out_date, guest_count, status,
        commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount,
        cancelled_at, cancel_reason
    ) VALUES (
        'BK-DEMO-CXL06', v_cust_an, v_htl_dn01, NULL, v_pol_dn01,
        CURRENT_DATE + 10, CURRENT_DATE + 11, 2, 'CANCELLED',
        15.00, 2200000, 0, 2200000, 330000,
        NOW() - INTERVAL '1 day', 'Khách đổi lịch công tác'
    ) RETURNING id INTO v_b_cancelled;

    INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, assigned_room_id, quantity, nights, unit_price_avg, line_total) VALUES
    (v_b_cancelled, 1, v_htl_dn01, v_rt_dn01_dlx, NULL, 1, 1, 2200000, 2200000);

    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key, paid_at) VALUES
    (v_b_cancelled, 'CHARGE', 'MOCK_CARD',           2200000, 'SUCCESS', 'seed-charge-cxl06', NOW() - INTERVAL '3 days'),
    (v_b_cancelled, 'REFUND', 'INTERNAL_ADJUSTMENT', 2200000, 'SUCCESS', 'seed-refund-cxl06', NOW() - INTERVAL '1 day');

    -- Đánh giá sau lưu trú (VISIBLE cho 2 đơn COMPLETED)
    INSERT INTO reviews (booking_id, customer_id, hotel_id, rating, comment, moderation_status) VALUES
    (v_b_ref,       v_cust_an,   v_htl_hn01, 5, 'Phòng Deluxe sạch sẽ, ngay trung tâm Phố Cổ.', 'VISIBLE'),
    (v_b_unsettled, v_cust_binh, v_htl_dn01, 4, 'View biển Mỹ Khê rất đẹp, bữa sáng phong phú.', 'VISIBLE');

    -- Ticket hỗ trợ đã đóng kèm ghi chú nội bộ (dùng cho Q16, T15)
    INSERT INTO support_tickets (ticket_code, booking_id, customer_id, assigned_staff_id, category, priority, status, subject, created_at, resolved_at)
    VALUES (
        'TK-DEMO-001', v_b_cancelled, v_cust_an, v_support_id,
        'REFUND', 'HIGH', 'CLOSED', 'Xác nhận thời gian hoàn tiền về thẻ',
        NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day'
    ) RETURNING id INTO v_ticket_id;

    INSERT INTO ticket_messages (ticket_id, seq_no, sender_id, message_body, is_internal_note, created_at) VALUES
    (v_ticket_id, 1, v_cust_an,    'Tôi đã hủy trước 48h, nhờ kiểm tra giúp lệnh hoàn tiền.', FALSE, NOW() - INTERVAL '2 days'),
    (v_ticket_id, 2, v_support_id, 'Đã kiểm tra policy 48h hợp lệ, chuyển kế toán đối soát hoàn 100%.', TRUE,  NOW() - INTERVAL '36 hours'),
    (v_ticket_id, 3, v_support_id, 'Hệ thống đã hoàn đủ 2.200.000 VND cho quý khách.', FALSE, NOW() - INTERVAL '1 day');

    -- Điều chỉnh lại sequence code tránh đụng mã seed
    PERFORM setval('seq_booking_code', 2000);
    PERFORM setval('seq_batch_code', 200);
END;
$$;

COMMIT;
