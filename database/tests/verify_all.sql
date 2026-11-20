-- =============================================================================
-- verify_all.sql
-- Bộ kiểm thử tự động tầng PostgreSQL cho T01-T15, T19, BR18 & ví dụ đối chứng
-- Chạy bằng: psql -U db_migrator -d hotel_ota -v ON_ERROR_STOP=1 -f ...
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_tbl_count      INT;
    v_view_count     INT;
    v_cust_id        BIGINT;
    v_other_cust_id  BIGINT;
    v_partner_id     BIGINT;
    v_support_id     BIGINT;
    v_accountant_id  BIGINT;
    v_hotel_id       BIGINT;
    v_rt_id          BIGINT;
    v_pol_id         BIGINT;
    v_room1_id       BIGINT;
    v_room2_id       BIGINT;
    v_b_id           BIGINT;
    v_b_code         VARCHAR;
    v_pay_id1        BIGINT;
    v_pay_id2        BIGINT;
    v_refund_amt     NUMERIC(18, 0);
    v_batch1_id      BIGINT;
    v_batch1_code    VARCHAR;
    v_batch2_id      BIGINT;
    v_batch2_code    VARCHAR;
    v_cnt            INT;
    v_avg            NUMERIC(3, 2);
    v_old_total      NUMERIC(18, 0);
    v_new_total      NUMERIC(18, 0);
    v_audit_cnt      INT;
    v_promo_used_1   INT;
    v_promo_used_2   INT;
BEGIN
    -- =========================================================================
    -- T19: Kiểm tra đủ 22 bảng vật lý và 3 views
    -- =========================================================================
    SELECT COUNT(*) INTO v_tbl_count
      FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    ASSERT v_tbl_count = 22, format('T19 FAIL: Expected 22 tables, got %s', v_tbl_count);

    SELECT COUNT(*) INTO v_view_count
      FROM information_schema.views
     WHERE table_schema = 'public';
    ASSERT v_view_count = 3, format('T19 FAIL: Expected 3 views, got %s', v_view_count);

    SELECT id INTO v_cust_id       FROM users WHERE email = 'an.nguyen@example.vn';
    SELECT id INTO v_other_cust_id FROM users WHERE email = 'binh.tran@example.vn';
    SELECT id INTO v_partner_id    FROM users WHERE email = 'doitac.hanoi@hotelota.vn';
    SELECT id INTO v_support_id    FROM users WHERE email = 'hotro1@hotelota.vn';
    SELECT id INTO v_accountant_id FROM users WHERE email = 'ketoan@hotelota.vn';
    SELECT id INTO v_hotel_id      FROM hotels WHERE code = 'HTL-HN-01';
    SELECT id INTO v_rt_id         FROM room_types WHERE hotel_id = v_hotel_id AND code = 'STD';
    SELECT id INTO v_pol_id        FROM cancellation_policies WHERE hotel_id = v_hotel_id AND is_default = TRUE;
    SELECT id INTO v_room1_id      FROM rooms WHERE room_type_id = v_rt_id AND room_number = 'STD-01';
    SELECT id INTO v_room2_id      FROM rooms WHERE room_type_id = v_rt_id AND room_number = 'STD-02';

    -- =========================================================================
    -- Kiểm chứng số liệu ví dụ đối chứng III.4 (4.4M / 4.2M / 660k / 3.74M) & Q18 (0 sai lệch)
    -- =========================================================================
    SELECT COUNT(*) INTO v_cnt
      FROM bookings b
      JOIN payout_items pi ON pi.booking_id = b.id
     WHERE b.booking_code = 'BK-DEMO-REF01'
       AND b.room_subtotal = 4400000
       AND b.discount_amount = 200000
       AND b.total_amount = 4200000
       AND b.commission_amount = 660000
       AND pi.net_amount = 3740000;
    ASSERT v_cnt = 1, 'REF III.4 FAIL: Demo reference booking math mismatch!';

    SELECT COUNT(*) INTO v_cnt
      FROM (
          SELECT b.id
            FROM bookings b
            JOIN booking_night_rates bnr ON bnr.booking_id = b.id
           GROUP BY b.id, b.room_subtotal, b.discount_amount, b.total_amount
          HAVING b.room_subtotal <> SUM(bnr.quantity * bnr.nightly_price_snapshot)
              OR b.total_amount <> GREATEST(SUM(bnr.quantity * bnr.nightly_price_snapshot) - b.discount_amount, 0)
      ) AS drift;
    ASSERT v_cnt = 0, format('IMP1 FAIL: Q18 detected %s booking(s) with night_rate mismatch in seed data', v_cnt);

    -- =========================================================================
    -- T01: Vi phạm CHECK (check_out_date <= check_in_date và rating = 6) -> 23514
    -- =========================================================================
    BEGIN
        INSERT INTO bookings (
            booking_code, customer_id, hotel_id, policy_id,
            check_in_date, check_out_date, guest_count, status,
            commission_rate_snapshot, room_subtotal, discount_amount, total_amount, commission_amount
        ) VALUES (
            'BK-TEST-T01', v_cust_id, v_hotel_id, v_pol_id,
            CURRENT_DATE + 5, CURRENT_DATE + 5, 2, 'HOLD', 15.00, 800000, 0, 800000, 120000
        );
        RAISE EXCEPTION 'T01 FAIL: check_out_date = check_in_date should be rejected';
    EXCEPTION WHEN check_violation THEN
        NULL; -- expected 23514
    END;

    BEGIN
        INSERT INTO reviews (booking_id, customer_id, hotel_id, rating)
        VALUES ((SELECT id FROM bookings WHERE booking_code = 'BK-DEMO-CMP02'), v_other_cust_id, (SELECT id FROM hotels WHERE code = 'HTL-DN-01'), 6);
        RAISE EXCEPTION 'T01 FAIL: rating = 6 should be rejected';
    EXCEPTION WHEN check_violation THEN
        NULL; -- expected 23514
    END;

    -- =========================================================================
    -- T02: Vi phạm CHECK tồn kho (booked_count + held_count > total_allotment)
    -- =========================================================================
    BEGIN
        UPDATE room_inventory
           SET held_count = total_allotment + 1
         WHERE room_type_id = v_rt_id AND stay_date = CURRENT_DATE + 12;
        RAISE EXCEPTION 'T02 FAIL: over-allotment update should be rejected';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    -- =========================================================================
    -- T03: Vi phạm FK & ON DELETE RESTRICT (xóa booking hoặc room_type đang có giao dịch)
    -- =========================================================================
    BEGIN
        DELETE FROM bookings WHERE booking_code = 'BK-DEMO-REF01';
        RAISE EXCEPTION 'T03 FAIL: deleting booking with payments/payouts should fail';
    EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN
        NULL;
    END;

    BEGIN
        DELETE FROM room_types WHERE id = v_rt_id;
        RAISE EXCEPTION 'T03 FAIL: deleting room_type with inventory should fail';
    EXCEPTION WHEN foreign_key_violation OR restrict_violation THEN
        NULL;
    END;

    -- =========================================================================
    -- T04: Vi phạm UNIQUE thực thể yếu (booking_id, line_no) & 1-1 reviews(booking_id)
    -- =========================================================================
    BEGIN
        INSERT INTO booking_items (booking_id, line_no, hotel_id, room_type_id, quantity, nights, unit_price_avg, line_total)
        VALUES ((SELECT id FROM bookings WHERE booking_code = 'BK-DEMO-REF01'), 1, v_hotel_id,
                (SELECT id FROM room_types WHERE hotel_id = v_hotel_id AND code = 'DLX'), 1, 2, 1100000, 2200000);
        RAISE EXCEPTION 'T04 FAIL: duplicate PK (booking_id, line_no) should fail';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO reviews (booking_id, customer_id, hotel_id, rating, comment)
        VALUES ((SELECT id FROM bookings WHERE booking_code = 'BK-DEMO-REF01'), v_cust_id, v_hotel_id, 4, 'Duplicate review');
        RAISE EXCEPTION 'T04 FAIL: duplicate review for 1 booking should fail';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    -- =========================================================================
    -- T05: Trigger chặn đánh giá khi đơn chưa COMPLETED (ví dụ CONFIRMED)
    -- =========================================================================
    BEGIN
        INSERT INTO reviews (booking_id, customer_id, hotel_id, rating, comment)
        SELECT b.id, b.customer_id, b.hotel_id, 5, 'Too early'
          FROM bookings b WHERE b.booking_code = 'BK-DEMO-CNF04';
        RAISE EXCEPTION 'T05 FAIL: review on CONFIRMED booking should be blocked';
    EXCEPTION WHEN raise_exception THEN
        NULL;
    END;

    -- =========================================================================
    -- T06: Trigger đồng bộ avg_rating & review_count khi ẩn review (HIDDEN -> VISIBLE)
    -- =========================================================================
    UPDATE reviews
       SET moderation_status = 'HIDDEN', moderation_reason = 'Test ẩn kiểm duyệt', moderated_by = v_support_id
     WHERE booking_id = (SELECT id FROM bookings WHERE booking_code = 'BK-DEMO-REF01');

    SELECT avg_rating, review_count INTO v_avg, v_cnt FROM hotels WHERE id = v_hotel_id;
    ASSERT v_cnt = 0 AND v_avg = 0.00, format('T06 FAIL: Expected 0/0.00 after hiding review, got %s/%s', v_cnt, v_avg);

    UPDATE reviews
       SET moderation_status = 'VISIBLE', moderation_reason = NULL, moderated_by = NULL
     WHERE booking_id = (SELECT id FROM bookings WHERE booking_code = 'BK-DEMO-REF01');

    SELECT avg_rating, review_count INTO v_avg, v_cnt FROM hotels WHERE id = v_hotel_id;
    ASSERT v_cnt = 1 AND v_avg = 5.00, format('T06 FAIL: Expected 1/5.00 after restoring review, got %s/%s', v_cnt, v_avg);

    -- =========================================================================
    -- T08: sp_create_booking_hold rollback toàn bộ khi có 1 đêm ở giữa is_closed = TRUE
    -- =========================================================================
    UPDATE room_inventory SET is_closed = TRUE
     WHERE room_type_id = v_rt_id AND stay_date = CURRENT_DATE + 15;

    BEGIN
        CALL sp_create_booking_hold(
            v_cust_id, v_hotel_id, v_rt_id,
            CURRENT_DATE + 14, CURRENT_DATE + 17, 1, 2::SMALLINT, NULL, 15, v_b_id, v_b_code
        );
        RAISE EXCEPTION 'T08 FAIL: closed middle night should reject booking hold';
    EXCEPTION WHEN SQLSTATE 'P0002' THEN
        NULL;
    END;

    SELECT held_count INTO v_cnt FROM room_inventory WHERE room_type_id = v_rt_id AND stay_date = CURRENT_DATE + 14;
    ASSERT v_cnt = 0, format('T08 FAIL: Night 1 held_count should remain 0 after rollback, got %s', v_cnt);

    UPDATE room_inventory SET is_closed = FALSE
     WHERE room_type_id = v_rt_id AND stay_date = CURRENT_DATE + 15;

    -- =========================================================================
    -- T10 & T14 & T07: Hold -> đối tác tăng giá gấp đôi (snapshot bất biến) -> Pay idempotent -> Check-in/out
    -- =========================================================================
    SELECT used_count INTO v_promo_used_1 FROM promotions WHERE code = 'VIP15';

    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE + 14, CURRENT_DATE + 17, 2, 4::SMALLINT, 'VIP15', 15, v_b_id, v_b_code
    );

    SELECT used_count INTO v_promo_used_2 FROM promotions WHERE code = 'VIP15';
    ASSERT v_promo_used_2 = v_promo_used_1 + 1, 'Promo used_count should increment on HOLD';

    SELECT total_amount INTO v_old_total FROM bookings WHERE id = v_b_id;

    -- T14: Đối tác tăng giá gấp đôi ngay sau khi khách tạo đơn
    UPDATE room_inventory
       SET nightly_price = nightly_price * 2
     WHERE room_type_id = v_rt_id
       AND stay_date >= CURRENT_DATE + 14
       AND stay_date < CURRENT_DATE + 17;

    SELECT total_amount INTO v_new_total FROM bookings WHERE id = v_b_id;
    ASSERT v_new_total = v_old_total, 'T14 FAIL: Snapshot total_amount changed when inventory price doubled';

    -- T10: Thanh toán 2 lần cùng idempotency_key
    CALL sp_confirm_booking_payment(v_b_id, 'MOCK_CARD', 'idem-verify-t10', v_pay_id1);
    CALL sp_confirm_booking_payment(v_b_id, 'MOCK_CARD', 'idem-verify-t10', v_pay_id2);
    ASSERT v_pay_id1 = v_pay_id2, 'T10 FAIL: Retry with same idempotency_key must return same payment_id';

    SELECT COUNT(*) INTO v_cnt FROM payments WHERE booking_id = v_b_id AND payment_type = 'CHARGE' AND status = 'SUCCESS';
    ASSERT v_cnt = 1, format('T10 FAIL: Expected 1 payment row, got %s', v_cnt);

    -- Check-in reject NULL/duplicate room_ids (IMP4) before valid check-in
    BEGIN
        CALL sp_check_in_booking(v_b_id, ARRAY[v_room1_id, NULL]::BIGINT[], v_partner_id);
        RAISE EXCEPTION 'IMP4 FAIL: NULL in p_room_ids must be rejected';
    EXCEPTION WHEN raise_exception THEN
        NULL;
    END;

    BEGIN
        CALL sp_check_in_booking(v_b_id, ARRAY[v_room1_id, v_room1_id], v_partner_id);
        RAISE EXCEPTION 'IMP4 FAIL: Duplicate room_id in p_room_ids must be rejected';
    EXCEPTION WHEN raise_exception THEN
        NULL;
    END;

    -- Check-in gán 2 phòng vật lý STD-01 & STD-02 rồi Check-out -> COMPLETED
    CALL sp_check_in_booking(v_b_id, ARRAY[v_room1_id, v_room2_id], v_partner_id);
    ASSERT (SELECT status FROM bookings WHERE id = v_b_id) = 'CHECKED_IN', 'Check-in failed';
    ASSERT (SELECT status FROM rooms WHERE id = v_room1_id) = 'OCCUPIED', 'Room 1 should be OCCUPIED';

    CALL sp_check_out_booking(v_b_id, v_partner_id);
    ASSERT (SELECT status FROM bookings WHERE id = v_b_id) = 'COMPLETED', 'Check-out failed';
    ASSERT (SELECT status FROM rooms WHERE id = v_room1_id) = 'AVAILABLE', 'Room 1 should be AVAILABLE after checkout';

    -- T07: Kiểm tra audit_logs có ghi lại thay đổi của đơn v_b_id
    SELECT COUNT(*) INTO v_audit_cnt FROM audit_logs WHERE entity_type = 'bookings' AND entity_id = v_b_id::TEXT;
    ASSERT v_audit_cnt >= 3, format('T07 FAIL: Expected >= 3 audit entries for lifecycle, got %s', v_audit_cnt);

    -- =========================================================================
    -- T11: Hủy đơn trước hạn miễn phí hủy (hoàn 100%, trả tồn kho & promo used_count)
    -- =========================================================================
    SELECT used_count INTO v_promo_used_1 FROM promotions WHERE code = 'GIAM200K';
    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE + 20, CURRENT_DATE + 22, 1, 2::SMALLINT, 'GIAM200K', 15, v_b_id, v_b_code
    );
    ASSERT (SELECT used_count FROM promotions WHERE code = 'GIAM200K') = v_promo_used_1 + 1, 'GIAM200K should increment';
    CALL sp_cancel_booking(v_b_id, v_cust_id, 'Test hủy khi còn HOLD', FALSE, NULL, v_refund_amt);
    ASSERT v_refund_amt = 0, 'Hold cancel refund should be 0';
    ASSERT (SELECT used_count FROM promotions WHERE code = 'GIAM200K') = v_promo_used_1, 'Hold cancel must restore promo used_count';

    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE + 20, CURRENT_DATE + 22, 1, 2::SMALLINT, NULL, 15, v_b_id, v_b_code
    );
    CALL sp_confirm_booking_payment(v_b_id, 'MOCK_WALLET', 'idem-verify-t11-free', v_pay_id1);
    CALL sp_cancel_booking(v_b_id, v_cust_id, 'Hủy trước 48h miễn phí', FALSE, 'refund-verify-t11-free', v_refund_amt);
    ASSERT v_refund_amt = (SELECT total_amount FROM bookings WHERE id = v_b_id),
           'T11 FAIL: Free cancel before 48h must refund 100%';
    SELECT booked_count INTO v_cnt FROM room_inventory WHERE room_type_id = v_rt_id AND stay_date = CURRENT_DATE + 20;
    ASSERT v_cnt = 0, format('T11 FAIL: Inventory booked_count must return to 0, got %s', v_cnt);

    -- =========================================================================
    -- T11b: Hủy trễ hạn tính penalty_percent + Hủy ngoại lệ CHECKED_IN + Expired hold release
    -- =========================================================================
    -- Đặt phòng check-in hôm nay (chắc chắn trễ hạn miễn phí hủy 48h -> phạt 50%)
    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE, CURRENT_DATE + 2, 1, 2::SMALLINT, NULL, 15, v_b_id, v_b_code
    );
    CALL sp_confirm_booking_payment(v_b_id, 'MOCK_CARD', 'idem-verify-t11-late', v_pay_id1);
    CALL sp_cancel_booking(v_b_id, v_cust_id, 'Hủy sát giờ nhận phòng', FALSE, 'refund-verify-t11-late', v_refund_amt);
    ASSERT v_refund_amt = ROUND((SELECT total_amount FROM bookings WHERE id = v_b_id) * 0.50, 0),
           format('T11b FAIL: Late cancel should refund 50%%, got %s', v_refund_amt);

    -- Hủy ngoại lệ đơn đang CHECKED_IN phải trả phòng vật lý về AVAILABLE và giải phóng đêm còn lại
    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE, CURRENT_DATE + 2, 1, 2::SMALLINT, NULL, 15, v_b_id, v_b_code
    );
    CALL sp_confirm_booking_payment(v_b_id, 'MOCK_CARD', 'idem-verify-t11-ex', v_pay_id1);
    CALL sp_check_in_booking(v_b_id, ARRAY[v_room1_id], v_partner_id);
    CALL sp_cancel_booking(v_b_id, v_support_id, 'Sự cố kỹ thuật phòng, hủy ngoại lệ', TRUE, 'refund-verify-t11-ex', v_refund_amt);
    ASSERT (SELECT status FROM bookings WHERE id = v_b_id) = 'CANCELLED', 'Exception cancel must cancel CHECKED_IN booking';
    ASSERT (SELECT status FROM rooms WHERE id = v_room1_id) = 'AVAILABLE', 'Exception cancel must free physical room';
    ASSERT v_refund_amt = (SELECT total_amount FROM bookings WHERE id = v_b_id), 'Exception cancel must refund 100%';

    -- Kiểm tra sp_release_expired_holds giải phóng giữ chỗ quá hạn & không rò rỉ actor_id (IMP5)
    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE + 22, CURRENT_DATE + 24, 1, 2::SMALLINT, 'GIAM200K', 15, v_b_id, v_b_code
    );
    UPDATE bookings SET hold_expires_at = NOW() - INTERVAL '1 minute' WHERE id = v_b_id;
    CALL sp_release_expired_holds(v_cnt);
    ASSERT v_cnt >= 1 AND (SELECT status FROM bookings WHERE id = v_b_id) = 'CANCELLED',
           'sp_release_expired_holds must cancel expired holds';
    ASSERT (SELECT used_count FROM promotions WHERE code = 'GIAM200K') = v_promo_used_1,
           'Expired hold release must restore promo used_count';
    ASSERT (SELECT actor_id FROM audit_logs WHERE entity_type = 'bookings' AND entity_id = v_b_id::TEXT AND new_data->>'status' = 'CANCELLED' ORDER BY id DESC LIMIT 1) IS NULL,
           'IMP5 FAIL: System release must record NULL actor_id, not stale customer actor';

    -- Kiểm tra idempotency_key đã FAILED bị từ chối khi retry & PENDING -> SUCCESS hoạt động
    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key)
    VALUES (v_b_id, 'CHARGE', 'MOCK_CARD', 100000, 'FAILED', 'idem-failed-key-test');
    BEGIN
        CALL sp_confirm_booking_payment(v_b_id, 'MOCK_CARD', 'idem-failed-key-test', v_pay_id2);
        RAISE EXCEPTION 'BR09 FAIL: FAILED idempotency_key reuse must fail';
    EXCEPTION WHEN raise_exception THEN
        NULL;
    END;

    CALL sp_create_booking_hold(
        v_cust_id, v_hotel_id, v_rt_id,
        CURRENT_DATE + 25, CURRENT_DATE + 27, 1, 2::SMALLINT, NULL, 15, v_b_id, v_b_code
    );
    INSERT INTO payments (booking_id, payment_type, method, amount, status, idempotency_key)
    SELECT v_b_id, 'CHARGE', 'MOCK_CARD', total_amount, 'PENDING', 'idem-pending-to-success'
      FROM bookings WHERE id = v_b_id;
    CALL sp_confirm_booking_payment(v_b_id, 'MOCK_CARD', 'idem-pending-to-success', v_pay_id2);
    ASSERT (SELECT status FROM payments WHERE id = v_pay_id2) = 'SUCCESS'
       AND (SELECT status FROM bookings WHERE id = v_b_id) = 'CONFIRMED',
           'PENDING payment transition to SUCCESS must confirm booking';

    -- =========================================================================
    -- T12: Chốt kỳ đối soát hai lần liên tiếp -> không chi trả trùng
    -- =========================================================================
    CALL sp_generate_settlement_batch(CURRENT_DATE - 30, CURRENT_DATE + 30, v_accountant_id, v_batch1_id, v_batch1_code);
    SELECT COUNT(*) INTO v_cnt
      FROM payout_items pi
      JOIN partner_payouts pp ON pp.id = pi.payout_id
     WHERE pp.batch_id = v_batch1_id;
    ASSERT v_cnt >= 2, format('T12 FAIL: First settlement batch should settle >= 2 un-settled COMPLETED bookings, got %s', v_cnt);

    CALL sp_generate_settlement_batch(CURRENT_DATE - 30, CURRENT_DATE + 30, v_accountant_id, v_batch2_id, v_batch2_code);
    SELECT COUNT(*) INTO v_cnt
      FROM payout_items pi
      JOIN partner_payouts pp ON pp.id = pi.payout_id
     WHERE pp.batch_id = v_batch2_id;
    ASSERT v_cnt = 0, format('T12 FAIL: Second consecutive settlement batch must produce 0 duplicate payouts, got %s', v_cnt);

    -- =========================================================================
    -- T15 & BR15: Ticket gắn booking_id từ người ngoài đơn bị chặn
    -- =========================================================================
    BEGIN
        INSERT INTO support_tickets (ticket_code, booking_id, customer_id, category, priority, subject)
        VALUES ('TK-FAIL-BR15', (SELECT id FROM bookings WHERE booking_code = 'BK-DEMO-REF01'), v_other_cust_id, 'BOOKING', 'LOW', 'Unauthorized');
        RAISE EXCEPTION 'T15/BR15 FAIL: Unrelated user creating ticket for booking should fail';
    EXCEPTION WHEN raise_exception THEN
        NULL;
    END;

    -- =========================================================================
    -- BR18: Chặn xóa / sửa trực tiếp payments SUCCESS & audit_logs
    -- =========================================================================
    BEGIN
        DELETE FROM audit_logs WHERE id = (SELECT id FROM audit_logs LIMIT 1);
        RAISE EXCEPTION 'BR18 FAIL: Deleting audit_logs must be blocked';
    EXCEPTION WHEN SQLSTATE 'P0003' THEN
        NULL;
    END;

    BEGIN
        UPDATE payments SET amount = 1 WHERE id = v_pay_id1;
        RAISE EXCEPTION 'BR18 FAIL: Updating SUCCESS payment must be blocked';
    EXCEPTION WHEN SQLSTATE 'P0003' THEN
        NULL;
    END;

    -- IMP3: Chặn sửa FAILED payment & chặn sửa số tiền trên PENDING payment/payout
    BEGIN
        UPDATE payments SET status = 'SUCCESS' WHERE idempotency_key = 'idem-failed-key-test';
        RAISE EXCEPTION 'IMP3 FAIL: Updating FAILED payment must be blocked';
    EXCEPTION WHEN SQLSTATE 'P0003' THEN
        NULL;
    END;

    BEGIN
        UPDATE partner_payouts SET net_payout = 1, gross_amount = 1, commission_total = 0
         WHERE batch_id = v_batch1_id;
        RAISE EXCEPTION 'IMP3 FAIL: Mutating PENDING payout amounts directly must be blocked';
    EXCEPTION WHEN SQLSTATE 'P0003' THEN
        NULL;
    END;

    -- Cho phép chuyển PENDING -> PAID hợp lệ trên partner_payouts, sau đó chặn sửa PAID
    UPDATE partner_payouts
       SET status = 'PAID', paid_at = NOW(), payment_reference = 'UNC-TEST-IMP3'
     WHERE batch_id = v_batch1_id;

    BEGIN
        UPDATE partner_payouts SET payment_reference = 'TAMPER' WHERE batch_id = v_batch1_id;
        RAISE EXCEPTION 'IMP3 FAIL: Updating PAID payout must be blocked';
    EXCEPTION WHEN SQLSTATE 'P0003' THEN
        NULL;
    END;

    -- =========================================================================
    -- T13: Kiểm tra phân quyền role reporting_ro & app_rw
    -- =========================================================================
    SET LOCAL ROLE reporting_ro;
    PERFORM * FROM v_public_hotel_listings LIMIT 1;
    PERFORM * FROM v_hotel_daily_occupancy LIMIT 1;
    PERFORM * FROM v_partner_settlement_overview LIMIT 1;

    BEGIN
        PERFORM * FROM users LIMIT 1;
        RAISE EXCEPTION 'T13 FAIL: reporting_ro must NOT read users';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;

    BEGIN
        PERFORM * FROM partner_profiles LIMIT 1;
        RAISE EXCEPTION 'T13 FAIL: reporting_ro must NOT read partner_profiles';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
    RESET ROLE;

    SET LOCAL ROLE app_rw;
    BEGIN
        DELETE FROM payments WHERE id = v_pay_id1;
        RAISE EXCEPTION 'T13 FAIL: app_rw must NOT have DELETE privilege on payments';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
    RESET ROLE;

    RAISE NOTICE 'ALL VERIFY_ALL ASSERTIONS PASSED (T01-T15, T19, BR15, BR18, REF III.4)';
END;
$$;

ROLLBACK;
