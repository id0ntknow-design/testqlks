#!/usr/bin/env bash
# =============================================================================
# backup.sh (T18)
# Tạo bản sao lưu chuẩn định dạng custom (-Fc) bằng pg_dump
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="$ROOT_DIR/database/backups"
mkdir -p "$BACKUP_DIR"

PG_USER="${POSTGRES_USER:-db_migrator}"
PG_DB="${POSTGRES_DB:-hotel_ota}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${PG_DB}_${TIMESTAMP}.dump"

echo "[BACKUP] Đang sao lưu CSDL '$PG_DB' -> $BACKUP_FILE ..."
docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T postgres \
    pg_dump -U "$PG_USER" -d "$PG_DB" -Fc --no-owner --no-acl > "$BACKUP_FILE"

ln -sfn "$(basename "$BACKUP_FILE")" "$BACKUP_DIR/latest.dump"
SIZE_BYTES=$(wc -c < "$BACKUP_FILE")
echo "[BACKUP] Hoàn tất: $BACKUP_FILE ($SIZE_BYTES bytes)."
