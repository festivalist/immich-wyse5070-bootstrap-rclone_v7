#!/usr/bin/env bash
set -Eeuo pipefail
# Monatliche Restore-Probe: spielt den neuesten PostgreSQL-Dump in einen
# Wegwerf-Container ein und prueft, ob Tabellen und Inhalte ankommen.
# Ein Backup ist erst dann ein Backup, wenn der Restore bewiesen ist.
APP_DIR="/opt/immich"
BACKUP_MOUNT="/mnt/immich-backup"
NOTIFY="$APP_DIR/scripts/notify.sh"
CNAME="immich_restore_test"
TMPDIR_DATA=""

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

cleanup() {
  docker rm -f "$CNAME" >/dev/null 2>&1 || true
  [ -n "$TMPDIR_DATA" ] && rm -rf "$TMPDIR_DATA"
}
trap cleanup EXIT

findmnt "$BACKUP_MOUNT" >/dev/null 2>&1 || { log "Backup-HDD nicht gemountet - Probe uebersprungen."; exit 0; }
DUMP="$(ls -1t "$BACKUP_MOUNT"/postgres-dumps/immich-pg-*.sql.gz 2>/dev/null | head -n1 || true)"
[ -n "$DUMP" ] || { log "Kein Dump vorhanden - Probe uebersprungen."; exit 0; }

IMAGE="$(awk '/immich-app\/postgres/{print $2; exit}' "$APP_DIR/docker-compose.yml" || true)"
[ -n "$IMAGE" ] || IMAGE="ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0"

TMPDIR_DATA="$(mktemp -d "$BACKUP_MOUNT/.restore-test.XXXXXX")"
log "Starte Wegwerf-Datenbank ($IMAGE)."
docker rm -f "$CNAME" >/dev/null 2>&1 || true
docker run -d --name "$CNAME" \
  -e POSTGRES_PASSWORD=restoretest \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=postgres \
  -v "$TMPDIR_DATA":/var/lib/postgresql/data \
  "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
  docker exec "$CNAME" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 2
done
docker exec "$CNAME" pg_isready -U postgres >/dev/null 2>&1 || { echo "Wegwerf-Datenbank startet nicht." >&2; exit 1; }

log "Spiele Dump ein: $(basename "$DUMP")"
gunzip -c "$DUMP" \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | docker exec -i "$CNAME" psql -q -U postgres -d postgres >/dev/null

tables="$(docker exec "$CNAME" psql -tA -U postgres -d immich -c \
  "select count(*) from pg_tables where schemaname='public'" 2>/dev/null || echo 0)"
tables="${tables//[^0-9]/}"; tables="${tables:-0}"
counts=""
for t in assets asset albums album users user; do
  n="$(docker exec "$CNAME" psql -tA -U postgres -d immich -c "select count(*) from \"$t\"" 2>/dev/null || true)"
  n="${n//[^0-9]/}"
  [ -n "$n" ] && counts="${counts}${t}=${n} "
done

if [ "$tables" -lt 10 ]; then
  echo "Zu wenige Tabellen nach Restore: ${tables}" >&2
  exit 1
fi
log "Restore-Probe erfolgreich: ${tables} Tabellen, ${counts:-keine Detailzaehlung}"
"$NOTIFY" "Restore-Probe erfolgreich: ${tables} Tabellen, ${counts:-keine Detailzaehlung}(Dump: $(basename "$DUMP"))" "Immich $(hostname): Restore-Probe OK" default
exit 0
