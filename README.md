# Windows-Bridge

Startet Windows-Programme und die **Windows-Version von Steam** auf dem Mac (Apple Silicon und Intel).

Windows-Bridge übernimmt die Einrichtung: Es installiert Rosetta 2, lädt Wine herunter, legt eine Windows-Umgebung an, installiert Steam und erstellt eine Mac-App, auf die man `.exe`-Dateien ziehen kann. Die eigentliche Übersetzung der Windows-Programme erledigt [Wine](https://www.winehq.org) (in den macOS-Builds von [Gcenx](https://github.com/Gcenx/macOS_Wine_builds)). DirectX 10/11 lässt sich optional über [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) → Vulkan → Metal beschleunigen.

## Installation

Terminal öffnen und einfügen:

```bash
curl -fsSL https://raw.githubusercontent.com/Solilus/Windows-Bridge/main/install.sh | bash
```

Danach liegt **Windows-Bridge.app** in `~/Applications` (Programme-Ordner deines Benutzers).

**Alternativ:** Repository als ZIP herunterladen, entpacken und `Windows-Bridge.command` doppelklicken. Beim ersten Mal blockiert macOS das Skript eventuell. Dann unter **Systemeinstellungen → Datenschutz & Sicherheit** auf **„Trotzdem öffnen“** klicken.

## Benutzung

- **App doppelklicken:** Es öffnet sich ein Menü mit den Optionen Programm starten, Steam, DXVK an/aus, Laufwerk C:, Einstellungen und Beenden.
- **`.exe` auf das App-Symbol ziehen**, oder Rechtsklick auf die Datei → *Öffnen mit* → Windows-Bridge.
- **Im Terminal:**

| Befehl | Funktion |
|---|---|
| `windows-bridge` | Menü |
| `windows-bridge run Datei.exe` | Windows-Programm starten |
| `windows-bridge steam` | Windows-Steam installieren/starten |
| `windows-bridge dxvk an` / `aus` | DirectX-10/11-Beschleunigung |
| `windows-bridge laufwerk` | Laufwerk C: im Finder öffnen |
| `windows-bridge config` | Wine-Einstellungen (winecfg) |
| `windows-bridge stop` | Alle Windows-Programme beenden |
| `windows-bridge entfernen` | Alles in den Papierkorb legen |

Daten liegen in `~/Library/Application Support/Windows-Bridge`, Protokolle unter `logs/`.

## Grenzen

- **DirectX 12** wird nicht unterstützt (dafür bräuchte es Apples D3DMetal, das nicht frei weitergegeben werden darf).
- Spiele mit **Anti-Cheat** (viele Online-Shooter) starten meist nicht.
- Auf Macs mit 8 GB RAM laufen eher ältere oder leichte Spiele flüssig.

## Lizenz der Komponenten

Wine steht unter der LGPL, DXVK unter der zlib-Lizenz. Steam ist ein Produkt von Valve und wird direkt von Valve heruntergeladen.
