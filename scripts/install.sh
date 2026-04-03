#!/usr/bin/env bash
set -euo pipefail
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# 针对国内网络环境，使用镜像加速
MIRROR="https://gh-proxy.com/"
BASE_URL="${MIRROR}https://raw.githubusercontent.com/mjj0001/macosscript/main"

mkdir -p "$TMP_DIR/lib" "$TMP_DIR/scripts" "$TMP_DIR/docs"

download_with_fallback() {
  local url="$1" output="$2" label="$3"
  curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output" 2>/dev/null || {
    echo "⚠️ $label 镜像下载失败，尝试直连..."
    local direct_url="${url#https://gh-proxy.com/}"
    curl -fsSL --connect-timeout 10 --max-time 60 "$direct_url" -o "$output" || return 1
  }
}

echo "📦 下载主脚本..."
download_with_fallback "$BASE_URL/openclaw-macos-kejilion-rebuild.sh" "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh" "主脚本" || {
  echo "❌ 下载失败，请检查网络"
  echo "💡 备用方案："
  echo "   git clone https://github.com/mjj0001/macosscript.git"
  echo "   cd macosscript"
  echo "   ./openclaw-macos-kejilion-rebuild.sh"
  exit 1
}

echo "📦 下载 lib 模块..."
FAILED_FILES=()
for f in common.sh core.sh api.sh memory.sh admin.sh backup.sh bot.sh plugin.sh skill.sh logs.sh config.sh; do
  echo "  - $f"
  if ! download_with_fallback "$BASE_URL/lib/$f" "$TMP_DIR/lib/$f" "$f"; then
    FAILED_FILES+=("$f")
  fi
done

if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
  echo ""
  echo "⚠️ 以下模块下载失败: ${FAILED_FILES[*]}"
  echo "💡 备用方案（推荐）："
  echo "   git clone https://github.com/mjj0001/macosscript.git"
  echo "   cd macosscript"
  echo "   ./openclaw-macos-kejilion-rebuild.sh"
  exit 1
fi

chmod +x "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
echo "✅ 下载完成，启动..."
exec "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
