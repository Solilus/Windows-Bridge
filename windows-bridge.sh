#!/bin/bash
# =============================================================================
#  Windows-Bridge – Windows-Programme auf dem Mac starten (auf Basis von Wine)
# -----------------------------------------------------------------------------
#  Benutzung im Terminal:
#     bash windows-bridge.sh                 Menü anzeigen
#     bash windows-bridge.sh setup           Wine + Rosetta einrichten
#     bash windows-bridge.sh app             Windows-Bridge.app in ~/Programme anlegen
#     bash windows-bridge.sh run DATEI.exe   Windows-Programm (.exe/.msi/.bat) starten
#     bash windows-bridge.sh steam-install   Windows-Steam installieren
#     bash windows-bridge.sh steam           Windows-Steam starten
#     bash windows-bridge.sh dxvk an|aus     DirectX 10/11 über Vulkan/Metal (DXVK)
#     bash windows-bridge.sh config          Wine-Einstellungen (winecfg)
#     bash windows-bridge.sh laufwerk        Laufwerk C: im Finder öffnen
#     bash windows-bridge.sh stop            Alle Windows-Programme beenden
#     bash windows-bridge.sh entfernen       Alles in den Papierkorb legen
#
#  Die eigentliche Übersetzungsarbeit macht Wine (Open Source, LGPL) in den
#  macOS-Builds von Gcenx; x86-Code übersetzt Apples Rosetta 2.
# =============================================================================
set -uo pipefail

VERSION="1.0"
WINE_TAG="11.0_1"
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_TAG}/wine-stable-${WINE_TAG}-osx64.tar.xz"
DXVK_NAME="dxvk-macOS-async-v1.10.3-20230507-repack"
DXVK_URL="https://github.com/Gcenx/DXVK-macOS/releases/download/v1.10.3-20230507-repack/${DXVK_NAME}.tar.gz"
STEAM_URL="https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe"

BASE="$HOME/Library/Application Support/Windows-Bridge"
WINE_DIR="$BASE/wine"
WINE_APP="$WINE_DIR/Wine Stable.app"
WINE_BIN="$WINE_APP/Contents/Resources/wine/bin"
PREFIX="$BASE/prefix"
CACHE="$BASE/cache"
LOGS="$BASE/logs"
CONF="$BASE/einstellungen.conf"
SELF_COPY="$BASE/windows-bridge.sh"
APP_PATH="$HOME/Applications/Windows-Bridge.app"

GUI=0   # 1 = Meldungen als macOS-Dialoge statt im Terminal

# ----------------------------------------------------------------- Hilfen ---
info()  { [ "$GUI" = 1 ] || printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { [ "$GUI" = 1 ] || printf '\033[1;32m✓\033[0m %s\n' "$*"; }

fehler() {
  if [ "$GUI" = 1 ]; then
    osascript -e "display alert \"Windows-Bridge\" message \"$(printf '%s' "$*" | sed 's/"/\\"/g')\" as critical" >/dev/null 2>&1
  else
    printf '\033[1;31mFehler:\033[0m %s\n' "$*" >&2
  fi
  exit 1
}

hinweis() {
  if [ "$GUI" = 1 ]; then
    osascript -e "display notification \"$(printf '%s' "$*" | sed 's/"/\\"/g')\" with title \"Windows-Bridge\"" >/dev/null 2>&1
  else
    info "$*"
  fi
}

lade_einstellungen() {
  DXVK_AKTIV=0
  # shellcheck disable=SC1090
  [ -f "$CONF" ] && . "$CONF"
}

speichere_einstellungen() {
  mkdir -p "$BASE"
  printf 'DXVK_AKTIV=%s\n' "$DXVK_AKTIV" > "$CONF"
}

wine_umgebung() {
  lade_einstellungen
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="-all"
  export PATH="$WINE_BIN:$PATH"
  # Keine Startmenü-Verknüpfungen im Mac-System anlegen
  local ov="winemenubuilder.exe=d"
  if [ "$DXVK_AKTIV" = 1 ]; then
    ov="$ov;d3d11,d3d10core=n,b"
    export DXVK_ASYNC=1
    export MVK_CONFIG_RESUME_LOST_DEVICE=1
  fi
  export WINEDLLOVERRIDES="$ov"
}

ist_eingerichtet() {
  [ -x "$WINE_BIN/wine" ] && [ -f "$PREFIX/system.reg" ]
}

pruefe_einrichtung() {
  ist_eingerichtet || fehler "Windows-Bridge ist noch nicht eingerichtet. Bitte zuerst ausführen: bash windows-bridge.sh setup"
}

# ------------------------------------------------------------- Einrichtung ---
cmd_setup() {
  [ "$(uname -s)" = "Darwin" ] || fehler "Dieses Programm läuft nur auf macOS."

  # 1) Rosetta 2 – übersetzt die x86-Teile von Wine und den Windows-Programmen
  if [ "$(uname -m)" = "arm64" ]; then
    if arch -x86_64 /usr/bin/true 2>/dev/null; then
      ok "Rosetta 2 ist bereits installiert."
    else
      info "Installiere Rosetta 2 (ggf. Passwort eingeben) …"
      softwareupdate --install-rosetta --agree-to-license \
        || fehler "Rosetta 2 konnte nicht installiert werden."
      ok "Rosetta 2 installiert."
    fi
  fi

  mkdir -p "$WINE_DIR" "$CACHE" "$LOGS"

  # 2) Wine herunterladen
  if [ -x "$WINE_BIN/wine" ]; then
    ok "Wine ist bereits vorhanden."
  else
    local archiv="$CACHE/wine-${WINE_TAG}.tar.xz"
    info "Lade Wine ${WINE_TAG} herunter (ca. 200 MB) …"
    curl -fL --progress-bar -o "$archiv.part" "$WINE_URL" \
      || fehler "Download von Wine fehlgeschlagen. Internetverbindung prüfen."
    mv "$archiv.part" "$archiv"
    info "Entpacke Wine …"
    tar -xJf "$archiv" -C "$WINE_DIR" || fehler "Wine-Archiv konnte nicht entpackt werden."
    rm -f "$archiv"
    [ -x "$WINE_BIN/wine" ] || fehler "Wine wurde nicht gefunden – das Archiv hat einen unerwarteten Aufbau."
    ok "Wine installiert."
  fi

  # 3) Windows-Umgebung („Flasche“) anlegen
  wine_umgebung
  if [ -f "$PREFIX/system.reg" ]; then
    ok "Windows-Umgebung existiert bereits."
  else
    info "Lege Windows-Umgebung an (dauert beim ersten Mal 1–2 Minuten) …"
    "$WINE_BIN/wineboot" --init >"$LOGS/setup.log" 2>&1 \
      || fehler "Windows-Umgebung konnte nicht angelegt werden. Details: $LOGS/setup.log"
    "$WINE_BIN/wineserver" -w 2>/dev/null
    # Windows 10 melden, Retina-Modus für scharfe Darstellung
    "$WINE_BIN/wine" reg add 'HKCU\Software\Wine' /v Version /d win10 /f >/dev/null 2>&1
    "$WINE_BIN/wine" reg add 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /d y /f >/dev/null 2>&1
    "$WINE_BIN/wineserver" -w 2>/dev/null
    ok "Windows-Umgebung angelegt."
  fi

  # Kopie des Skripts an festen Ort, damit die App es findet
  local quelle
  quelle="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  [ "$quelle" = "$SELF_COPY" ] || cp "$quelle" "$SELF_COPY"
  chmod +x "$SELF_COPY"

  ok "Fertig! Tipp: 'bash windows-bridge.sh app' legt eine Windows-Bridge.app an."
}

# -------------------------------------------------------------- Mac-App ---
cmd_app() {
  [ -f "$SELF_COPY" ] || cmd_setup
  mkdir -p "$HOME/Applications"
  local tmp
  tmp="$(mktemp -t windows-bridge).applescript"
  cat > "$tmp" <<APPLESCRIPT
property skript : "$SELF_COPY"

on run
	do shell script "/bin/bash " & quoted form of skript & " gui > /dev/null 2>&1 &"
end run

on open dateien
	repeat with d in dateien
		do shell script "/bin/bash " & quoted form of skript & " gui-run " & quoted form of (POSIX path of d) & " > /dev/null 2>&1 &"
	end repeat
end open
APPLESCRIPT
  rm -rf "$APP_PATH"
  osacompile -o "$APP_PATH" "$tmp" || fehler "App konnte nicht erstellt werden."
  rm -f "$tmp"
  ok "App erstellt: $APP_PATH"
  info "Doppelklick öffnet das Menü. .exe-Dateien kannst du auf das App-Symbol ziehen"
  info "oder per Rechtsklick → Öffnen mit → Windows-Bridge starten."
}

# ------------------------------------------------------- Programme starten ---
cmd_run() {
  local datei="${1:-}"
  [ -n "$datei" ] || fehler "Bitte eine Datei angeben, z. B.: bash windows-bridge.sh run ~/Downloads/setup.exe"
  [ -f "$datei" ] || fehler "Datei nicht gefunden: $datei"
  pruefe_einrichtung
  wine_umgebung
  mkdir -p "$LOGS"
  local log="$LOGS/$(basename "$datei").log"
  hinweis "Starte $(basename "$datei") …"
  (cd "$(dirname "$datei")" && "$WINE_BIN/wine" start /unix "$datei") >"$log" 2>&1 &
  ok "Läuft. Protokoll: $log"
}

steam_exe() {
  local p
  for p in "$PREFIX/drive_c/Program Files (x86)/Steam/steam.exe" \
           "$PREFIX/drive_c/Program Files/Steam/steam.exe"; do
    [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

cmd_steam_install() {
  pruefe_einrichtung
  wine_umgebung
  if steam_exe >/dev/null; then ok "Steam ist bereits installiert."; return 0; fi
  mkdir -p "$CACHE" "$LOGS"
  hinweis "Lade Steam-Installer herunter …"
  curl -fL --progress-bar -o "$CACHE/SteamSetup.exe" "$STEAM_URL" \
    || fehler "Steam-Installer konnte nicht geladen werden."
  hinweis "Installiere Steam …"
  "$WINE_BIN/wine" "$CACHE/SteamSetup.exe" /S >"$LOGS/steam-install.log" 2>&1
  "$WINE_BIN/wineserver" -w 2>/dev/null
  steam_exe >/dev/null || fehler "Steam-Installation fehlgeschlagen. Details: $LOGS/steam-install.log"
  ok "Steam installiert. Starten mit: bash windows-bridge.sh steam"
}

cmd_steam() {
  pruefe_einrichtung
  local exe
  exe="$(steam_exe)" || cmd_steam_install
  exe="$(steam_exe)" || exit 1
  wine_umgebung
  hinweis "Starte Steam (der erste Start mit Update dauert einige Minuten) …"
  # -cef-disable-gpu: Steams eingebauter Browser läuft unter Wine sonst oft schwarz
  "$WINE_BIN/wine" "$exe" -cef-disable-gpu -cef-disable-gpu-compositing \
    >"$LOGS/steam.log" 2>&1 &
  ok "Steam läuft. Protokoll: $LOGS/steam.log"
}

# ------------------------------------------------------------------ DXVK ---
cmd_dxvk() {
  pruefe_einrichtung
  lade_einstellungen
  case "${1:-}" in
    an|ein|on)
      local quelle="$CACHE/$DXVK_NAME"
      if [ ! -d "$quelle" ]; then
        info "Lade DXVK herunter …"
        mkdir -p "$CACHE"
        curl -fL --progress-bar "$DXVK_URL" | tar -xz -C "$CACHE" \
          || fehler "DXVK konnte nicht geladen werden."
      fi
      cp "$quelle"/x64/*.dll "$PREFIX/drive_c/windows/system32/" || fehler "Kopieren fehlgeschlagen."
      cp "$quelle"/x32/*.dll "$PREFIX/drive_c/windows/syswow64/" || fehler "Kopieren fehlgeschlagen."
      DXVK_AKTIV=1; speichere_einstellungen
      ok "DXVK aktiv: DirectX-10/11-Spiele laufen jetzt über Vulkan → Metal."
      ;;
    aus|off)
      DXVK_AKTIV=0; speichere_einstellungen
      ok "DXVK deaktiviert (Wines eigene DirectX-Umsetzung wird genutzt)."
      ;;
    *)
      [ "$DXVK_AKTIV" = 1 ] && echo "DXVK ist an." || echo "DXVK ist aus."
      echo "Ändern mit: bash windows-bridge.sh dxvk an   bzw.   dxvk aus"
      ;;
  esac
}

# --------------------------------------------------------------- Diverses ---
cmd_config()   { pruefe_einrichtung; wine_umgebung; "$WINE_BIN/winecfg" >/dev/null 2>&1 & }
cmd_laufwerk() { pruefe_einrichtung; open "$PREFIX/drive_c"; }
cmd_stop()     { wine_umgebung; "$WINE_BIN/wineserver" -k 2>/dev/null; ok "Alle Windows-Programme beendet."; }

cmd_entfernen() {
  [ -d "$BASE" ] || { ok "Nichts zu entfernen."; return 0; }
  printf 'Windows-Bridge samt Windows-Umgebung und allen darin installierten Programmen\n'
  printf 'in den Papierkorb legen? (ja/nein) '
  read -r antwort
  [ "$antwort" = "ja" ] || { info "Abgebrochen."; return 0; }
  cmd_stop >/dev/null 2>&1
  local ziel="$HOME/.Trash/Windows-Bridge-$(date +%Y%m%d-%H%M%S)"
  mv "$BASE" "$ziel"
  [ -d "$APP_PATH" ] && mv "$APP_PATH" "$HOME/.Trash/Windows-Bridge-$(date +%H%M%S).app"
  ok "In den Papierkorb gelegt. Endgültig weg erst, wenn du den Papierkorb leerst."
}

# ------------------------------------------------------------------- GUI ---
cmd_gui() {
  GUI=1
  if ! ist_eingerichtet; then
    osascript -e 'display dialog "Windows-Bridge ist noch nicht eingerichtet. Jetzt im Terminal einrichten? (Download ca. 200 MB)" buttons {"Abbrechen", "Einrichten"} default button "Einrichten" with title "Windows-Bridge"' >/dev/null 2>&1 || exit 0
    osascript -e "tell application \"Terminal\" to do script \"/bin/bash '$SELF_COPY' setup\"" -e 'tell application "Terminal" to activate' >/dev/null
    exit 0
  fi
  local wahl
  wahl="$(osascript <<'EOF'
set optionen to {"Windows-Programm starten …", "Steam starten", "DirectX-Beschleunigung (DXVK) an", "DirectX-Beschleunigung (DXVK) aus", "Laufwerk C: öffnen", "Wine-Einstellungen", "Alle Windows-Programme beenden"}
set r to choose from list optionen with title "Windows-Bridge" with prompt "Was möchtest du tun?" default items {item 1 of optionen}
if r is false then return ""
return item 1 of r
EOF
)"
  case "$wahl" in
    "Windows-Programm starten …")
      local datei
      datei="$(osascript -e 'POSIX path of (choose file with prompt "Windows-Programm (.exe, .msi, .bat) auswählen:")' 2>/dev/null)" || exit 0
      cmd_run "$datei" ;;
    "Steam starten")                       cmd_steam ;;
    "DirectX-Beschleunigung (DXVK) an")    cmd_dxvk an;  hinweis "DXVK ist jetzt an." ;;
    "DirectX-Beschleunigung (DXVK) aus")   cmd_dxvk aus; hinweis "DXVK ist jetzt aus." ;;
    "Laufwerk C: öffnen")                  cmd_laufwerk ;;
    "Wine-Einstellungen")                  cmd_config ;;
    "Alle Windows-Programme beenden")      cmd_stop ;;
  esac
}

cmd_menue() {
  echo "Windows-Bridge $VERSION – Windows-Programme auf dem Mac"
  ist_eingerichtet && echo "Status: eingerichtet" || echo "Status: noch nicht eingerichtet"
  echo
  echo "  1) Einrichten (Wine + Rosetta)"
  echo "  2) Mac-App anlegen"
  echo "  3) Windows-Programm starten"
  echo "  4) Steam installieren/starten"
  echo "  5) DXVK an/aus"
  echo "  6) Laufwerk C: öffnen"
  echo "  7) Alles beenden"
  echo "  q) Ende"
  printf 'Auswahl: '
  read -r a
  case "$a" in
    1) cmd_setup ;;
    2) cmd_app ;;
    3) printf 'Pfad zur .exe (Datei hier ins Fenster ziehen): '; read -r f
       f="${f%" "}"; f="${f//\\/}"; f="${f//\"/}"; f="${f//\'/}"
       cmd_run "$f" ;;
    4) cmd_steam ;;
    5) lade_einstellungen; [ "$DXVK_AKTIV" = 1 ] && cmd_dxvk aus || cmd_dxvk an ;;
    6) cmd_laufwerk ;;
    7) cmd_stop ;;
    *) exit 0 ;;
  esac
}

# ------------------------------------------------------------- Einstieg ---
case "${1:-}" in
  setup|einrichten)  cmd_setup ;;
  app)               cmd_app ;;
  run|start)         shift; cmd_run "${1:-}" ;;
  steam-install)     cmd_steam_install ;;
  steam)             cmd_steam ;;
  dxvk)              shift; cmd_dxvk "${1:-}" ;;
  config|winecfg)    cmd_config ;;
  laufwerk|c)        cmd_laufwerk ;;
  stop)              cmd_stop ;;
  entfernen)         cmd_entfernen ;;
  gui)               cmd_gui ;;
  gui-run)           GUI=1; shift; cmd_run "${1:-}" ;;
  -h|--help|hilfe)   sed -n '2,22p' "$0" ;;
  "")                cmd_menue ;;
  *)                 fehler "Unbekannter Befehl: $1 (Hilfe: bash windows-bridge.sh hilfe)" ;;
esac
