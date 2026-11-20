-- =============================================================================
-- 06_views.sql
-- 03 View nghiệp vụ & phân quyền (v_public_hotel_listings ẩn thông tin nhạy cảm)
-- =============================================================================

-- 1. v_public_hotel_listings (View phân quyền cho khách hàng & reporting_ro)
--    Chỉ hiển thị khách sạn APPROVED & is_active = TRUE;
--    ẨN hoàn toàn commission_rate, partner_id, tax_code, bank_account, bank_name.
CREATE OR REPLACE VIEW v_public_hotel_listings AS
SELECT
    h.id          AS hotel_id,
    h.code        AS hotel_code,
    h.name        AS hotel_name,
    h.address,
    h.description,
    h.star_rating,
    h.avg_rating,
    h.review_count,
    l.id          AS location_id,
    l.code        AS location_code,
    l.name        AS location_name,
    l.level       AS location_level,
    l.parent_id   AS parent_location_id,
    (
        SELECT MIN(rt.base_price)
          FROM room_types rt
         WHERE rt.hotel_id = h.id
           AND rt.is_active = TRUE
    ) AS min_base_price,
    COALESCE(
        (
            SELECT ARRAY_AGG(a.name ORDER BY a.name)
              FROM hotel_amenities ha
              JOIN amenities a ON a.id = ha.amenity_id
             WHERE ha.hotel_id = h.id
        ),
        ARRAY[]::VARCHAR[]
    ) AS amenity_names
FROM hotels h
JOIN locations l ON l.id = h.location_id
WHERE h.approval_status = 'APPROVED'
  AND h.is_active = TRUE;

-- 2. v_hotel_daily_occupancy: Tỷ lệ lấp đầy & doanh thu dự kiến theo khách sạn/ngày
CREATE OR REPLACE VIEW v_hotel_daily_occupancy AS
SELECT
    h.id   AS hotel_id,
    h.code AS hotel_code,
    h.name AS hotel_name,
    ri.stay_date,
    SUM(ri.total_allotment)::INT AS total_allotment,
    SUM(ri.booked_count)::INT    AS booked_count,
    SUM(ri.held_count)::INT      AS held_count,
    SUM(ri.total_allotment - ri.booked_count - ri.held_count)::INT AS available_rooms,
    ROUND(
        SUM(ri.booked_count)::NUMERIC * 100.0 / NULLIF(SUM(ri.total_allotment), 0),
        2
    ) AS occupancy_rate_pct,
    SUM(ri.booked_count * ri.nightly_price)::NUMERIC(18, 0) AS booked_gross_estimate
FROM hotels h
JOIN room_types rt ON rt.hotel_id = h.id
JOIN room_inventory ri ON ri.room_type_id = rt.id
GROUP BY h.id, h.code, h.name, ri.stay_date;

-- 3. v_partner_settlement_overview: Tổng hợp doanh thu, hoa hồng & công nợ chi trả theo đối tác
CREATE OR REPLACE VIEW v_partner_settlement_overview AS
SELECT
    pp.user_id       AS partner_id,
    pp.business_name,
    pp.kyc_status,
    COUNT(DISTINCT b.id) FILTER (WHERE b.status = 'COMPLETED') AS completed_bookings_count,
    COALESCE(SUM(b.room_subtotal) FILTER (WHERE b.status = 'COMPLETED'), 0)::NUMERIC(18, 0)
        AS total_completed_gross,
    COALESCE(SUM(b.commission_amount) FILTER (WHERE b.status = 'COMPLETED'), 0)::NUMERIC(18, 0)
        AS total_completed_commission,
    COALESCE((
        SELECT SUM(pay.net_payout)
          FROM partner_payouts pay
         WHERE pay.partner_id = pp.user_id AND pay.status = 'PAID'
    ), 0)::NUMERIC(18, 0) AS paid_net_payout,
    COALESCE((
        SELECT SUM(pay.net_payout)
          FROM partner_payouts pay
         WHERE pay.partner_id = pp.user_id AND pay.status = 'PENDING'
    ), 0)::NUMERIC(18, 0) AS pending_net_payout,
    COALESCE(SUM(b.room_subtotal - b.commission_amount) FILTER (
        WHERE b.status = 'COMPLETED'
          AND NOT EXISTS (SELECT 1 FROM payout_items pi WHERE pi.booking_id = b.id)
    ), 0)::NUMERIC(18, 0) AS unsettled_net_amount
FROM partner_profiles pp
LEFT JOIN hotels h ON h.partner_id = pp.user_id
LEFT JOIN bookings b ON b.hotel_id = h.id
GROUP BY pp.user_id, pp.business_name, pp.kyc_status;
