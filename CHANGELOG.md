# Changelog

## v7
Aufbauend auf v6. Zerstoerungsfreies Upgrade und Selbstueberwachung.

### Hinzugefuegt
- Upgrade-Modus: bootstrap.sh erkennt eine bestehende Installation
  (/opt/immich/.env bzw. /mnt/immich-data/postgres) und aktualisiert sie
  zerstoerungsfrei: keine Formatierung, .env inkl. DB-Passwort bleibt erhalten,
  Compose/Skripte/Units werden erneuert (mit .bak-Kopien), vorab automatischer
  Sicherheits-Dump, Bestaetigung per UPGRADE-Eingabe.
- Push-Benachrichtigungen (ntfy) + optionaler healthchecks.io-Dead-Man-Switch:
  notify.sh, setup-notify.sh, OnFailure-Hooks fuer Backup/Offsite/Restore-Probe.
- Taeglicher Selbsttest (immich-heartbeat, 09:00): warnt bei voller Platte
  (>= 85 %), altem Backup (> 48 h), fehlendem Mount oder gestoppten Containern;
  sonntags Wochenbericht.
- SMART-Ueberwachung per smartd: Kurztest samstags 03:00, Langtest am 1. des
  Monats 04:00, Alarm via Push. Setzt SMART-faehige USB-Bridges voraus.
- Monatliche Restore-Probe (verify-restore.sh, 1. Sonntag 06:30): neuester Dump
  wird in einen Wegwerf-Postgres-Container eingespielt und inhaltlich geprueft.
- Fuellstandswaechter im Backup-Skript: Warnung ab 85 %, kontrollierter Abbruch
  ab 95 %.
- Docker-Logrotation (daemon.json, 3x10 MB) und monatliches docker image prune
  (15., 05:15).
- Automatischer Reboot nach Kernel-Updates (05:45 Uhr).
- Hardware-Watchdog (systemd RuntimeWatchdogSec=10min) und 2-GB-Swapfile bei
  <= 8 GB RAM (vm.swappiness=10).

### Geaendert
- install_docker ueberspringt die Installation, wenn Docker bereits vorhanden ist.
- ufw --force reset laeuft nur noch bei Neuinstallation; im Upgrade-Modus bleiben
  bestehende Firewall-Regeln (z. B. Samba, Tailscale) erhalten.

## v6
Aufbauend auf v5. Betriebsflexibilitaet: Setup mit nur einer HDD und optionales
Time-Machine-Ziel fuer einen Mac.

### Geaendert
- Backup-HDD beim Setup optional: Bei der Abfrage leer lassen richtet Immich ohne
  Backup-Platte ein (Backup-Timer bleibt inaktiv), statt abzubrechen. Ideal, wenn
  die zweite HDD erst spaeter verfuegbar ist.

### Hinzugefuegt
- scripts/add-backup-disk.sh: Ruestet die zweite HDD spaeter nach (Formatierung,
  fstab-Eintrag, Ordnerstruktur) und aktiviert den taeglichen Backup-Timer.
- scripts/setup-timemachine.sh: Optionales Time-Machine-Ziel fuer einen Mac (Samba
  + vfs_fruit + Avahi). Interaktiv (ja/nein) im Bootstrap oder jederzeit spaeter.
- Time-Machine-Daten werden vom taeglichen Backup automatisch auf HDD 2 mitgesichert
  (rclone sync ohne Versionierung, da das TM-Sparsebundle staendig neue Baender
  schreibt und eine Versionierung die Platte fluten wuerde).

## v5
Aufbauend auf v4. Aktualitaet (Stand Juni 2026) und Robustheit.

### Geaendert
- **Immich-Version gepinnt:** `IMMICH_VERSION` von `release` auf `v2`. Verhindert
  einen unbemerkten Sprung auf den naechsten Major beim `docker compose pull`.
  (`.env`-Erzeugung in `bootstrap.sh` und `config/immich.env.template`.)
- **Valkey 9:** Redis/Valkey-Image von `valkey:8-bookworm` auf `valkey:9`
  angehoben (entspricht dem aktuellen offiziellen Immich-Compose). Healthcheck
  um `interval/timeout/retries/start_period` ergaenzt.
- **DB-Healthcheck:** Der `database`-Dienst hat jetzt einen `pg_isready`-
  Healthcheck. `immich-server` wartet via `depends_on: condition: service_healthy`
  auf Datenbank und Redis — saubererer Start.
- **Schonenderer Backup-Lauf:** Die naechtliche `rclone sync` vergleicht
  Groesse+Aenderungszeit statt jede Datei per Pruefsumme zu lesen. Sonntags
  laeuft zusaetzlich eine vollstaendige `rclone check --checksum`-Kontrolle
  (erkennt Bit-Rot). Schneller und schont die USB-Platte.

### Hinzugefuegt
- **`RequiresMountsFor`** im `immich-backup.service`: Der Timer startet nur,
  wenn beide HDDs (`/mnt/immich-data`, `/mnt/immich-backup`) gemountet sind.
- **Optionales Offsite-Backup** (3-2-1-Regel): `scripts/immich-offsite.sh`,
  `config/offsite.env.template` sowie `systemd/immich-offsite.{service,timer}`.
  Werden vom Bootstrap installiert, aber NICHT aktiviert. Aktivierung per
  `rclone config` + `offsite.env` + `systemctl enable --now immich-offsite.timer`.

## v4
- **Fix:** Korrekte Tailscale-Paketquelle. Primaer der offizielle Installer
  (`https://tailscale.com/install.sh`), als Fallback die korrekte Listendatei
  `<codename>.tailscale-keyring.list`.
- Restore-Postgres wartet auf `pg_isready` und enthaelt die `search_path`-
  Korrektur fuer VectorChord/pgvector.
- `/dev/dri` aus dem ML-Dienst entfernt (ohne `-openvino`-Image wirkungslos).

## v3 (fehlerhaft — nicht verwenden)
- Tailscale-Listen-URL fehlerhaft (`<codename>.tailscale-list` statt
  `<codename>.tailscale-keyring.list`). `curl -f` liefert 404, das Skript bricht
  wegen `set -Eeuo pipefail` ab.
