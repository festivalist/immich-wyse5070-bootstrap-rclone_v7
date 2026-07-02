#!/usr/bin/env bash
# Taeglicher Selbsttest (09:00). Sendet:
#  - sofort eine WARNUNG, wenn etwas nicht stimmt (Platte voll, Backup alt,
#    Mount fehlt, Container gestoppt)
#  - sonntags eine kurze "alles ok"-Zusammenfassung
# Ohne notify-Konfiguration passiert nichts (notify.sh ist dann ein No-Op).
set -u
APP_DIR="/opt/immich"
DATA_MOUNT="/mnt/immich-data"
BACKUP_MOUNT="/mnt/immich-backup"
NOTIFY="$APP_DIR/scripts/notify.sh"
issues=""
info=""

pct() { df --output=pcent "$1" 2>/dev/null | tail -n1 | tr -dc '0-9'; }

p="$(pct /)"; info="System: ${p:-?}%"
[ -n "$p" ] && [ "$p" -ge 85 ] && issues="${issues}- Systemplatte zu ${p}% voll\n"

if findmnt "$DATA_MOUNT" >/dev/null 2>&1; then
  p="$(pct "$DATA_MOUNT")"; info="${info} | Daten: ${p:-?}%"
  [ -n "$p" ] && [ "$p" -ge 85 ] && issues="${issues}- Daten-HDD zu ${p}% voll\n"
else
  issues="${issues}- Daten-HDD ist NICHT gemountet\n"
fi

if findmnt "$BACKUP_MOUNT" >/dev/null 2>&1; then
  p="$(pct "$BACKUP_MOUNT")"; info="${info} | Backup: ${p:-?}%"
  [ -n "$p" ] && [ "$p" -ge 85 ] && issues="${issues}- Backup-HDD zu ${p}% voll\n"
  last="$(ls -1t "$BACKUP_MOUNT"/postgres-dumps/immich-pg-*.sql.gz 2>/dev/null | head -n1 || true)"
  if [ -n "$last" ]; then
    age_h=$(( ( $(date +%s) - $(stat -c %Y "$last") ) / 3600 ))
    info="${info} | letztes Backup: vor ${age_h}h"
    [ "$age_h" -gt 48 ] && issues="${issues}- letztes Backup ist ${age_h} Stunden alt\n"
  else
    issues="${issues}- noch kein Datenbank-Dump auf der Backup-HDD\n"
  fi
else
  info="${info} | Backup-HDD: fehlt (Timer inaktiv)"
fi

if command -v docker >/dev/null 2>&1; then
  run="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -c '^immich_' || true)"
  info="${info} | Container: ${run}/4"
  [ "${run:-0}" -lt 4 ] && issues="${issues}- nur ${run}/4 Immich-Container laufen\n"
fi

if [ -n "$issues" ]; then
  msg="$(printf 'Probleme erkannt:\n%b\n%s' "$issues" "$info")"
  "$NOTIFY" "$msg" "Immich $(hostname): WARNUNG" high
elif [ "$(date +%u)" = "7" ]; then
  "$NOTIFY" "Alles in Ordnung. ${info}" "Immich $(hostname): Wochenbericht" default
fi
exit 0
