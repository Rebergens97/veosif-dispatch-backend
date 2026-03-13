#!/usr/bin/env bash
# scripts/backup-db.sh
# Backup bazdone fleetbase sou yon fichye SQL.
# Itilizasyon: ./scripts/backup-db.sh   ou   bash scripts/backup-db.sh
# Backup yo ale nan scripts/backups/ (kreye otomatikman si pa egziste).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/scripts/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/fleetbase_$TIMESTAMP.sql"

cd "$PROJECT_ROOT"
mkdir -p "$BACKUP_DIR"

echo "⏳  Backup fleetbase nan $BACKUP_FILE ..."
docker compose exec -T database mysqldump -uroot fleetbase > "$BACKUP_FILE"

if [[ -s "$BACKUP_FILE" ]]; then
  echo "✔  Backup reyisi: $BACKUP_FILE"
  echo "   Restore avèk: docker compose exec -T database mysql -uroot fleetbase < $BACKUP_FILE"
else
  echo "✖  Backup vid oswa echwe."
  rm -f "$BACKUP_FILE"
  exit 1
fi
