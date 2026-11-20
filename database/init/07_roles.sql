-- =============================================================================
-- 07_roles.sql
-- Phân quyền 03 vai trò PostgreSQL: db_migrator, app_rw, reporting_ro
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'db_migrator') THEN
        CREATE ROLE db_migrator WITH LOGIN PASSWORD 'migrator_secret_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
        CREATE ROLE app_rw WITH LOGIN PASSWORD 'app_rw_secret_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reporting_ro') THEN
        CREATE ROLE reporting_ro WITH LOGIN PASSWORD 'reporting_ro_secret_2026';
    END IF;
END;
$$;

-- Thu hồi quyền mặc định của PUBLIC trên schema public
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

GRANT ALL ON SCHEMA public TO db_migrator;
GRANT USAGE ON SCHEMA public TO app_rw, reporting_ro;

-- 1. app_rw: Tài khoản kết nối ứng dụng Express/Prisma
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_rw;
GRANT DELETE ON
    hotel_amenities,
    booking_items,
    booking_night_rates,
    ticket_messages,
    cancellation_policies,
    rooms
    TO app_rw;

-- Chặn xóa trên các bảng tài chính, đơn đặt, nhật ký kiểm toán và tài khoản
REVOKE DELETE ON
    users,
    partner_profiles,
    hotels,
    room_types,
    bookings,
    payments,
    reviews,
    support_tickets,
    settlement_batches,
    partner_payouts,
    payout_items,
    audit_logs
    FROM app_rw;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_rw;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO app_rw;

-- 2. reporting_ro: Chỉ được SELECT trên 3 view báo cáo/công khai
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reporting_ro;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM reporting_ro;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM reporting_ro;

GRANT SELECT ON
    v_public_hotel_listings,
    v_hotel_daily_occupancy,
    v_partner_settlement_overview
    TO reporting_ro;
