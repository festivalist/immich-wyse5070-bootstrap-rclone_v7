#!/usr/bin/env bash
set -Eeuo pipefail
# Interaktive Einrichtung der Push-Benachrichtigungen (ntfy + optional
# healthchecks.io Dead-Man-Switch). Jederzeit erneut ausfuehrbar:
#   sudo /opt/immich/scripts/setup-notify.sh
APP_DIR="/opt/immich"
CONF="$APP_DIR/notify.env"
log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
fail() { printf '[%s] FEHLER: %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }
[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Bitte mit sudo ausfuehren."

suggest="immich-$(hostname | tr -cd 'a-z0-9')-$(tr -dc 'a-z0-9' </dev/urandom | head -c 8 || true)"
cat <<EOF

=== Push-Benachrichtigungen einrichten (ntfy) ===
1. Auf dem iPhone/Android die kostenlose App "ntfy" installieren.
2. Hier ein Topic festlegen. Das Topic wirkt wie ein Passwort:
   lang und zufaellig waehlen, niemandem weitergeben.
3. In der App dieses Topic abonnieren - fertig.

Vorschlag fuer dein Topic: ${suggest}
EOF
read -r -p "Topic uebernehmen oder eigenes eingeben [Enter = Vorschlag]: " topic
topic="${topic:-$suggest}"
read -r -p "Optional: healthchecks.io Ping-URL (Enter = keine): " hcurl

umask 077
cat >"$CONF" <<EOF
NTFY_SERVER=https://ntfy.sh
NTFY_TOPIC=${topic}
HEALTHCHECK_URL=${hcurl}
EOF
chmod 600 "$CONF"
log "Konfiguration gespeichert: $CONF"
log "Sende Testnachricht..."
"$APP_DIR/scripts/notify.sh" "Testnachricht: Benachrichtigungen sind eingerichtet." "Immich $(hostname)" default
cat <<EOF

Testnachricht verschickt. In der ntfy-App dieses Topic abonnieren:
  ${topic}
Kommt nichts an: Topic in der App exakt gleich schreiben, Internet pruefen.
EOF
