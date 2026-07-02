#!/usr/bin/env bash
# Zentrale Benachrichtigungsfunktion (ntfy-Push aufs Smartphone).
# Aufruf: notify.sh "<Nachricht>" ["<Titel>"] ["default|high"]
# Ohne Konfiguration (/opt/immich/notify.env) ist das Skript ein No-Op,
# damit OnFailure-Hooks niemals selbst Fehler erzeugen.
set -u
CONF="/opt/immich/notify.env"
[ -f "$CONF" ] || exit 0
. "$CONF"
MSG="${1:-Meldung vom Immich-Server}"
TITLE="${2:-Immich $(hostname)}"
PRIO="${3:-default}"
if [ -n "${NTFY_TOPIC:-}" ]; then
  curl -fsS -m 10 \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIO}" \
    -d "${MSG}" \
    "${NTFY_SERVER:-https://ntfy.sh}/${NTFY_TOPIC}" >/dev/null 2>&1 || true
fi
exit 0
