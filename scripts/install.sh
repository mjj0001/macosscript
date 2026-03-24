#!/usr/bin/env bash
set -euo pipefail
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsSL https://raw.githubusercontent.com/mjj0001/macosscript/main/openclaw-macos-kejilion-rebuild.sh -o "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
chmod +x "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
exec "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
