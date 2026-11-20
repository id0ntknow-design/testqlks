-- =============================================================================
-- q01_to_q20.sql
-- Bộ 20 truy vấn nghiệp vụ minh họa (Q01 - Q20) theo mục V.4 đề cương
-- =============================================================================

\echo '=== Q01: Tìm loại phòng còn đủ số lượng cho toàn bộ đêm [check_in, check_out) tại một khu vực ==='
WITH RECURSIVE target_dates AS (
    SELECT CURRENT_DATE + 1 AS check_in,
           CURRENT_DATE + 3 AS check_out,
           2::INT           AS qty_needed,
           'VN-HN'::TEXT    AS province_code
),
recursive_locs AS (
    SELECT l.id
      FROM locations l, target_dates td
     WHERE l.code = td.province_code
    UNION ALL
    SELECT c.id
      FROM locations c
      JOIN recursive_locs p ON c.parent_id = p.id
)
SELECT h.code AS hotel_code,
       h.name AS hotel_name,
       rt.code AS room_type_code,
       rt.name AS room_type_name,
       MIN(ri.total_allotment - ri.booked_count - ri.held_count) AS min_available_rooms,
       SUM(ri.nightly_price * td.qty_needed) AS estimated_room_subtotal
FROM target_dates td
JOIN hotels h ON h.location_id IN (SELECT id FROM recursive_locs)
JOIN room_types rt ON rt.hotel_id = h.id
JOIN room_inventory ri ON ri.room_type_id = rt.id
WHERE h.approval_status = 'APPROVED'
  AND h.is_active = TRUE
  AND rt.is_active = TRUE
  AND ri.stay_date >= td.check_in
  AND ri.stay_date < td.check_out
  AND NOT EXISTS (
      SELECT 1
        FROM generate_series(td.check_in, td.check_out - 1, INTERVAL '1 day') AS d(stay_dt)
        LEFT JOIN room_inventory ri2
          ON ri2.room_type_id = rt.id
         AND ri2.stay_date = d.stay_dt::DATE
       WHERE ri2.room_type_id IS NULL
          OR ri2.is_closed = TRUE
          OR (ri2.total_allotment - ri2.booked_count - ri2.held_count) < td.qty_needed
  )
GROUP BY h.code, h.name, rt.code, rt.name
ORDER BY estimated_room_subtotal ASC;

\echo '=== Q02: Liệt kê tất cả khách sạn đã duyệt kèm số đánh giá & số đơn (kể cả chưa có đơn) ==='
SELECT h.code,
       h.name,
       h.star_rating,
       COALESCE(COUNT(DISTINCT b.id), 0) AS total_bookings,
       COALESCE(COUNT(DISTINCT r.id) FILTER (WHERE r.moderation_status = 'VISIBLE'), 0) AS visible_reviews,
       COALESCE(ROUND(AVG(r.rating) FILTER (WHERE r.moderation_status = 'VISIBLE'), 2), 0.00) AS computed_avg_rating
FROM hotels h
LEFT OUTER JOIN bookings b ON b.hotel_id = h.id
LEFT OUTER JOIN reviews r  ON r.hotel_id = h.id
WHERE h.approval_status = 'APPROVED'
  AND h.is_active = TRUE
GROUP BY h.id, h.code, h.name, h.star_rating
ORDER BY total_bookings DESC, h.code ASC;

\echo '=== Q03: Chi tiết đầy đủ một đơn đặt phòng (khách sạn, hạng phòng, giá từng đêm, thanh toán) ==='
WITH pay_summary AS (
    SELECT p.booking_id,
           COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'SUCCESS' AND p.payment_type = 'CHARGE'), 0) AS total_paid
      FROM payments p
     GROUP BY p.booking_id
)
SELECT b.booking_code,
       b.status,
       u.full_name AS customer_name,
       h.name AS hotel_name,
       rt.name AS room_type_name,
       COUNT(DISTINCT bi.line_no) AS room_count,
       JSONB_AGG(DISTINCT JSONB_BUILD_OBJECT('stay_date', bnr.stay_date, 'qty', bnr.quantity, 'price', bnr.nightly_price_snapshot)) AS night_rates,
       COALESCE(ps.total_paid, 0) AS total_paid
FROM bookings b
JOIN users u ON u.id = b.customer_id
JOIN hotels h ON h.id = b.hotel_id
JOIN booking_items bi ON bi.booking_id = b.id
JOIN room_types rt ON rt.id = bi.room_type_id
JOIN booking_night_rates bnr ON bnr.booking_id = b.id AND bnr.room_type_id = bi.room_type_id
LEFT JOIN pay_summary ps ON ps.booking_id = b.id
WHERE b.booking_code = 'BK-DEMO-REF01'
GROUP BY b.id, b.booking_code, b.status, u.full_name, h.name, rt.name, ps.total_paid;

\echo '=== Q04: Tìm toàn bộ khách sạn nằm trong tỉnh/thành phố và mọi cấp con (CTE đệ quy) ==='
WITH RECURSIVE loc_tree AS (
    SELECT id, parent_id, code, name, level, name::TEXT AS path
      FROM locations
     WHERE code = 'VN-HN'
    UNION ALL
    SELECT c.id, c.parent_id, c.code, c.name, c.level, lt.path || ' > ' || c.name
      FROM locations c
      JOIN loc_tree lt ON c.parent_id = lt.id
)
SELECT h.code, h.name, h.star_rating, lt.level, lt.path AS location_hierarchy
FROM hotels h
JOIN loc_tree lt ON lt.id = h.location_id
WHERE h.approval_status = 'APPROVED'
ORDER BY h.star_rating DESC, h.code;

\echo '=== Q05: Lọc khách sạn có nhiều đánh giá hiển thị và điểm trung bình >= 4.5 (GROUP BY + HAVING) ==='
-- Ngưỡng ví dụ >= 1 trên bộ demo nhỏ (trên tập 100k thay >= 10)
SELECT h.code,
       h.name,
       COUNT(r.id) AS visible_review_count,
       ROUND(AVG(r.rating), 2) AS avg_score
FROM hotels h
JOIN reviews r ON r.hotel_id = h.id
WHERE r.moderation_status = 'VISIBLE'
GROUP BY h.id, h.code, h.name
HAVING COUNT(r.id) >= 1
   AND AVG(r.rating) >= 4.5
ORDER BY avg_score DESC;

\echo '=== Q06: Xếp hạng khách sạn theo tổng doanh thu thuần trong từng tỉnh/thành phố (DENSE_RANK) ==='
WITH RECURSIVE loc_province AS (
    SELECT id, parent_id, name, level, id AS root_province_id, name AS province_name
      FROM locations
     WHERE level = 'PROVINCE'
    UNION ALL
    SELECT c.id, c.parent_id, c.name, c.level, lp.root_province_id, lp.province_name
      FROM locations c
      JOIN loc_province lp ON c.parent_id = lp.id
),
hotel_rev AS (
    SELECT lp.province_name,
           h.code,
           h.name,
           COALESCE(SUM(b.room_subtotal - b.commission_amount) FILTER (WHERE b.status IN ('CONFIRMED','CHECKED_IN','COMPLETED')), 0) AS net_partner_revenue
      FROM hotels h
      JOIN loc_province lp ON lp.id = h.location_id
      LEFT JOIN bookings b ON b.hotel_id = h.id
     WHERE h.approval_status = 'APPROVED'
     GROUP BY lp.province_name, h.id, h.code, h.name
)
SELECT province_name,
       code,
       name,
       net_partner_revenue,
       DENSE_RANK() OVER (PARTITION BY province_name ORDER BY net_partner_revenue DESC) AS city_rank
FROM hotel_rev
ORDER BY province_name, city_rank, code;

\echo '=== Q07: Khách hàng có tổng chi tiêu lớn hơn trung bình khách đặt cùng hạng sao (Correlated Subquery) ==='
SELECT u.id,
       u.full_name,
       h.star_rating,
       SUM(b.total_amount) AS customer_spend
FROM bookings b
JOIN users u ON u.id = b.customer_id
JOIN hotels h ON h.id = b.hotel_id
WHERE b.status IN ('CONFIRMED', 'CHECKED_IN', 'COMPLETED')
GROUP BY u.id, u.full_name, h.star_rating
HAVING SUM(b.total_amount) > (
    SELECT AVG(sub.total_spent)
      FROM (
          SELECT b2.customer_id, SUM(b2.total_amount) AS total_spent
            FROM bookings b2
            JOIN hotels h2 ON h2.id = b2.hotel_id
           WHERE b2.status IN ('CONFIRMED', 'CHECKED_IN', 'COMPLETED')
             AND h2.star_rating = h.star_rating
           GROUP BY b2.customer_id
      ) AS sub
)
ORDER BY customer_spend DESC;

\echo '=== Q08: Doanh thu gộp, hoàn tiền, doanh thu ròng & hoa hồng theo tháng và phương thức thanh toán ==='
WITH booking_pay_agg AS (
    SELECT DATE_TRUNC('month', COALESCE(p.paid_at, p.created_at))::DATE AS pay_month,
           p.method,
           p.booking_id,
           b.status AS booking_status,
           b.commission_amount,
           COALESCE(SUM(p.amount) FILTER (WHERE p.payment_type = 'CHARGE' AND p.status = 'SUCCESS'), 0) AS charged_amt,
           COALESCE(SUM(p.amount) FILTER (WHERE p.payment_type = 'REFUND' AND p.status = 'SUCCESS'), 0) AS refunded_amt
      FROM payments p
      JOIN bookings b ON b.id = p.booking_id
      JOIN hotels h ON h.id = b.hotel_id
     GROUP BY DATE_TRUNC('month', COALESCE(p.paid_at, p.created_at))::DATE, p.method, p.booking_id, b.status, b.commission_amount
)
SELECT pay_month,
       method,
       SUM(charged_amt) AS gross_charged,
       SUM(refunded_amt) AS total_refunded,
       SUM(charged_amt - refunded_amt) AS net_cashflow,
       COALESCE(SUM(commission_amount) FILTER (WHERE charged_amt > 0 AND booking_status = 'COMPLETED'), 0) AS completed_commission
FROM booking_pay_agg
GROUP BY pay_month, method
ORDER BY pay_month DESC, method;

\echo '=== Q09: Loại phòng có số ngày hết phòng (booked_count = total_allotment) vượt ngưỡng ==='
SELECT h.code AS hotel_code,
       rt.code AS room_type_code,
       rt.name AS room_type_name,
       COUNT(*) FILTER (WHERE ri.total_allotment > 0 AND ri.booked_count = ri.total_allotment) AS sold_out_days
FROM room_inventory ri
JOIN room_types rt ON rt.id = ri.room_type_id
JOIN hotels h ON h.id = rt.hotel_id
WHERE ri.stay_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
  AND ri.stay_date < (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month')::DATE
GROUP BY h.code, rt.id, rt.code, rt.name
HAVING COUNT(*) FILTER (WHERE ri.total_allotment > 0 AND ri.booked_count = ri.total_allotment) >= 0
ORDER BY sold_out_days DESC, h.code;

\echo '=== Q10: Doanh thu lũy kế theo ngày của một đối tác (Window Function SUM() OVER) ==='
WITH daily_partner_rev AS (
    SELECT b.check_in_date AS rev_date,
           SUM(b.room_subtotal) AS daily_gross
      FROM bookings b
      JOIN hotels h ON h.id = b.hotel_id
      JOIN users u ON u.id = h.partner_id
     WHERE u.email = 'doitac.hanoi@hotelota.vn'
       AND b.status IN ('CONFIRMED', 'CHECKED_IN', 'COMPLETED')
     GROUP BY b.check_in_date
)
SELECT rev_date,
       daily_gross,
       SUM(daily_gross) OVER (ORDER BY rev_date ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_gross
FROM daily_partner_rev
ORDER BY rev_date ASC;

\echo '=== Q11: Khách sạn sở hữu TẤT CẢ tiện ích bắt buộc (Phép chia quan hệ - Relational Division) ==='
WITH required_amenities AS (
    SELECT id FROM amenities WHERE code IN ('FREE_WIFI', 'POOL', 'PARKING')
)
SELECT h.code, h.name, h.star_rating
FROM hotels h
WHERE h.approval_status = 'APPROVED'
  AND NOT EXISTS (
      SELECT 1
        FROM required_amenities ra
       WHERE NOT EXISTS (
           SELECT 1
             FROM hotel_amenities ha
            WHERE ha.hotel_id = h.id
              AND ha.amenity_id = ra.id
       )
  )
ORDER BY h.code;

\echo '=== Q12: Khách sạn chưa từng bị mở ticket khiếu nại trong 6 tháng gần nhất (NOT EXISTS) ==='
SELECT h.code, h.name
FROM hotels h
WHERE h.approval_status = 'APPROVED'
  AND NOT EXISTS (
      SELECT 1
        FROM support_tickets st
        JOIN bookings b ON b.id = st.booking_id
       WHERE b.hotel_id = h.id
         AND st.created_at >= NOW() - INTERVAL '6 months'
  )
ORDER BY h.code;

\echo '=== Q13: Tỷ lệ hủy đơn (%) & tiền phạt giữ lại theo khách sạn ==='
SELECT h.code,
       h.name,
       COUNT(b.id) AS total_orders,
       COUNT(b.id) FILTER (WHERE b.status = 'CANCELLED') AS cancelled_orders,
       ROUND(
           COUNT(b.id) FILTER (WHERE b.status = 'CANCELLED')::NUMERIC * 100.0 / NULLIF(COUNT(b.id), 0),
           2
       ) AS cancel_rate_pct,
       COALESCE(SUM(
           CASE WHEN b.status = 'CANCELLED' THEN
               COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.booking_id = b.id AND p.payment_type = 'CHARGE' AND p.status = 'SUCCESS'), 0)
               - COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.booking_id = b.id AND p.payment_type = 'REFUND' AND p.status = 'SUCCESS'), 0)
           ELSE 0 END
       ), 0) AS retained_penalty_amount
FROM hotels h
JOIN bookings b ON b.hotel_id = h.id
GROUP BY h.id, h.code, h.name
HAVING COUNT(b.id) >= 1
ORDER BY cancel_rate_pct DESC, h.code;

\echo '=== Q14: So sánh công suất phòng thực tế của từng đối tác với trung bình toàn sàn trong quý ==='
WITH partner_occ AS (
    SELECT pp.user_id AS partner_id,
           pp.business_name,
           COALESCE(SUM(ri.booked_count), 0)::NUMERIC AS total_booked,
           COALESCE(SUM(ri.total_allotment), 0)::NUMERIC AS total_allotted,
           ROUND(COALESCE(SUM(ri.booked_count), 0)::NUMERIC * 100.0 / NULLIF(SUM(ri.total_allotment), 0), 2) AS occupancy_pct
      FROM partner_profiles pp
      JOIN hotels h ON h.partner_id = pp.user_id
      JOIN room_types rt ON rt.hotel_id = h.id
      JOIN room_inventory ri ON ri.room_type_id = rt.id
     WHERE ri.stay_date >= DATE_TRUNC('quarter', CURRENT_DATE)::DATE - INTERVAL '30 days'
       AND ri.stay_date <= CURRENT_DATE + 30
     GROUP BY pp.user_id, pp.business_name
),
platform_avg AS (
    SELECT ROUND(AVG(occupancy_pct), 2) AS avg_platform_occ_pct FROM partner_occ
)
SELECT po.partner_id,
       po.business_name,
       po.occupancy_pct,
       pa.avg_platform_occ_pct,
       (po.occupancy_pct - pa.avg_platform_occ_pct) AS diff_vs_platform_pct
FROM partner_occ po
CROSS JOIN platform_avg pa
ORDER BY po.occupancy_pct DESC;

\echo '=== Q15: Danh sách các đơn COMPLETED đủ điều kiện đối soát nhưng chưa từng được chi trả ==='
SELECT b.id,
       b.booking_code,
       h.code AS hotel_code,
       pp.business_name,
       b.check_out_date,
       b.room_subtotal,
       b.commission_amount,
       (b.room_subtotal - b.commission_amount) AS expected_net_payout
FROM bookings b
JOIN hotels h ON h.id = b.hotel_id
JOIN partner_profiles pp ON pp.user_id = h.partner_id
LEFT JOIN payout_items pi ON pi.booking_id = b.id
WHERE b.status = 'COMPLETED'
  AND pi.booking_id IS NULL
ORDER BY b.check_out_date ASC, b.id ASC;

\echo '=== Q16: Thời gian phản hồi đầu tiên & giải quyết trung bình của Nhân viên Hỗ trợ (ticket đã đóng) ==='
WITH first_staff_reply AS (
    SELECT tm.ticket_id,
           MIN(tm.created_at) AS first_reply_at
      FROM ticket_messages tm
      JOIN users u ON u.id = tm.sender_id
     WHERE u.role = 'SUPPORT'
     GROUP BY tm.ticket_id
)
SELECT staff.id AS staff_id,
       staff.full_name AS staff_name,
       COUNT(st.id) AS closed_tickets,
       ROUND(AVG(EXTRACT(EPOCH FROM (fsr.first_reply_at - st.created_at)) / 3600.0)::NUMERIC, 2) AS avg_first_response_hours,
       ROUND(AVG(EXTRACT(EPOCH FROM (st.resolved_at - st.created_at)) / 3600.0)::NUMERIC, 2) AS avg_resolution_hours
FROM support_tickets st
JOIN users staff ON staff.id = st.assigned_staff_id
LEFT JOIN first_staff_reply fsr ON fsr.ticket_id = st.id
WHERE st.status IN ('RESOLVED', 'CLOSED')
  AND st.resolved_at IS NOT NULL
GROUP BY staff.id, staff.full_name
HAVING COUNT(st.id) >= 1
ORDER BY avg_resolution_hours ASC;

\echo '=== Q17: Thống kê mức độ sử dụng và tổng tiền tài trợ của từng mã khuyến mãi ==='
SELECT p.code,
       p.name,
       p.usage_limit,
       p.used_count,
       COUNT(b.id) FILTER (WHERE b.status <> 'CANCELLED') AS active_or_completed_orders,
       COALESCE(SUM(b.discount_amount) FILTER (WHERE b.status <> 'CANCELLED'), 0) AS total_platform_subsidy
FROM promotions p
LEFT OUTER JOIN bookings b ON b.promotion_id = p.id
GROUP BY p.id, p.code, p.name, p.usage_limit, p.used_count
ORDER BY total_platform_subsidy DESC, p.code;

\echo '=== Q18: Kiểm tra đối chiếu chênh lệch giữa bookings.total_amount và tổng booking_night_rates - discount_amount ==='
SELECT b.id,
       b.booking_code,
       b.room_subtotal,
       COALESCE(SUM(bnr.quantity * bnr.nightly_price_snapshot), 0) AS sum_night_rates,
       b.discount_amount,
       b.total_amount,
       GREATEST(COALESCE(SUM(bnr.quantity * bnr.nightly_price_snapshot), 0) - b.discount_amount, 0) AS expected_total
FROM bookings b
JOIN booking_night_rates bnr ON bnr.booking_id = b.id
GROUP BY b.id, b.booking_code, b.room_subtotal, b.discount_amount, b.total_amount
HAVING b.room_subtotal <> COALESCE(SUM(bnr.quantity * bnr.nightly_price_snapshot), 0)
    OR b.total_amount <> GREATEST(COALESCE(SUM(bnr.quantity * bnr.nightly_price_snapshot), 0) - b.discount_amount, 0);

\echo '=== Q19: Tìm các phòng vật lý đang trống (không gắn đơn CHECKED_IN) theo hạng phòng của 1 khách sạn ==='
SELECT h.code AS hotel_code,
       rt.code AS room_type_code,
       r.id AS room_id,
       r.room_number,
       r.floor,
       r.status
FROM rooms r
JOIN room_types rt ON rt.id = r.room_type_id
JOIN hotels h ON h.id = rt.hotel_id
WHERE h.code = 'HTL-HCM-01'
  AND r.status = 'AVAILABLE'
  AND NOT EXISTS (
      SELECT 1
        FROM booking_items bi
        JOIN bookings b ON b.id = bi.booking_id
       WHERE bi.assigned_room_id = r.id
         AND b.status = 'CHECKED_IN'
  )
ORDER BY rt.code, r.room_number;

\echo '=== Q20: Truy vết lịch sử thao tác nhạy cảm kèm thông tin người thực hiện trong 30 ngày (JSONB) ==='
SELECT al.id,
       al.created_at,
       COALESCE(u.full_name, 'SYSTEM') AS actor_name,
       u.role AS actor_role,
       al.action,
       al.entity_type,
       al.entity_id,
       al.old_data->>'status' AS old_status,
       al.new_data->>'status' AS new_status
FROM audit_logs al
LEFT JOIN users u ON u.id = al.actor_id
WHERE al.created_at >= NOW() - INTERVAL '30 days'
ORDER BY al.created_at DESC, al.id DESC
LIMIT 25;
