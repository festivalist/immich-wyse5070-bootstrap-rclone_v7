#!/usr/bin/env bash
set -Eeuo pipefail

# Optionale Einrichtung eines Time-Machine-Ziels (Samba + vfs_fruit + Avahi) fuer
# einen Mac. Die Time-Machine-Daten liegen auf der Daten-HDD und werden vom
# taeglichen Immich-Backup automatisch auf HDD 2 mitgesichert (sobald vorhanden).
#
# Spaeter/erneut ausfuehrbar mit: sudo /opt/immich/scripts/setup-timemachine.sh

DATA_MOUNT="/mnt/immich-data"
TM_DIR="${DATA_MOUNT}/timemachine"
SSH_LAN_CIDR="${SSH_LAN_CIDR:-}"

log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
fail() { printf '[%s] FEHLER: %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "Bitte mit sudo ausfuehren."
findmnt "$DATA_MOUNT" >/dev/null || fail "$DATA_MOUNT ist nicht gemountet."

read -r -p "Benutzername fuer Time Machine (Samba), z.B. tmbackup: " tmuser
[ -n "$tmuser" ] || fail "Benutzername erforderlich."
read -r -p "Maximale Groesse des Time-Machine-Ziels in GB (z.B. 800): " tmsize
case "$tmsize" in ''|*[!0-9]*) fail "Bitte eine ganze Zahl in GB angeben." ;; esac

log "Installiere Samba und Avahi."
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y samba avahi-daemon

if ! id "$tmuser" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "$tmuser"
fi
log "Setze Samba-Passwort fuer ${tmuser} (wird gleich abgefragt)."
smbpasswd -a "$tmuser"

mkdir -p "$TM_DIR"
chown "$tmuser":"$tmuser" "$TM_DIR"
chmod 700 "$TM_DIR"

[ -f /etc/samba/smb.conf.orig ] || cp /etc/samba/smb.conf /etc/samba/smb.conf.orig 2>/dev/null || true

if ! grep -q 'fruit:model' /etc/samba/smb.conf 2>/dev/null; then
  cat >>/etc/samba/smb.conf <<'GLOBALS'

# --- Time Machine (vfs_fruit) global ---
[global]
   min protocol = SMB2
   vfs objects = catia fruit streams_xattr
   fruit:metadata = stream
   fruit:model = MacSamba
   fruit:posix_rename = yes
   fruit:veto_appledouble = no
   fruit:nfs_aces = no
   fruit:wipe_intentionally_left_blank_rfork = yes
   fruit:delete_empty_adfiles = yes
GLOBALS
fi

if ! grep -q '^\[TimeMachine\]' /etc/samba/smb.conf 2>/dev/null; then
  cat >>/etc/samba/smb.conf <<SHARE

[TimeMachine]
   path = ${TM_DIR}
   valid users = ${tmuser}
   writable = yes
   durable handles = yes
   kernel oplocks = no
   kernel share modes = no
   posix locking = no
   vfs objects = catia fruit streams_xattr
   fruit:time machine = yes
   fruit:time machine max size = ${tmsize}G
SHARE
fi

mkdir -p /etc/avahi/services
cat >/etc/avahi/services/timemachine.service <<'AVAHI'
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=RackMac</txt-record>
  </service>
  <service>
    <type>_adisk._tcp</type>
    <port>9</port>
    <txt-record>sys=waMa=0,adVF=0x100</txt-record>
    <txt-record>dk0=adVN=TimeMachine,adVF=0x82</txt-record>
  </service>
</service-group>
AVAHI

if command -v ufw >/dev/null 2>&1; then
  if [ -n "$SSH_LAN_CIDR" ]; then
    log "Erlaube Samba (139/445) nur aus ${SSH_LAN_CIDR}."
    ufw allow from "$SSH_LAN_CIDR" to any port 445 proto tcp || true
    ufw allow from "$SSH_LAN_CIDR" to any port 139 proto tcp || true
  else
    log "Erlaube Samba (UFW-App-Profil Samba). Fuer LAN-Einschraenkung SSH_LAN_CIDR setzen."
    ufw allow Samba || true
  fi
fi

if ! testparm -s >/dev/null 2>&1; then
  log "WARNUNG: testparm meldet ein Problem in /etc/samba/smb.conf. Bitte pruefen."
fi

systemctl enable --now smbd avahi-daemon
systemctl restart smbd avahi-daemon

ip="$(hostname -I | awk '{print $1}')"
cat <<EOF

Time Machine ist eingerichtet.
  Am Mac:  Systemeinstellungen > Time Machine > Volume hinzufuegen.
           Der Server erscheint als Time-Machine-Ziel (ueber Bonjour).
  Manuell: im Finder mit  smb://${ip}  verbinden (Benutzer: ${tmuser}).

  Ziel-Ordner auf dem Server:      ${TM_DIR}
  Maximale Groesse:                ${tmsize} GB
  Die Time-Machine-Daten werden vom taeglichen Immich-Backup automatisch
  auf HDD 2 mitgesichert (sobald HDD 2 vorhanden und der Timer aktiv ist).
EOF
