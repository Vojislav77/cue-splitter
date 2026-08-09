#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_SCRIPTS="$HOME/.local/share/kio/scripts"
DEST_SERVICES="$HOME/.local/share/kio/servicemenus"

mkdir -p "$DEST_SCRIPTS" "$DEST_SERVICES"

install -m 755 "$SRC_DIR/cue-splitter.sh" "$DEST_SCRIPTS/cue-splitter.sh"

sed "s|@SCRIPT@|$DEST_SCRIPTS/cue-splitter.sh|" \
  "$SRC_DIR/cue-splitter.desktop" > "$DEST_SERVICES/cue-splitter.desktop"
# Service menus must be marked executable to be authorized in this location
chmod 755 "$DEST_SERVICES/cue-splitter.desktop"

# Refresh KDE's menu database so the entry appears
command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true

echo "Installed to:"
echo "  $DEST_SERVICES/cue-splitter.desktop"
echo "  $DEST_SCRIPTS/cue-splitter.sh"
echo ""
echo "Now fully quit Dolphin (killall dolphin) and reopen it."
echo "Right-click a .cue file -> CUE Splitter -> Split & Encode..."
