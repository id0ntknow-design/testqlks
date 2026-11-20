-- =============================================================================
-- 01_schema_tables.sql
-- Lược đồ 22 bảng vật lý cho Hệ thống Đặt phòng Khách sạn Trực tuyến (OTA)
-- PostgreSQL 18 | Chuẩn >= 3NF | Ràng buộc toàn vẹn R01-R08
-- =============================================================================

-- -----------------------------------------------------------------------------
-- NHÓM A: NGƯỜI DÙNG, ĐỐI TÁC VÀ DANH MỤC NỀN (5 bảng)
-- -----------------------------------------------------------------------------

-- 1. users: Tài khoản chung 05 vai trò (A01-A05)
CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    phone         VARCHAR(20),
    role          VARCHAR(20)  NOT NULL
        CONSTRAINT chk_users_role CHECK (role IN ('ADMIN', 'PARTNER', 'CUSTOMER', 'SUPPORT', 'ACCOUNTANT')),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 2. partner_profiles: Hồ sơ kinh doanh & ngân hàng đối tác (quan hệ 1-1 với users)
CREATE TABLE partner_profiles (
    user_id          BIGINT       PRIMARY KEY
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    business_name    VARCHAR(200) NOT NULL,
    tax_code         VARCHAR(50)  NOT NULL UNIQUE,
    bank_account     VARCHAR(50)  NOT NULL,
    bank_name        VARCHAR(120) NOT NULL,
    bank_branch      VARCHAR(120),
    kyc_status       VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_partner_kyc_status CHECK (kyc_status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED')),
    rejection_reason TEXT,
    verified_by      BIGINT
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    verified_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 3. locations: Cây phân cấp địa điểm tự tham chiếu
CREATE TABLE locations (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id  BIGINT
        REFERENCES locations(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    code       VARCHAR(50)  NOT NULL UNIQUE,
    name       VARCHAR(150) NOT NULL,
    level      VARCHAR(20)  NOT NULL
        CONSTRAINT chk_locations_level CHECK (level IN ('COUNTRY', 'PROVINCE', 'DISTRICT', 'AREA')),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_locations_no_self_parent CHECK (parent_id IS DISTINCT FROM id)
);

-- 4. amenities: Danh mục tiện ích chuẩn toàn sàn
CREATE TABLE amenities (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       VARCHAR(50)  NOT NULL UNIQUE,
    name       VARCHAR(120) NOT NULL,
    category   VARCHAR(50)  NOT NULL
        CONSTRAINT chk_amenities_category CHECK (category IN ('GENERAL', 'ROOM', 'DINING', 'WELLNESS', 'BUSINESS', 'ACCESSIBILITY')),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 5. promotions: Mã giảm giá toàn sàn
CREATE TABLE promotions (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code                VARCHAR(50)    NOT NULL UNIQUE,
    name                VARCHAR(150)   NOT NULL,
    discount_type       VARCHAR(20)    NOT NULL
        CONSTRAINT chk_promotions_type CHECK (discount_type IN ('FIXED', 'PERCENT')),
    discount_value      NUMERIC(18, 2) NOT NULL
        CONSTRAINT chk_promotions_value_pos CHECK (discount_value > 0),
    max_discount_amount NUMERIC(18, 0)
        CONSTRAINT chk_promotions_max_discount CHECK (max_discount_amount IS NULL OR max_discount_amount >= 0),
    min_order_amount    NUMERIC(18, 0) NOT NULL DEFAULT 0
        CONSTRAINT chk_promotions_min_order CHECK (min_order_amount >= 0),
    valid_from          TIMESTAMPTZ    NOT NULL,
    valid_to            TIMESTAMPTZ    NOT NULL,
    usage_limit         INT            NOT NULL
        CONSTRAINT chk_promotions_usage_limit CHECK (usage_limit > 0),
    used_count          INT            NOT NULL DEFAULT 0
        CONSTRAINT chk_promotions_used_count CHECK (used_count >= 0 AND used_count <= usage_limit),
    is_active           BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_promotions_percent_cap CHECK (discount_type <> 'PERCENT' OR discount_value <= 100),
    CONSTRAINT chk_promotions_valid_range CHECK (valid_to > valid_from)
);

-- -----------------------------------------------------------------------------
-- NHÓM B: KHÁCH SẠN, PHÒNG VÀ QUỸ PHÒNG THEO NGÀY (6 bảng)
-- -----------------------------------------------------------------------------

-- 6. hotels: Thông tin khách sạn
CREATE TABLE hotels (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partner_id      BIGINT        NOT NULL
        REFERENCES partner_profiles(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    location_id     BIGINT        NOT NULL
        REFERENCES locations(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    code            VARCHAR(50)   NOT NULL UNIQUE,
    name            VARCHAR(200)  NOT NULL,
    address         VARCHAR(300)  NOT NULL,
    description     TEXT,
    star_rating     SMALLINT      NOT NULL
        CONSTRAINT chk_hotels_star_rating CHECK (star_rating BETWEEN 1 AND 5),
    approval_status VARCHAR(20)   NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_hotels_approval_status CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED')),
    commission_rate NUMERIC(5, 2) NOT NULL DEFAULT 15.00
        CONSTRAINT chk_hotels_commission_rate CHECK (commission_rate BETWEEN 0 AND 100),
    avg_rating      NUMERIC(3, 2) NOT NULL DEFAULT 0.00
        CONSTRAINT chk_hotels_avg_rating CHECK (avg_rating BETWEEN 0 AND 5),
    review_count    INT           NOT NULL DEFAULT 0
        CONSTRAINT chk_hotels_review_count CHECK (review_count >= 0),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 7. hotel_amenities: Liên kết N-N giữa khách sạn và tiện ích
CREATE TABLE hotel_amenities (
    hotel_id   BIGINT NOT NULL
        REFERENCES hotels(id) ON DELETE CASCADE ON UPDATE CASCADE,
    amenity_id BIGINT NOT NULL
        REFERENCES amenities(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    PRIMARY KEY (hotel_id, amenity_id)
);

-- 8. cancellation_policies: Chính sách hủy phòng theo khách sạn
CREATE TABLE cancellation_policies (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hotel_id          BIGINT        NOT NULL
        REFERENCES hotels(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    name              VARCHAR(150)  NOT NULL,
    free_cancel_hours INT           NOT NULL
        CONSTRAINT chk_policies_free_hours CHECK (free_cancel_hours >= 0),
    penalty_percent   NUMERIC(5, 2) NOT NULL
        CONSTRAINT chk_policies_penalty CHECK (penalty_percent BETWEEN 0 AND 100),
    is_default        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_cancellation_policies_id_hotel UNIQUE (id, hotel_id)
);

-- Mỗi khách sạn có tối đa 01 chính sách mặc định
CREATE UNIQUE INDEX uq_cancellation_policies_default
    ON cancellation_policies (hotel_id)
    WHERE is_default = TRUE;

-- 9. room_types: Hạng phòng thuộc khách sạn
CREATE TABLE room_types (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hotel_id     BIGINT         NOT NULL
        REFERENCES hotels(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    code         VARCHAR(50)    NOT NULL,
    name         VARCHAR(150)   NOT NULL,
    description  TEXT,
    max_adults   SMALLINT       NOT NULL
        CONSTRAINT chk_room_types_max_adults CHECK (max_adults > 0),
    max_children SMALLINT       NOT NULL DEFAULT 0
        CONSTRAINT chk_room_types_max_children CHECK (max_children >= 0),
    base_price   NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_room_types_base_price CHECK (base_price >= 0),
    total_rooms  INT            NOT NULL
        CONSTRAINT chk_room_types_total_rooms CHECK (total_rooms > 0),
    is_active    BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_room_types_hotel_code UNIQUE (hotel_id, code),
    CONSTRAINT uq_room_types_id_hotel UNIQUE (id, hotel_id)
);

-- 10. rooms: Phòng vật lý cụ thể
CREATE TABLE rooms (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_type_id BIGINT      NOT NULL
        REFERENCES room_types(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    room_number  VARCHAR(30) NOT NULL,
    floor        SMALLINT,
    status       VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
        CONSTRAINT chk_rooms_status CHECK (status IN ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE', 'OUT_OF_SERVICE')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_rooms_type_number UNIQUE (room_type_id, room_number),
    CONSTRAINT uq_rooms_id_type UNIQUE (id, room_type_id)
);

-- 11. room_inventory: Quỹ phòng và giá theo từng đêm
CREATE TABLE room_inventory (
    room_type_id    BIGINT         NOT NULL
        REFERENCES room_types(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    stay_date       DATE           NOT NULL,
    total_allotment INT            NOT NULL
        CONSTRAINT chk_inventory_allotment CHECK (total_allotment >= 0),
    booked_count    INT            NOT NULL DEFAULT 0
        CONSTRAINT chk_inventory_booked CHECK (booked_count >= 0),
    held_count      INT            NOT NULL DEFAULT 0
        CONSTRAINT chk_inventory_held CHECK (held_count >= 0),
    nightly_price   NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_inventory_price CHECK (nightly_price >= 0),
    is_closed       BOOLEAN        NOT NULL DEFAULT FALSE,
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (room_type_id, stay_date),
    CONSTRAINT chk_inventory_capacity CHECK (booked_count + held_count <= total_allotment)
);

-- -----------------------------------------------------------------------------
-- NHÓM C: ĐẶT PHÒNG, THANH TOÁN, ĐÁNH GIÁ, HỖ TRỢ, ĐỐI SOÁT & KIỂM TOÁN (11 bảng)
-- -----------------------------------------------------------------------------

-- 12. bookings: Đơn đặt phòng chính
CREATE TABLE bookings (
    id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_code             VARCHAR(32)    NOT NULL UNIQUE,
    customer_id              BIGINT         NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    hotel_id                 BIGINT         NOT NULL
        REFERENCES hotels(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    promotion_id             BIGINT
        REFERENCES promotions(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    policy_id                BIGINT         NOT NULL,
    check_in_date            DATE           NOT NULL,
    check_out_date           DATE           NOT NULL,
    guest_count              SMALLINT       NOT NULL
        CONSTRAINT chk_bookings_guest_count CHECK (guest_count > 0),
    status                   VARCHAR(20)    NOT NULL DEFAULT 'HOLD'
        CONSTRAINT chk_bookings_status CHECK (status IN ('HOLD', 'PENDING_PAYMENT', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED')),
    commission_rate_snapshot NUMERIC(5, 2)  NOT NULL
        CONSTRAINT chk_bookings_commission_rate CHECK (commission_rate_snapshot BETWEEN 0 AND 100),
    room_subtotal            NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_bookings_subtotal CHECK (room_subtotal >= 0),
    discount_amount          NUMERIC(18, 0) NOT NULL DEFAULT 0
        CONSTRAINT chk_bookings_discount CHECK (discount_amount >= 0),
    total_amount             NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_bookings_total CHECK (total_amount >= 0),
    commission_amount        NUMERIC(18, 0) NOT NULL DEFAULT 0
        CONSTRAINT chk_bookings_commission_amt CHECK (commission_amount >= 0),
    hold_expires_at          TIMESTAMPTZ,
    cancelled_at             TIMESTAMPTZ,
    cancel_reason            TEXT,
    created_at               TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_bookings_dates CHECK (check_out_date > check_in_date),
    CONSTRAINT chk_bookings_amount_math CHECK (total_amount = GREATEST(room_subtotal - discount_amount, 0)),
    CONSTRAINT fk_bookings_policy_hotel FOREIGN KEY (policy_id, hotel_id)
        REFERENCES cancellation_policies(id, hotel_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_bookings_id_hotel UNIQUE (id, hotel_id)
);

-- 13. booking_items: Thực thể yếu chi tiết hạng mục đặt & gán phòng vật lý
CREATE TABLE booking_items (
    booking_id       BIGINT         NOT NULL,
    line_no          INT            NOT NULL
        CONSTRAINT chk_booking_items_line_no CHECK (line_no > 0),
    hotel_id         BIGINT         NOT NULL,
    room_type_id     BIGINT         NOT NULL,
    assigned_room_id BIGINT,
    quantity         INT            NOT NULL
        CONSTRAINT chk_booking_items_qty CHECK (quantity > 0),
    nights           INT            NOT NULL
        CONSTRAINT chk_booking_items_nights CHECK (nights > 0),
    unit_price_avg   NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_booking_items_unit_price CHECK (unit_price_avg >= 0),
    line_total       NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_booking_items_line_total CHECK (line_total >= 0),
    PRIMARY KEY (booking_id, line_no),
    CONSTRAINT fk_booking_items_booking FOREIGN KEY (booking_id)
        REFERENCES bookings(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_booking_items_booking_hotel FOREIGN KEY (booking_id, hotel_id)
        REFERENCES bookings(id, hotel_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_booking_items_room_type_hotel FOREIGN KEY (room_type_id, hotel_id)
        REFERENCES room_types(id, hotel_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_booking_items_assigned_room FOREIGN KEY (assigned_room_id, room_type_id)
        REFERENCES rooms(id, room_type_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 14. booking_night_rates: Snapshot đơn giá từng đêm bất biến
CREATE TABLE booking_night_rates (
    id                     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id             BIGINT         NOT NULL
        REFERENCES bookings(id) ON DELETE CASCADE ON UPDATE CASCADE,
    room_type_id           BIGINT         NOT NULL
        REFERENCES room_types(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    stay_date              DATE           NOT NULL,
    quantity               INT            NOT NULL
        CONSTRAINT chk_bnr_qty CHECK (quantity > 0),
    nightly_price_snapshot NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_bnr_price CHECK (nightly_price_snapshot >= 0),
    CONSTRAINT uq_bnr_booking_type_date UNIQUE (booking_id, room_type_id, stay_date)
);

-- 15. payments: Giao dịch thu tiền và hoàn tiền (chống lặp idempotency_key)
CREATE TABLE payments (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id      BIGINT         NOT NULL
        REFERENCES bookings(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    payment_type    VARCHAR(20)    NOT NULL
        CONSTRAINT chk_payments_type CHECK (payment_type IN ('CHARGE', 'REFUND')),
    method          VARCHAR(30)    NOT NULL
        CONSTRAINT chk_payments_method CHECK (method IN ('MOCK_CARD', 'MOCK_BANK_TRANSFER', 'MOCK_WALLET', 'INTERNAL_ADJUSTMENT')),
    amount          NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payments_amount CHECK (amount > 0),
    status          VARCHAR(20)    NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_payments_status CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    idempotency_key VARCHAR(100)   NOT NULL UNIQUE,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- 16. reviews: Đánh giá sau lưu trú (1-1 với bookings)
CREATE TABLE reviews (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id        BIGINT      NOT NULL UNIQUE
        REFERENCES bookings(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    customer_id       BIGINT      NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    hotel_id          BIGINT      NOT NULL
        REFERENCES hotels(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    rating            SMALLINT    NOT NULL
        CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    comment           TEXT,
    moderation_status VARCHAR(20) NOT NULL DEFAULT 'VISIBLE'
        CONSTRAINT chk_reviews_moderation CHECK (moderation_status IN ('VISIBLE', 'HIDDEN')),
    moderation_reason TEXT,
    moderated_by      BIGINT
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. support_tickets: Phiếu yêu cầu hỗ trợ / khiếu nại
CREATE TABLE support_tickets (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_code       VARCHAR(32)  NOT NULL UNIQUE,
    booking_id        BIGINT
        REFERENCES bookings(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    customer_id       BIGINT       NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    assigned_staff_id BIGINT
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    category          VARCHAR(30)  NOT NULL
        CONSTRAINT chk_tickets_category CHECK (category IN ('BOOKING', 'PAYMENT', 'REFUND', 'SERVICE_QUALITY', 'PARTNER_DISPUTE', 'OTHER')),
    priority          VARCHAR(20)  NOT NULL DEFAULT 'MEDIUM'
        CONSTRAINT chk_tickets_priority CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
    status            VARCHAR(20)  NOT NULL DEFAULT 'OPEN'
        CONSTRAINT chk_tickets_status CHECK (status IN ('OPEN', 'IN_PROGRESS', 'WAITING_CUSTOMER', 'RESOLVED', 'CLOSED')),
    subject           VARCHAR(255) NOT NULL,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    resolved_at       TIMESTAMPTZ,
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 18. ticket_messages: Thực thể yếu lưu chuỗi tin nhắn & ghi chú nội bộ
CREATE TABLE ticket_messages (
    ticket_id        BIGINT      NOT NULL
        REFERENCES support_tickets(id) ON DELETE CASCADE ON UPDATE CASCADE,
    seq_no           INT         NOT NULL
        CONSTRAINT chk_ticket_messages_seq CHECK (seq_no > 0),
    sender_id        BIGINT      NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    message_body     TEXT        NOT NULL,
    is_internal_note BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ticket_id, seq_no)
);

-- 19. settlement_batches: Đợt đối soát định kỳ
CREATE TABLE settlement_batches (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_code   VARCHAR(32) NOT NULL UNIQUE,
    period_start DATE        NOT NULL,
    period_end   DATE        NOT NULL,
    created_by   BIGINT      NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    status       VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CONSTRAINT chk_settlement_batches_status CHECK (status IN ('DRAFT', 'FINALIZED', 'PAID')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_settlement_batches_period CHECK (period_end >= period_start)
);

-- 20. partner_payouts: Tổng hợp tiền phải trả cho từng đối tác trong kỳ
CREATE TABLE partner_payouts (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id          BIGINT         NOT NULL
        REFERENCES settlement_batches(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    partner_id        BIGINT         NOT NULL
        REFERENCES partner_profiles(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    gross_amount      NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payouts_gross CHECK (gross_amount >= 0),
    commission_total  NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payouts_commission CHECK (commission_total >= 0),
    net_payout        NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payouts_net CHECK (net_payout >= 0),
    status            VARCHAR(20)    NOT NULL DEFAULT 'PENDING'
        CONSTRAINT chk_payouts_status CHECK (status IN ('PENDING', 'PAID', 'CANCELLED')),
    paid_at           TIMESTAMPTZ,
    payment_reference VARCHAR(100),
    created_at        TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_partner_payouts_batch_partner UNIQUE (batch_id, partner_id),
    CONSTRAINT chk_payouts_math CHECK (net_payout = gross_amount - commission_total)
);

-- 21. payout_items: Chi tiết từng booking đã đối soát (booking_id UNIQUE chống chi trả trùng)
CREATE TABLE payout_items (
    payout_id         BIGINT         NOT NULL
        REFERENCES partner_payouts(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    booking_id        BIGINT         NOT NULL UNIQUE
        REFERENCES bookings(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    booking_amount    NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payout_items_booking_amt CHECK (booking_amount >= 0),
    commission_amount NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payout_items_commission CHECK (commission_amount >= 0),
    net_amount        NUMERIC(18, 0) NOT NULL
        CONSTRAINT chk_payout_items_net CHECK (net_amount >= 0),
    PRIMARY KEY (payout_id, booking_id),
    CONSTRAINT chk_payout_items_math CHECK (net_amount = booking_amount - commission_amount)
);

-- 22. audit_logs: Nhật ký kiểm toán thay đổi dữ liệu trọng yếu
CREATE TABLE audit_logs (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id    BIGINT
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    action      VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id   VARCHAR(64) NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
