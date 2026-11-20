-- =============================================================================
-- 02_indexes.sql
-- Hệ thống chỉ mục tối ưu tìm kiếm, quét hết hạn giữ chỗ, báo cáo & kiểm toán
-- Bao gồm Composite, Partial, Covering (INCLUDE) và GIN Index
-- =============================================================================

-- 1. Composite index: Tra cứu đơn theo khách sạn, trạng thái và khoảng ngày lưu trú
CREATE INDEX idx_bookings_hotel_status_dates
    ON bookings (hotel_id, status, check_in_date, check_out_date);

-- 2. Partial index: Tối ưu tác vụ quét giải phóng đơn giữ chỗ quá hạn (HOLD / PENDING_PAYMENT)
CREATE INDEX idx_bookings_active_holds
    ON bookings (hold_expires_at)
    WHERE status IN ('HOLD', 'PENDING_PAYMENT');

-- 3. Covering + Partial index: Index-only scan tìm phòng trống theo ngày đang mở bán
CREATE INDEX idx_inventory_avail_cover
    ON room_inventory (room_type_id, stay_date)
    INCLUDE (total_allotment, booked_count, held_count, nightly_price)
    WHERE is_closed = FALSE;

-- 4. Composite index: Lịch sử đặt phòng của khách hàng theo thứ tự mới nhất
CREATE INDEX idx_bookings_customer_created
    ON bookings (customer_id, created_at DESC);

-- 5. Composite + GIN index: Truy vết nhật ký kiểm toán theo thực thể, thời gian và nội dung JSONB
CREATE INDEX idx_audit_entity_time
    ON audit_logs (entity_type, entity_id, created_at DESC);

CREATE INDEX idx_audit_new_data_gin
    ON audit_logs USING GIN (new_data);

-- 6. Partial Composite index: Tìm kiếm khách sạn đã duyệt theo địa điểm, hạng sao và điểm đánh giá
CREATE INDEX idx_hotels_location_rating
    ON hotels (location_id, star_rating, avg_rating DESC)
    WHERE approval_status = 'APPROVED' AND is_active = TRUE;

-- 7. B-tree index: Hỗ trợ CTE đệ quy duyệt cây địa điểm phân cấp
CREATE INDEX idx_locations_parent
    ON locations (parent_id);

-- Chỉ mục hỗ trợ truy vấn đối soát, thanh toán và ticket nhanh trên tập 100k+ dòng
CREATE INDEX idx_bookings_status_checkout
    ON bookings (status, check_out_date)
    WHERE status = 'COMPLETED';

CREATE INDEX idx_payments_booking_type_status
    ON payments (booking_id, payment_type, status);

CREATE INDEX idx_tickets_staff_status
    ON support_tickets (assigned_staff_id, status, created_at DESC);
