#!/usr/bin/env bash
# Apply personal Neovim customizations on top of a fresh Omarchy install.
# Safe to run multiple times (idempotent).

set -euo pipefail

NVIM_DIR="${HOME}/.config/nvim"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$NVIM_DIR" ]]; then
  echo "ERROR: $NVIM_DIR does not exist. Run omarchy-nvim-setup first." >&2
  exit 1
fi

echo "Copying custom plugins..."
cp "$SCRIPT_DIR/plugins/"*.lua "$NVIM_DIR/lua/plugins/"

KEYMAP_FILE="$NVIM_DIR/lua/config/keymaps.lua"
MARKER="-- BEGIN custom keymaps"

if grep -qF "$MARKER" "$KEYMAP_FILE"; then
  echo "Custom keymaps already applied, skipping."
else
  echo "Appending custom keymaps..."
  {
    echo ""
    echo "$MARKER"
    cat "$SCRIPT_DIR/keymaps-extra.lua"
    echo "-- END custom keymaps"
  } >> "$KEYMAP_FILE"
fi

echo "Done. Restart Neovim and run :Lazy sync to install plugins."
