#!/bin/bash
# Windows-Bridge – Installer
# Benutzung:  curl -fsSL https://raw.githubusercontent.com/Solilus/Windows-Bridge/main/install.sh | bash
set -euo pipefail

[ "$(uname -s)" = "Darwin" ] || { echo "Windows-Bridge läuft nur auf macOS." >&2; exit 1; }

ZIEL="$HOME/Library/Application Support/Windows-Bridge"
URL="https://raw.githubusercontent.com/Solilus/Windows-Bridge/main/windows-bridge.sh"

mkdir -p "$ZIEL"
echo "==> Lade Windows-Bridge herunter …"
curl -fsSL -o "$ZIEL/windows-bridge.sh" "$URL"
chmod +x "$ZIEL/windows-bridge.sh"

# Befehl 'windows-bridge' im Terminal verfügbar machen (ohne Admin-Rechte)
mkdir -p "$HOME/.local/bin"
ln -sf "$ZIEL/windows-bridge.sh" "$HOME/.local/bin/windows-bridge"
if ! grep -qs '.local/bin' "$HOME/.zshrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

/bin/bash "$ZIEL/windows-bridge.sh" setup </dev/tty
/bin/bash "$ZIEL/windows-bridge.sh" app

echo
echo "Fertig! Öffne 'Windows-Bridge' in deinem Programme-Ordner (~/Applications)"
echo "oder tippe in einem neuen Terminal-Fenster: windows-bridge"
