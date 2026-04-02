#!/usr/bin/env bash
set -euo pipefail
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 针对国内网络环境，使用镜像加速
MIRROR="https://gh-proxy.com/"
BASE_URL="${MIRROR}https://raw.githubusercontent.com/mjj0001/macosscript/main"

mkdir -p "$TMP_DIR/lib" "$TMP_DIR/scripts" "$TMP_DIR/docs"

echo "📦 下载主脚本..."
curl -fsSL --connect-timeout 10 --max-time 60 "$BASE_URL/openclaw-macos-kejilion-rebuild.sh" -o "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh" || {
  echo "⚠️ 镜像下载失败，尝试直连..."
  BASE_URL="https://raw.githubusercontent.com/mjj0001/macosscript/main"
  curl -fsSL --connect-timeout 10 --max-time 60 "$BASE_URL/openclaw-macos-kejilion-rebuild.sh" -o "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
}

echo "📦 下载 lib 模块..."
for f in common.sh core.sh api.sh memory.sh admin.sh backup.sh bot.sh plugin.sh skill.sh; do
  echo "  - $f"
  curl -fsSL --connect-timeout 10 --max-time 60 "$BASE_URL/lib/$f" -o "$TMP_DIR/lib/$f" || {
    echo "❌ 下载 $f 失败"
    echo ""
    echo "💡 备用方案（推荐）："
    echo "   git clone https://github.com/mjj0001/macosscript.git"
    echo "   cd macosscript"
    echo "   ./openclaw-macos-kejilion-rebuild.sh"
    exit 1
  }
done

chmod +x "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
echo "✅ 下载完成，启动..."
exec "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
