# Git-Deployment v7 auf den Ziel-PC (Referenzanleitung)

Diese Anleitung bringt das Paket `immich-wyse5070-bootstrap-rclone_v7.zip` in ein
bestehendes lokales Git-Repository auf einem anderen PC, entfernt dabei alle
obsoleten Altdateien und committet nur den aktuellen v7-Stand.

Auszufuehren in **PowerShell** (Windows 10/11 Standard) auf dem Ziel-PC, auf dem
das Repository liegt — nicht auf diesem Rechner.

## Schritte

```powershell
# 1. Pfade anpassen
$RepoPath   = "C:\Pfad\zu\deinem\lokalen\repo\immich-wyse5070-bootstrap-rclone"
$ZipPath    = "C:\Pfad\zu\immich-wyse5070-bootstrap-rclone_v7.zip"
$ExtractTmp = "$env:TEMP\immich_v7_extract"

# 2. ZIP in einen temporaeren Ordner entpacken (nicht direkt ins Repo)
Expand-Archive -Path $ZipPath -DestinationPath $ExtractTmp -Force

# 3. Das ZIP enthaelt einen Ordner "immich-wyse5070-bootstrap-rclone" - das ist die Quelle
$SourceFolder = Join-Path $ExtractTmp "immich-wyse5070-bootstrap-rclone"

# 4. Ins Repo wechseln und zur Kontrolle den Zustand pruefen, BEVOR irgendetwas geloescht wird
Set-Location $RepoPath
git status
git log --oneline -5
```

**Stopp an dieser Stelle und `git status` pruefen:** Sind noch nicht committete
eigene Aenderungen im Repo, die behalten werden sollen? Falls ja, erst
sichern/committen. Erst wenn der Stand sauber ist, weitermachen:

```powershell
# 5. Alles im Repo AUSSER dem .git-Ordner loeschen (entfernt die obsoleten Altdateien)
Get-ChildItem -Path $RepoPath -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force

# 6. Den neuen v7-Inhalt ins Repo-Root kopieren
Copy-Item -Path (Join-Path $SourceFolder "*") -Destination $RepoPath -Recurse -Force

# 7. Kontrolle: zeigt neue/geloeschte/geaenderte Dateien VOR dem Commit
git add -A
git status

# 8. Commit
git commit -m "Update auf v7: Upgrade-Modus, Benachrichtigungen, Ueberwachung, Haertung"

# 9. Push
git push
```

## Wichtige Hinweise

- **Schritt 5 ist destruktiv** (`Remove-Item -Recurse -Force`) und loescht *alles*
  ausser `.git`. Unbedingt sicherstellen, dass `$RepoPath` wirklich auf das
  richtige Repo zeigt, bevor diese Zeile ausgefuehrt wird — ein falscher Pfad
  wuerde den falschen Ordner leeren.
- Zwischen Schritt 7 (`git add -A` + `git status`) und Schritt 8 lohnt sich ein
  Blick auf die Ausgabe: Die alten Handbuch-/Skriptversionen sollten als
  `deleted:`, die v7-Dateien als `new file:`/`modified:` gelistet sein.
- Falls das Repo einen Branch-Schutz auf `main` hat oder Unsicherheit besteht:
  erst `git checkout -b update-v7`, dann Schritte 5-8, dann
  `git push -u origin update-v7` und per Pull Request mergen, statt direkt auf
  `main` zu pushen.
- Falls im Repo bereits eine `.gitignore` lag: Die geht in Schritt 5 verloren,
  da das v7-ZIP keine enthaelt. Bei Bedarf vorher sichern und danach wieder
  reinkopieren.

## Kontext

Erstellt am 02.07.2026 im Rahmen des Immich-Wyse5070-Projekts (siehe Memory
`immich-wyse-projekt`). Zugehoerige Pakete: `immich-wyse5070-bootstrap-rclone_v7.zip`
und `Immich_Admin_Handbuch_Wyse5070_Ubuntu2404_v7.docx` liegen im Projekt-Root
(nicht in diesem Archiv-Ordner).
