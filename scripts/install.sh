#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$HOME/macosscript"

# 优先检查本地是否已有 git 仓库
if [[ -d "$SCRIPT_DIR/.git" ]]; then
  echo "📂 检测到本地脚本: $SCRIPT_DIR"
  cd "$SCRIPT_DIR"
  echo "🔄 正在检查更新..."
  if git fetch origin main 2>/dev/null; then
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
    REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "")
    if [[ "$LOCAL" != "$REMOTE" ]]; then
      echo "📦 发现新版本，正在更新..."
      git reset --hard origin/main
      echo "✅ 已更新到最新版本"
    else
      echo "✅ 已是最新版本"
    fi
  else
    echo "⚠️ 无法连接远程仓库，跳过更新"
  fi
  chmod +x "$SCRIPT_DIR/openclaw-macos-kejilion-rebuild.sh"
  echo "🚀 启动..."
  exec "$SCRIPT_DIR/openclaw-macos-kejilion-rebuild.sh"
fi

# 没有本地仓库，下载到临时目录
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MIRROR="https://gh-proxy.com/"
BASE_URL="${MIRROR}https://raw.githubusercontent.com/mjj0001/macosscript/main"

download_with_fallback() {
  local url="$1" output="$2" label="$3"
  curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output" 2>/dev/null || {
    echo "⚠️ $label 镜像下载失败，尝试直连..."
    local direct_url="${url#https://gh-proxy.com/}"
    curl -fsSL --connect-timeout 10 --max-time 60 "$direct_url" -o "$output" || return 1
  }
}

mkdir -p "$TMP_DIR/lib"

echo "📦 下载主脚本..."
download_with_fallback "$BASE_URL/openclaw-macos-kejilion-rebuild.sh" "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh" "主脚本" || {
  echo "❌ 下载失败，请检查网络"
  echo "💡 备用方案："
  echo "   git clone https://github.com/mjj0001/macosscript.git ~/macosscript"
  echo "   cd ~/macosscript && ./openclaw-macos-kejilion-rebuild.sh"
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
  echo "💡 建议先 git clone 到本地："
  echo "   git clone https://github.com/mjj0001/macosscript.git ~/macosscript"
  echo "   cd ~/macosscript && ./openclaw-macos-kejilion-rebuild.sh"
  exit 1
fi

chmod +x "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
echo "✅ 下载完成，启动..."
exec "$TMP_DIR/openclaw-macos-kejilion-rebuild.sh"
