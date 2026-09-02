#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-/srv/apps/OSK-Manager/deploy}"
BACKUP_DIR="${BACKUP_DIR:-/srv/backups/osk-manager/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-osk_manager}"
POSTGRES_USER="${POSTGRES_USER:-osk_manager}"

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_file="${BACKUP_DIR}/osk-manager-postgres-${timestamp}.dump"

mkdir -p "$BACKUP_DIR"

cd "$COMPOSE_DIR"

docker compose --profile postgres exec -T "$POSTGRES_SERVICE" \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc \
  > "$backup_file"

find "$BACKUP_DIR" \
  -type f \
  -name 'osk-manager-postgres-*.dump' \
  -mtime +"$RETENTION_DAYS" \
  -delete

echo "Created backup: $backup_file"
ls -lh "$backup_file"
