#!/bin/bash
# Doppelklick im Finder öffnet das Windows-Bridge-Menü im Terminal.
cd "$(dirname "$0")" || exit 1
exec /bin/bash ./windows-bridge.sh "$@"
