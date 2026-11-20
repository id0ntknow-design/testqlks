# PostgreSQL Database Implementation Plan — Hệ thống Đặt phòng Khách sạn OTA

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai hoàn chỉnh tầng cơ sở dữ liệu PostgreSQL 18 (22 bảng, ràng buộc, chỉ mục, hàm, thủ tục, trigger, view phân quyền, roles, dữ liệu mẫu tiếng Việt, 20 truy vấn nghiệp vụ Q01–Q20, backup/restore và kiểm thử tự động) chạy sạch qua `docker compose up`.

**Architecture:** Tách toàn bộ đối tượng PostgreSQL vào thư mục `database/init/` theo thứ tự thực thi `01_` → `08_` khi container PostgreSQL khởi tạo lần đầu, kèm `database/seeds/seed_scale.sql` cho benchmark 100k+ dòng, `database/queries/q01_to_q20.sql` cho 20 truy vấn và `database/tests/` + `database/scripts/` để kiểm chứng tự động trên PostgreSQL thật.

**Tech Stack:** PostgreSQL 18 (`postgres:18-alpine`), Docker Compose, Bash (`psql`, `pg_dump`, `pg_restore`).

**Spec:** [2026-11-20-postgresql-database-design.md](../specs/2026-11-20-postgresql-database-design.md)

## Global Constraints

- Chính xác **22 bảng vật lý** (`users`, `partner_profiles`, `locations`, `amenities`, `promotions`, `hotels`, `hotel_amenities`, `cancellation_policies`, `room_types`, `rooms`, `room_inventory`, `bookings`, `booking_items`, `booking_night_rates`, `payments`, `reviews`, `support_tickets`, `ticket_messages`, `settlement_batches`, `partner_payouts`, `payout_items`, `audit_logs`), khớp 100% tên cột trong Từ điển dữ liệu của Spec.
- Khóa chính độc lập dùng `BIGINT GENERATED ALWAYS AS IDENTITY`; toàn bộ tiền tệ VND dùng `NUMERIC(18,0)`; phần trăm dùng `NUMERIC(5,2)`; không dùng `FLOAT`/`DOUBLE`.
- Chính sách FK: `ON DELETE RESTRICT` bảo vệ lịch sử tài chính (`bookings`, `payments`, `payout_items`, `room_types`, `hotels`); `ON DELETE CASCADE` chỉ dùng cho `hotel_amenities`, `booking_items`, `booking_night_rates`, `ticket_messages`.
- Mọi thao tác giữ/đặt/thanh toán/hủy/đối soát trên `room_inventory` phải khóa dòng theo thứ tự `(room_type_id ASC, stay_date ASC) FOR UPDATE`.
- Không sửa đổi file đề cương `De_cuong_va_ke_hoach_do_an_CSDL_Dat_Phong_Khach_San.md`.

## Review Focus

1. **Multi-row `booking_items` trong `sp_create_booking_hold`:** Với đơn `quantity = N`, thủ tục tạo `N` dòng `quantity = 1` để check-in gán 1–1 vào `assigned_room_id`; khi hủy hoặc hoàn tất, tổng `booked_count`/`held_count` cần khôi phục theo tổng `SUM(quantity)` nhóm theo `room_type_id` trong `booking_items` (tránh trừ lặp theo từng dòng nếu đêm lưu trú trùng nhau).
2. **Idempotency retry khi thanh toán thất bại/đang chờ (BR09):** Gửi lại cùng `idempotency_key` khi bản ghi `payments` trước đó đang `SUCCESS` (cùng `booking_id`) phải trả lại `payment_id` mà không trừ tồn kho lần 2; nếu `FAILED` hoặc khác `booking_id` phải `RAISE EXCEPTION`.
3. **Bất biến tài chính vs Trigger nội bộ (BR18):** Trigger chặn `UPDATE/DELETE` trên `payments`/`partner_payouts`/`audit_logs` phải vẫn cho phép `sp_confirm_booking_payment` chuyển `payments.status` từ `PENDING` → `SUCCESS` và cho phép kế toán chuyển `partner_payouts.status` từ `PENDING` → `PAID`, nhưng chặn sửa dòng đã `SUCCESS`/`PAID` và chặn `DELETE`.
4. **Quyền `reporting_ro` & `app_rw`:** Kết nối bằng role `reporting_ro` chỉ được `SELECT` 3 views và phải bị từ chối khi đọc `users`, `partner_profiles`, `payments`; role `app_rw` không được `DELETE` trên `payments`, `payout_items`, `audit_logs`, `partner_payouts`.
5. **Khôi phục tồn kho khi hủy ngoại lệ `CHECKED_IN`:** Khi hủy ngoại lệ đơn đã `CHECKED_IN`, chỉ hoàn `booked_count` cho các đêm từ `GREATEST(CURRENT_DATE, check_in_date)` trở đi và đặt `rooms.status = 'AVAILABLE'` cho tất cả phòng đã gán trên đơn.

---

### Task 1: Hạ tầng Docker, Lược đồ 22 Bảng (`01_schema_tables.sql`) và Chỉ mục (`02_indexes.sql`)

**Files:**
- Create: `.env.example`
- Create: `.gitignore`
- Create: `docker-compose.yml`
- Create: `database/init/01_schema_tables.sql`
- Create: `database/init/02_indexes.sql`

**Interfaces:**
- Produces: 22 bảng vật lý với đầy đủ PK, composite FKs (`cancellation_policies(id, hotel_id)`, `bookings(id, hotel_id)`, `room_types(id, hotel_id)`, `rooms(id, room_type_id)`), CHECK constraints (R01–R03), UNIQUE constraints (R04–R06), và 7 chỉ mục (`idx_bookings_hotel_status_dates`, `idx_bookings_active_holds`, `idx_inventory_avail_cover`, `idx_bookings_customer_created`, `idx_audit_entity_time`, `idx_audit_new_data_gin`, `idx_hotels_location_rating`, `idx_locations_parent`).

- [ ] **Step 1: Tạo `.env.example`, `.gitignore` và `docker-compose.yml`**
  - `.env.example`: `POSTGRES_DB=hotel_ota`, `POSTGRES_USER=db_migrator`, `POSTGRES_PASSWORD=migrator_secret_2026`, `POSTGRES_PORT=5432`, `APP_RW_PASSWORD=app_rw_secret_2026`, `REPORTING_RO_PASSWORD=reporting_ro_secret_2026`.
  - `.gitignore`: bỏ qua `.env`, `database/backups/*.dump`, `*.log`.
  - `docker-compose.yml`: service `postgres` dùng `postgres:18-alpine`, `TZ=Asia/Ho_Chi_Minh`, mount `./database/init:/docker-entrypoint-initdb.d:ro`, `./database:/workspace/database`, `healthcheck` với `pg_isready -U ${POSTGRES_USER:-db_migrator} -d ${POSTGRES_DB:-hotel_ota}`.

- [ ] **Step 2: Viết `database/init/01_schema_tables.sql`**
  - Định nghĩa đủ 22 bảng theo đúng tên, kiểu dữ liệu, nullability, `DEFAULT`, `CHECK`, `UNIQUE`, `PK`, `FK` (`ON DELETE/UPDATE`) trong Mục 4 của Spec.
  - Bao gồm partial unique index `uq_cancellation_policies_default ON cancellation_policies(hotel_id) WHERE is_default = TRUE`.

- [ ] **Step 3: Viết `database/init/02_indexes.sql`**
  - Tạo đủ các chỉ mục Mục 5.5 của Spec: `idx_bookings_hotel_status_dates`, `idx_bookings_active_holds`, `idx_inventory_avail_cover`, `idx_bookings_customer_created`, `idx_audit_entity_time`, `idx_audit_new_data_gin`, `idx_hotels_location_rating`, `idx_locations_parent`.

- [ ] **Step 4: Chạy kiểm thử DDL + Indexes trên PostgreSQL 18 (Docker)**
  - Run: `cp -n .env.example .env && docker compose up -d postgres` và đợi healthy; kiểm tra:
    `docker compose exec -T postgres psql -U db_migrator -d hotel_ota -c "SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"`
  - Expected: `table_count = 22` và 0 lỗi SQL trong log khởi tạo Docker.

---

### Task 2: Functions (`03_functions.sql`) và Stored Procedures (`04_procedures.sql`)

**Files:**
- Create: `database/init/03_functions.sql`
- Create: `database/init/04_procedures.sql`

**Interfaces:**
- Consumes: 22 bảng từ Task 1.
- Produces:
  - `fn_calculate_booking_quote(p_hotel_id BIGINT, p_items JSONB, p_check_in DATE, p_check_out DATE, p_promo_code VARCHAR DEFAULT NULL)` + overload `(p_room_type_id BIGINT, p_check_in DATE, p_check_out DATE, p_qty INT, p_promo_code VARCHAR DEFAULT NULL)`
  - `fn_calculate_refund_amount(p_booking_id BIGINT, p_cancel_time TIMESTAMPTZ DEFAULT NOW())`
  - `sp_create_booking_hold(p_customer_id BIGINT, p_hotel_id BIGINT, p_items JSONB, p_check_in DATE, p_check_out DATE, p_guest_count SMALLINT, p_promo_code VARCHAR, p_hold_minutes INT, OUT p_booking_id BIGINT, OUT p_booking_code VARCHAR)` + overload 1 loại phòng
  - `sp_confirm_booking_payment(p_booking_id BIGINT, p_method VARCHAR, p_idempotency_key VARCHAR, OUT p_payment_id BIGINT)`
  - `sp_cancel_booking(p_booking_id BIGINT, p_actor_id BIGINT, p_reason TEXT, p_is_exception BOOLEAN DEFAULT FALSE, p_idempotency_key VARCHAR DEFAULT NULL, OUT p_refund_amount NUMERIC)`
  - `sp_generate_settlement_batch(p_period_start DATE, p_period_end DATE, p_created_by BIGINT, OUT p_batch_id BIGINT, OUT p_batch_code VARCHAR)`
  - `sp_release_expired_holds(OUT p_released_count INT)`
  - `sp_check_in_booking(p_booking_id BIGINT, p_room_ids BIGINT[])`
  - `sp_check_out_booking(p_booking_id BIGINT)`

- [ ] **Step 1: Viết `database/init/03_functions.sql`**
  - Cài đặt `fn_calculate_booking_quote` (JSONB + overload 1 `room_type_id`), kiểm tra khách sạn `APPROVED & is_active`, kiểm tra sức chứa tối đa `(max_adults + max_children) * qty >= 1`, đếm số đêm = `p_check_out - p_check_in`, kiểm tra đủ `total_allotment - booked_count - held_count >= qty` và `is_closed = FALSE` mọi đêm, tính khuyến mãi (`FIXED`/`PERCENT` có `max_discount_amount`, `min_order_amount`, `valid_from..valid_to`, `used_count < usage_limit`) và `commission_amount = ROUND(room_subtotal * commission_rate / 100.0, 0)`.
  - Cài đặt `fn_calculate_refund_amount` kiểm tra tổng tiền `CHARGE + SUCCESS` đã thu, so sánh `p_cancel_time` với `(check_in_date::TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh') - make_interval(hours => free_cancel_hours)`.

- [ ] **Step 2: Viết `database/init/04_procedures.sql`**
  - Cài đặt toàn bộ 7 thủ tục với `SET LOCAL app.current_actor_id` khi truyền `actor_id`, khóa `room_inventory` theo thứ tự `(room_type_id ASC, stay_date ASC) FOR UPDATE`.
  - Lưu ý Review Focus: `sp_cancel_booking` và `sp_release_expired_holds` tổng hợp theo `room_type_id` từ `booking_night_rates` (hoặc `SUM(quantity)` từ `booking_items`) để trừ `held_count`/`booked_count` đúng chính xác một lần mỗi đêm, hoàn trả `promotions.used_count` khi hủy/hết hạn đơn chưa trả tiền, và xử lý `PENDING`/`FAILED`/`SUCCESS` `idempotency_key` trong `sp_confirm_booking_payment`.

- [ ] **Step 3: Nạp và kiểm tra cú pháp Functions & Procedures**
  - Run: `docker compose exec -T postgres psql -U db_migrator -d hotel_ota -v ON_ERROR_STOP=1 -f /workspace/database/init/03_functions.sql -f /workspace/database/init/04_procedures.sql`
  - Expected: Thực thi `CREATE OR REPLACE FUNCTION/PROCEDURE` thành công không lỗi.

---

### Task 3: Triggers (`05_triggers.sql`), Views (`06_views.sql`) và Roles (`07_roles.sql`)

**Files:**
- Create: `database/init/05_triggers.sql`
- Create: `database/init/06_views.sql`
- Create: `database/init/07_roles.sql`

**Interfaces:**
- Consumes: 22 bảng (Task 1) và cột/trạng thái quy định trong Spec.
- Produces:
  - Triggers: `trg_validate_and_sync_review`, `trg_audit_log_changes`, `trg_validate_support_ticket`, `trg_enforce_financial_immutability`, `trg_validate_room_assignment`, `trg_touch_updated_at`.
  - Views: `v_public_hotel_listings`, `v_hotel_daily_occupancy`, `v_partner_settlement_overview`.
  - Roles: `db_migrator`, `app_rw`, `reporting_ro`.

- [ ] **Step 1: Viết `database/init/05_triggers.sql`**
  - `trg_validate_and_sync_review`: `BEFORE INSERT/UPDATE` kiểm tra đơn `COMPLETED`, khớp `customer_id` và `hotel_id`; `AFTER INSERT/UPDATE/DELETE` cập nhật `hotels.avg_rating` và `hotels.review_count` chỉ từ `moderation_status = 'VISIBLE'`.
  - `trg_audit_log_changes`: gắn trên `bookings`, `hotels`, `partner_payouts`; ghi `actor_id` từ `current_setting('app.current_actor_id', TRUE)`, `old_data`, `new_data` JSONB.
  - `trg_validate_support_ticket`: kiểm tra BR15 khi `booking_id IS NOT NULL` (`customer_id` phải là `bookings.customer_id` hoặc `hotels.partner_id`).
  - `trg_enforce_financial_immutability`: chặn `DELETE` trên `payments`, `payout_items`, `partner_payouts`, `audit_logs`; chặn `UPDATE` trên `audit_logs`, `payout_items`, các dòng `payments` đã `SUCCESS`, và các dòng `partner_payouts` đã `PAID`.
  - `trg_validate_room_assignment`: khi `booking_items.assigned_room_id` được gán/đổi sang phòng khác `NULL`, kiểm tra `rooms.status = 'AVAILABLE'` và chưa có đơn `CHECKED_IN` nào khác đang giữ phòng đó.
  - `trg_touch_updated_at`: tự cập nhật `updated_at = NOW()` trên các bảng có cột `updated_at`.

- [ ] **Step 2: Viết `database/init/06_views.sql`**
  - `v_public_hotel_listings`: lọc `approval_status = 'APPROVED' AND is_active = TRUE`, nối `locations`, ẩn tuyệt đối `commission_rate`, `partner_id`, `tax_code`, `bank_account`, `bank_name`.
  - `v_hotel_daily_occupancy`: tỷ lệ lấp đầy và tồn phòng theo khách sạn và ngày.
  - `v_partner_settlement_overview`: tổng hợp doanh thu, hoa hồng, đã chi trả / chờ chi trả theo từng đối tác.

- [ ] **Step 3: Viết `database/init/07_roles.sql`**
  - Tạo idempotent roles `app_rw` và `reporting_ro` (từ cấu hình `DO $$ ... $$` dùng mật khẩu mặc định hoặc biến môi trường khớp `.env`).
  - Cấp quyền `app_rw`: `SELECT, INSERT, UPDATE` trên các bảng nghiệp vụ, `USAGE, SELECT` trên sequences, `EXECUTE` trên toàn bộ functions/procedures; `REVOKE DELETE` trên `payments`, `payout_items`, `audit_logs`, `partner_payouts`; không có quyền DDL.
  - Cấp quyền `reporting_ro`: `REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reporting_ro` (và `PUBLIC`); chỉ `GRANT SELECT ON v_public_hotel_listings, v_hotel_daily_occupancy, v_partner_settlement_overview TO reporting_ro`.

- [ ] **Step 4: Nạp và xác minh Triggers, Views, Roles**
  - Run: `docker compose exec -T postgres psql -U db_migrator -d hotel_ota -v ON_ERROR_STOP=1 -f /workspace/database/init/05_triggers.sql -f /workspace/database/init/06_views.sql -f /workspace/database/init/07_roles.sql`
  - Expected: 3 views, các triggers và 3 roles tạo thành công không lỗi.

---

### Task 4: Dữ liệu Mẫu Tiếng Việt (`08_seed_demo.sql`) và Bộ Sinh Dữ liệu Quy mô Lớn (`seeds/seed_scale.sql`)

**Files:**
- Create: `database/init/08_seed_demo.sql`
- Create: `database/seeds/seed_scale.sql`

**Interfaces:**
- Consumes: toàn bộ schema, SP/triggers từ Tasks 1–3.
- Produces: Bộ dữ liệu demo tiếng Việt nhất quán 100% ràng buộc (đủ 05 vai trò A01–A05, cây địa điểm Quốc gia → Tỉnh/Thành → Quận/Huyện → Khu vực, tiện ích, khuyến mãi, khách sạn, chính sách hủy, hạng phòng, phòng vật lý, `room_inventory`, các đơn ở đủ trạng thái `HOLD`/`CONFIRMED`/`CHECKED_IN`/`COMPLETED`/`CANCELLED`, bao gồm đúng ví dụ đối chứng 4.400.000 / 4.200.000 / 660.000 / 3.740.000 VND, đánh giá, ticket có ghi chú nội bộ, kỳ đối soát) + script `seed_scale.sql` sinh ≥ 10.000 `bookings` và ≥ 100.000 `room_inventory` & ≥ 200.000 `booking_night_rates`.

- [ ] **Step 1: Viết `database/init/08_seed_demo.sql`**
  - Dùng dữ liệu tiếng Việt có dấu tự nhiên, tên người Việt và địa danh Việt Nam (Hà Nội, Đà Nẵng, TP.HCM, Phú Quốc, Hội An).
  - Gồm ví dụ đối chứng: 02 phòng Deluxe × 02 đêm (`1.000.000` + `1.200.000` = `4.400.000`), mã giảm giá `200.000`, thanh toán `4.200.000`, `commission_rate = 15%` (`660.000`), payout `3.740.000`.
  - Bao gồm cả các đơn `COMPLETED` chưa đối soát (cho Q15), ticket chưa đóng/đã đóng có `is_internal_note = TRUE`, đánh giá `VISIBLE` và `HIDDEN`.

- [ ] **Step 2: Viết `database/seeds/seed_scale.sql`**
  - Script set-based dùng `generate_series` sinh bổ sung đạt tối thiểu `100.000+` dòng `room_inventory` (ví dụ 100 khách sạn × 3 hạng phòng × 365 ngày = `109.500` dòng), `10.000+` (có tham số tùy chọn nâng lên `100.000`) dòng `bookings` và `200.000+` dòng `booking_night_rates` tuân thủ 100% PK/FK/CHECK.

- [ ] **Step 3: Khởi tạo lại sạch container từ đầu và kiểm tra auto-init**
  - Run: `docker compose down -v && docker compose up -d postgres` và kiểm tra:
    `docker compose exec -T postgres psql -U db_migrator -d hotel_ota -c "SELECT status, COUNT(*) FROM bookings GROUP BY status ORDER BY status;"`
  - Expected: Container khởi tạo sạch tự động từ `01_` → `08_` với 0 lỗi, dữ liệu demo đầy đủ các trạng thái.

---

### Task 5: 20 Truy vấn Nghiệp vụ (`q01_to_q20.sql`), Bộ Kiểm thử (`verify_all.sql`, `concurrency_test.sh`) và Backup/Restore

**Files:**
- Create: `database/queries/q01_to_q20.sql`
- Create: `database/tests/verify_all.sql`
- Create: `database/tests/concurrency_test.sh`
- Create: `database/scripts/backup.sh`
- Create: `database/scripts/restore.sh`

**Interfaces:**
- Consumes: Toàn bộ CSDL đã dựng ở Tasks 1–4.
- Produces: Bộ kiểm chứng toàn diện cho Q01–Q20, T01–T15, T09 (concurrency race condition), T18 (backup/restore 100% parity), T19 (kiểm tra 22 bảng).

- [ ] **Step 1: Viết `database/queries/q01_to_q20.sql`**
  - Cài đặt đầy đủ 20 truy vấn Q01–Q20 đúng từng kỹ thuật SQL yêu cầu trong Mục 5.7 (CTE đệ quy Q04, `DENSE_RANK()` Q06, correlated subquery Q07, `FILTER (WHERE ...)` Q08, `SUM() OVER` Q10, phép chia quan hệ Q11, `NOT EXISTS` Q01/Q12/Q15/Q19, `GROUP BY + HAVING` Q05/Q09/Q13/Q18, `EXTRACT(EPOCH FROM ...)` Q16, `JSONB` Q20).

- [ ] **Step 2: Viết `database/tests/verify_all.sql`**
  - Viết khối kiểm thử `DO $$ ... $$` với `ASSERT` / `BEGIN ... EXCEPTION WHEN ...` tự động xác minh:
    - T01: CHECK constraint (`check_out_date <= check_in_date`, `rating = 6`) bị chặn (`23514`).
    - T02: CHECK tồn kho (`booked_count + held_count > total_allotment`) bị chặn (`23514`).
    - T03: `ON DELETE RESTRICT` trên `bookings`/`room_types` bị chặn (`23503`).
    - T04: Trùng PK thực thể yếu `(booking_id, line_no)` và 1–1 `reviews(booking_id)` bị chặn (`23505`).
    - T05: Trigger chặn đánh giá đơn `CONFIRMED`.
    - T06: Trigger đồng bộ `avg_rating` và `review_count` khi thêm hoặc ẩn review.
    - T07: Trigger `audit_logs` tự ghi `old_data`/`new_data` JSONB.
    - T08: `sp_create_booking_hold` rollback toàn bộ khi có 1 đêm `is_closed = TRUE`.
    - T10: `sp_confirm_booking_payment` gọi 2 lần cùng `idempotency_key` chỉ sinh 1 payment, retry key đã `FAILED` bị từ chối.
    - T11: Hủy trước hạn hoàn 100%, hủy trễ hạn tính đúng phạt `penalty_percent`, hủy ngoại lệ `CHECKED_IN` trả phòng vật lý về `AVAILABLE`.
    - T12: Chốt kỳ đối soát 2 lần liên tiếp không chi trả trùng; đối chiếu ví dụ `4.4M / 4.2M / 660k / 3.74M`.
    - T13: Role `reporting_ro` bị từ chối đọc `users`/`payments`, chỉ đọc được views; `app_rw` bị từ chối `DELETE` trên `payments`.
    - T14: Snapshot giá bất biến khi đối tác tăng `nightly_price` sau khi đặt.
    - T15: Trigger `support_tickets` chặn người ngoài đơn tạo ticket gắn `booking_id`.
    - BR18: Trigger chặn `DELETE`/`UPDATE` bất hợp pháp trên `payments`, `audit_logs`, `payout_items`.
    - T19: Xác minh đủ 22 bảng và 3 views.

- [ ] **Step 3: Viết `database/tests/concurrency_test.sh`, `database/scripts/backup.sh`, `database/scripts/restore.sh`**
  - `concurrency_test.sh`: mở 10 tiến trình `psql` song song cùng gọi `sp_create_booking_hold` vào 01 phòng trống cuối cùng → khẳng định đúng `1` phiên thành công và `9` phiên nhận lỗi hết phòng (T09).
  - `backup.sh` & `restore.sh`: dùng `pg_dump -Fc` xuất `.dump`, tạo DB tạm sạch `hotel_ota_restore_test`, chạy `pg_restore`, đối chiếu số bảng, tổng dòng `bookings`, tổng doanh thu và payout khớp 100% (T18).

- [ ] **Step 4: Chạy toàn bộ kiểm thử xác minh**
  - Run:
    1. `docker compose exec -T postgres psql -U db_migrator -d hotel_ota -v ON_ERROR_STOP=1 -f /workspace/database/queries/q01_to_q20.sql`
    2. `docker compose exec -T postgres psql -U db_migrator -d hotel_ota -v ON_ERROR_STOP=1 -f /workspace/database/tests/verify_all.sql`
    3. `bash database/tests/concurrency_test.sh`
    4. `bash database/scripts/backup.sh && bash database/scripts/restore.sh`
  - Expected: Tất cả đều pass, 0 lỗi, số liệu backup/restore khớp 100%, concurrency đúng 1/10 thành công.

---

## Self-Review

1. **Spec coverage:** Đủ 22 bảng (Task 1), 7+ indexes (Task 1), 2 functions + 4 SP chính + 3 SP bổ trợ (Task 2), 6 triggers + 3 views + 3 roles (Task 3), seed demo tiếng Việt + script seed 100k+ (Task 4), Q01–Q20 + T01–T15/T09/T18/T19 + backup/restore (Task 5). Không bỏ sót mục nào của Hướng 1.
2. **Step scan:** Mỗi bước chỉ rõ file, chữ ký hàm/thủ tục, ràng buộc nghiệp vụ và lệnh chạy kiểm chứng với kết quả kỳ vọng cụ thể.
3. **Type consistency:** Toàn bộ tên bảng, tên hàm (`fn_calculate_booking_quote`, `fn_calculate_refund_amount`), tên thủ tục (`sp_create_booking_hold`, `sp_confirm_booking_payment`, `sp_cancel_booking`, `sp_generate_settlement_batch`, `sp_release_expired_holds`, `sp_check_in_booking`, `sp_check_out_booking`), tên views và roles khớp 100% với Spec.
4. **Review Focus:** Đủ 5 điểm rủi ro trọng yếu đã được gắn kiểm thử tương ứng vào Tasks 2, 3 và 5 (`verify_all.sql`).
5. **Proportion:** Kế hoạch gọn, không chép code SQL dài vào kế hoạch, chỉ khóa hợp đồng giao diện và điều kiện kiểm thử.
