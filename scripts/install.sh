#!/usr/bin/env bash
set -euo pipefail
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
BASE_URL="https://raw.githubusercontent.com/mjj0001/macosscript/main"
mkdir -p "$TMP_DIR/lib" "$TMP_DIR/scripts" "$TMP_DIR/docs"
curl -fsSL "$BASE_URL/openclaw-macos-kejilion-rebuild.sh" -o "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
for f in common.sh core.sh api.sh memory.sh admin.sh backup.sh bot.sh plugin.sh skill.sh; do
  curl -fsSL "$BASE_URL/lib/$f" -o "$TMP_DIR/lib/$f" || true
done
chmod +x "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
exec "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
