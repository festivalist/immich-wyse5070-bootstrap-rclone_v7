#!/usr/bin/env bash
set -Eeuo pipefail

# Nachruesten der Backup-HDD, wenn beim ersten Setup nur die Daten-HDD vorhanden
# war. Formatiert die zweite HDD, mountet sie dauerhaft und aktiviert den
# taeglichen Backup-Timer.

DATA_MOUNT="/mnt/immich-data"
BACKUP_MOUNT="/mnt/immich-backup"

log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
fail() { printf '[%s] FEHLER: %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Bitte mit sudo ausfuehren."
findmnt "$DATA_MOUNT" >/dev/null || fail "$DATA_MOUNT ist nicht gemountet. Zuerst das Grundsetup abschliessen."
if findmnt "$BACKUP_MOUNT" >/dev/null 2>&1; then
  fail "$BACKUP_MOUNT ist bereits gemountet. Nichts zu tun."
fi

root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
root_pk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1 || true)"
root_disk="/dev/${root_pk:-__none__}"
data_src="$(findmnt -n -o SOURCE "$DATA_MOUNT" 2>/dev/null || true)"

log "Verfuegbare Datentraeger:"
lsblk -dpno NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS | grep -v '^/dev/loop' || true
printf '\nSystemplatte: %s   Datenplatte: %s\n' "$root_disk" "${data_src:-unbekannt}"
printf 'Diese beiden nicht auswaehlen.\n\n'

read -r -p "Geraet fuer die Backup-HDD eingeben, z.B. /dev/sdb: " backup_disk
[ -b "$backup_disk" ] || fail "Geraet existiert nicht: $backup_disk"
[ "$backup_disk" != "$root_disk" ] || fail "Das ist die Systemplatte."
[ "$backup_disk" != "$data_src" ]  || fail "Das ist die Datenplatte."
findmnt -S "$backup_disk" >/dev/null 2>&1 && fail "Geraet ist bereits gemountet: $backup_disk"

printf 'WARNUNG: %s wird vollstaendig geloescht.\n' "$backup_disk"
read -r -p "Zum Fortfahren exakt eingeben: FORMAT $backup_disk : " ans
[ "$ans" = "FORMAT $backup_disk" ] || fail "Bestaetigung fehlgeschlagen."

log "Erstelle ext4-Dateisystem."
wipefs -a "$backup_disk"
mkfs.ext4 -F -L IMMICH_BACKUP "$backup_disk"
backup_uuid="$(blkid -s UUID -o value "$backup_disk")"

mkdir -p "$BACKUP_MOUNT"
cp /etc/fstab /etc/fstab.bak.$(date +%F_%H%M%S)
grep -v "${BACKUP_MOUNT}" /etc/fstab >/etc/fstab.tmp
cat /etc/fstab.tmp >/etc/fstab
rm -f /etc/fstab.tmp
printf 'UUID=%s %s ext4 defaults,nofail,x-systemd.device-timeout=30s 0 2\n' \
  "$backup_uuid" "$BACKUP_MOUNT" >>/etc/fstab

systemctl daemon-reload
mount -a
findmnt "$BACKUP_MOUNT" || fail "Backup-Mount fehlgeschlagen."

mkdir -p "$BACKUP_MOUNT/current" "$BACKUP_MOUNT/versions" \
  "$BACKUP_MOUNT/postgres-dumps" "$BACKUP_MOUNT/compose-backup" "$BACKUP_MOUNT/logs"

systemctl enable --now immich-backup.timer
log "Backup-HDD eingebunden und Timer aktiviert."
log "Erstes Backup jetzt testen: sudo systemctl start immich-backup.service"
