#!/usr/bin/env bash
# =============================================================================
# concurrency_test.sh (T09)
# Bắn 10 phiên SQL song song cùng đặt 01 phòng trống cuối cùng qua sp_create_booking_hold
# Kỳ vọng: ĐÚNG 01 phiên thành công, 09 phiên bị chặn (không overbooking / âm tồn)
# =============================================================================

set -euo pipefail

CONTAINER_NAME="${PG_CONTAINER:-hotel_ota_postgres}"
PG_USER="${POSTGRES_USER:-db_migrator}"
PG_DB="${POSTGRES_DB:-hotel_ota}"

echo "[T09] Thiết lập phòng kiểm thử chỉ còn đúng 01 phòng trống..."
IDS=$(docker compose exec -T postgres psql -U "$PG_USER" -d "$PG_DB" -At -v ON_ERROR_STOP=1 <<'SQL'
WITH target_hotel AS (
    SELECT id FROM hotels WHERE code = 'HTL-DN-02'
),
target_rt AS (
    SELECT rt.id, rt.hotel_id FROM room_types rt JOIN target_hotel h ON h.id = rt.hotel_id WHERE rt.code = 'STD'
),
target_cust AS (
    SELECT id FROM users WHERE email = 'an.nguyen@example.vn'
)
SELECT tc.id || '|' || tr.hotel_id || '|' || tr.id FROM target_cust tc, target_rt tr;
SQL
)

CUST_ID=$(echo "$IDS" | cut -d'|' -f1)
HOTEL_ID=$(echo "$IDS" | cut -d'|' -f2)
RT_ID=$(echo "$IDS" | cut -d'|' -f3)
CHECK_IN=$(date -d "+25 days" +%Y-%m-%d)
CHECK_OUT=$(date -d "+27 days" +%Y-%m-%d)

# Đặt trạng thái tồn kho đúng 5 phòng, đã đặt 4 phòng -> chỉ còn 1 phòng cuối cùng
docker compose exec -T postgres psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 <<SQL >/dev/null
DELETE FROM booking_night_rates WHERE room_type_id = $RT_ID AND stay_date >= '$CHECK_IN' AND stay_date < '$CHECK_OUT';
UPDATE room_inventory
   SET total_allotment = 5, booked_count = 4, held_count = 0, is_closed = FALSE
 WHERE room_type_id = $RT_ID
   AND stay_date >= '$CHECK_IN'
   AND stay_date < '$CHECK_OUT';
SQL

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[T09] Phóng 10 phiên PostgreSQL song song đặt cùng 01 phòng cuối cùng ($CHECK_IN -> $CHECK_OUT)..."
for i in $(seq 1 10); do
    (
        if docker compose exec -T postgres psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 -c \
            "CALL sp_create_booking_hold($CUST_ID, $HOTEL_ID, $RT_ID, '$CHECK_IN'::date, '$CHECK_OUT'::date, 1, 2::smallint, NULL, 15, NULL, NULL);" \
            >"$TMP_DIR/out_$i.log" 2>&1; then
            echo "SUCCESS" > "$TMP_DIR/res_$i"
        else
            echo "FAIL" > "$TMP_DIR/res_$i"
        fi
    ) &
done
wait

SUCCESS_COUNT=$(grep -l '^SUCCESS$' "$TMP_DIR"/res_* 2>/dev/null | wc -l)
FAIL_COUNT=$(grep -l '^FAIL$' "$TMP_DIR"/res_* 2>/dev/null | wc -l)

INV_CHECK=$(docker compose exec -T postgres psql -U "$PG_USER" -d "$PG_DB" -At -v ON_ERROR_STOP=1 -c \
    "SELECT MIN(booked_count || ':' || held_count || ':' || total_allotment) FROM room_inventory WHERE room_type_id = $RT_ID AND stay_date >= '$CHECK_IN' AND stay_date < '$CHECK_OUT';")

echo "[T09] Kết quả: Thành công = $SUCCESS_COUNT, Bị từ chối = $FAIL_COUNT, Tồn kho (booked:held:total) = $INV_CHECK"

if [ "$SUCCESS_COUNT" -ne 1 ] || [ "$FAIL_COUNT" -ne 9 ] || [ "$INV_CHECK" != "4:1:5" ]; then
    echo "[T09] FAILED! Mong đợi 1 thành công, 9 thất bại, tồn kho 4:1:5."
    exit 1
fi

echo "[T09] PASSED: Không có overbooking/lost update dưới 10 luồng đồng thời!"
