#!/usr/bin/env bash
# =============================================================================
# restore.sh (T18)
# Phục hồi bản .dump sang CSDL sạch và đối chiếu 100% bảng, dòng, doanh thu & payout
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="$ROOT_DIR/database/backups"
DUMP_FILE="${1:-$BACKUP_DIR/latest.dump}"

if [ -L "$DUMP_FILE" ]; then
    DUMP_FILE="$BACKUP_DIR/$(readlink "$DUMP_FILE")"
fi

if [ ! -f "$DUMP_FILE" ]; then
    echo "[RESTORE] Không tìm thấy file backup: $DUMP_FILE"
    exit 1
fi

PG_USER="${POSTGRES_USER:-db_migrator}"
PG_DB="${POSTGRES_DB:-hotel_ota}"
RESTORE_DB="${PG_DB}_restore_verify"

SNAPSHOT_QUERY="SELECT
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE') || '|' ||
    (SELECT COUNT(*) FROM bookings) || '|' ||
    (SELECT COALESCE(SUM(total_amount), 0) FROM bookings) || '|' ||
    (SELECT COALESCE(SUM(net_payout), 0) FROM partner_payouts);"

SRC_METRICS=$(docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    psql -U "$PG_USER" -d "$PG_DB" -At -c "$SNAPSHOT_QUERY")

echo "[RESTORE] Chỉ số nguồn ($PG_DB): tables|bookings|total_amount|net_payout = $SRC_METRICS"
echo "[RESTORE] Tạo CSDL sạch '$RESTORE_DB' và chạy pg_restore từ $(basename "$DUMP_FILE")..."

docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    psql -U "$PG_USER" -d postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS $RESTORE_DB;" \
    -c "CREATE DATABASE $RESTORE_DB OWNER $PG_USER;" >/dev/null

docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    pg_restore -U "$PG_USER" -d "$RESTORE_DB" --no-owner --no-acl -v < "$DUMP_FILE" 2>"$BACKUP_DIR/restore.log"

DST_METRICS=$(docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    psql -U "$PG_USER" -d "$RESTORE_DB" -At -c "$SNAPSHOT_QUERY")

echo "[RESTORE] Chỉ số đích ($RESTORE_DB): tables|bookings|total_amount|net_payout = $DST_METRICS"

docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    psql -U "$PG_USER" -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS $RESTORE_DB;" >/dev/null

if [ "$SRC_METRICS" != "$DST_METRICS" ]; then
    echo "[RESTORE] FAILED! Sai lệch dữ liệu sau phục hồi."
    exit 1
fi

echo "[RESTORE] PASSED: Khôi phục khớp 100% số bảng, số đơn, doanh thu và payout!"
