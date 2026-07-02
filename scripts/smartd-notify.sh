#!/usr/bin/env bash
# Wird von smartd bei Festplatten-Problemen aufgerufen (-M exec).
# smartd setzt SMARTD_DEVICE, SMARTD_MESSAGE, SMARTD_FAILTYPE als Umgebung.
set -u
MSG="SMART-Warnung: ${SMARTD_DEVICE:-unbekannt} - ${SMARTD_MESSAGE:-keine Details}"
/opt/immich/scripts/notify.sh "$MSG" "Immich $(hostname): Festplatten-Warnung" high
exit 0
