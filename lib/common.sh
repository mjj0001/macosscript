#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="OpenClaw"
SCRIPT_VERSION="v0.3.1-modular"
OPENCLAW_NPM_PACKAGE="openclaw@latest"
OPENCLAW_HOME="${HOME}/.openclaw"
OPENCLAW_CONFIG_FILE="${OPENCLAW_HOME}/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_HOME}/workspace"
BACKUP_DIR="${OPENCLAW_HOME}/backups"
LAUNCH_AGENT_PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"
LAST_ERROR_STEP="初始化"
TEST_MODE="${OPENCLAW_TEST_MODE:-0}"
SCRIPT_SETTINGS_FILE="${HOME}/.openclaw-macos-script-settings"

cecho(){ printf '%s\n' "$*"; }
warn(){ printf '⚠️ %s\n' "$*"; }
die(){ printf '❌ %s\n' "$*" >&2; exit 1; }
press_enter(){ read -r -p "按回车继续..." _; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }
step(){ LAST_ERROR_STEP="$1"; }
trap 'rc=$?; if [ $rc -ne 0 ]; then printf "\n❌ 失败步骤：%s\n" "$LAST_ERROR_STEP" >&2; printf "💡 建议先看上方报错，再决定重试哪一步。\n" >&2; fi' ERR

# --- 获取永久脚本路径 ---
get_permanent_script_path(){
  local current_dir
  current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # 判断是否在临时目录（/var/folders 或 /tmp 开头）
  if [[ "$current_dir" == /var/folders/* || "$current_dir" == /tmp/* ]]; then
    # 需要安装到永久位置
    local perm_dir="$HOME/macosscript"
    if [[ -d "$perm_dir" ]]; then
      echo "$perm_dir/openclaw-macos-kejilion-rebuild.sh"
    else
      echo ""
    fi
  else
    echo "$current_dir/openclaw-macos-kejilion-rebuild.sh"
  fi
}

# --- 首次运行设置向导 ---
first_run_setup(){
  [[ -f "$SCRIPT_SETTINGS_FILE" ]] && return 0

  clear
  cecho "╔═══════════════════════════════════════════════════════════╗"
  cecho "║  🎉 欢迎使用 OPENCLAW macOS 管理工具！                    ║"
  cecho "╠═══════════════════════════════════════════════════════════╣"
  cecho "║  首次运行，请设置一个快捷启动别名                        ║"
  cecho "║  设置后，在任意终端输入别名即可启动脚本                    ║"
  cecho "╚═══════════════════════════════════════════════════════════╝"
  echo
  cecho "💡 推荐别名示例："
  cecho "   ocm  (OpenClaw Mac 的缩写)"
  cecho "   oc   (简短好记)"
  cecho "   claw (直观)"
  echo
  read -r -p "请输入你想要的快捷别名（留空跳过）：" alias_name

  if [[ -n "$alias_name" ]]; then
    # 验证别名只包含字母、数字、下划线、连字符
    if [[ ! "$alias_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      warn "别名只能包含字母、数字、下划线(_)、连字符(-)"
      warn "已跳过设置，你之后可以手动配置"
    else
      local script_path
      script_path="$(get_permanent_script_path)"

      # 如果在临时目录运行，先安装到永久位置
      if [[ -z "$script_path" ]]; then
        cecho "📦 检测到临时运行模式，正在安装到永久位置..."
        local perm_dir="$HOME/macosscript"
        if [[ ! -d "$perm_dir" ]]; then
          mkdir -p "$perm_dir"
          local base_url="https://raw.githubusercontent.com/mjj0001/macosscript/main"
          curl -fsSL --connect-timeout 10 --max-time 60 "$base_url/openclaw-macos-kejilion-rebuild.sh" -o "$perm_dir/openclaw-macos-kejilion-rebuild.sh" 2>/dev/null || {
            curl -fsSL --connect-timeout 10 --max-time 60 "https://gh-proxy.com/$base_url/openclaw-macos-kejilion-rebuild.sh" -o "$perm_dir/openclaw-macos-kejilion-rebuild.sh" 2>/dev/null || {
              warn "下载失败，请手动 git clone"
              press_enter
              return 0
            }
          }
          mkdir -p "$perm_dir/lib"
          for f in common.sh core.sh api.sh memory.sh admin.sh backup.sh bot.sh plugin.sh skill.sh; do
            curl -fsSL --connect-timeout 10 --max-time 60 "$base_url/lib/$f" -o "$perm_dir/lib/$f" 2>/dev/null || true
          done
          chmod +x "$perm_dir/openclaw-macos-kejilion-rebuild.sh"
        fi
        script_path="$perm_dir/openclaw-macos-kejilion-rebuild.sh"
        cecho "✅ 已安装到: $perm_dir"
      fi

      local alias_line="alias ${alias_name}='${script_path}'"

      # 检查是否已存在
      if grep -q "alias ${alias_name}=" ~/.zshrc 2>/dev/null; then
        warn "别名 '${alias_name}' 已存在于 ~/.zshrc，跳过添加"
      else
        echo "" >> ~/.zshrc
        echo "# OpenClaw macOS 管理工具快捷启动" >> ~/.zshrc
        echo "$alias_line" >> ~/.zshrc
        cecho "✅ 已将 '${alias_name}' 添加到 ~/.zshrc"
        cecho "   命令: $alias_line"
        source ~/.zshrc 2>/dev/null || true
      fi

      # 保存设置
      echo "alias=${alias_name}" > "$SCRIPT_SETTINGS_FILE"
      echo "path=${script_path}" >> "$SCRIPT_SETTINGS_FILE"
      echo
      cecho "🎯 以后在任意终端输入 '${alias_name}' 即可启动！"
    fi
  else
    cecho "已跳过设置，你之后可以在脚本菜单中配置快捷别名"
  fi

  echo
  press_enter
}

# --- 快捷别名管理 ---
alias_manage_menu(){
  step "快捷别名管理"
  while true; do
    clear
    cecho "======================================="
    cecho "⌨️  快捷别名管理"
    cecho "======================================="
    if [[ -f "$SCRIPT_SETTINGS_FILE" ]]; then
      local current_alias
      current_alias=$(grep "^alias=" "$SCRIPT_SETTINGS_FILE" 2>/dev/null | cut -d= -f2)
      cecho "当前别名: ${current_alias:-未设置}"
    else
      cecho "当前别名: 未设置"
    fi
    echo
    cecho "1. 设置/修改别名"
    cecho "2. 删除别名"
    cecho "0. 返回"
    read -r -p "请选择：" c
    case "$c" in
      1)
        read -r -p "输入新别名（字母/数字/下划线/连字符）：" alias_name
        [[ -n "$alias_name" ]] || { warn "别名不能为空"; press_enter; continue; }
        if [[ ! "$alias_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
          warn "别名只能包含字母、数字、下划线(_)、连字符(-)"
          press_enter; continue
        fi
        local script_path
        script_path="$(get_permanent_script_path)"
        # 如果在临时目录，提示需要先 git clone
        if [[ -z "$script_path" ]]; then
          warn "当前在临时目录运行，请先执行以下命令安装到永久位置："
          cecho "   git clone https://github.com/mjj0001/macosscript.git ~/macosscript"
          press_enter; continue
        fi
        # 删除旧别名
        if [[ -f "$SCRIPT_SETTINGS_FILE" ]]; then
          local old_alias
          old_alias=$(grep "^alias=" "$SCRIPT_SETTINGS_FILE" 2>/dev/null | cut -d= -f2)
          if [[ -n "$old_alias" ]]; then
            sed -i '' "/alias ${old_alias}=/d" ~/.zshrc 2>/dev/null || true
            sed -i '' "/# OpenClaw macOS 管理工具快捷启动/d" ~/.zshrc 2>/dev/null || true
          fi
        fi
        # 添加新别名
        echo "" >> ~/.zshrc
        echo "# OpenClaw macOS 管理工具快捷启动" >> ~/.zshrc
        echo "alias ${alias_name}='${script_path}'" >> ~/.zshrc
        echo "alias=${alias_name}" > "$SCRIPT_SETTINGS_FILE"
        echo "path=${script_path}" >> "$SCRIPT_SETTINGS_FILE"
        source ~/.zshrc 2>/dev/null || true
        cecho "✅ 别名已设置为 '${alias_name}'"
        press_enter
        ;;
      2)
        if [[ -f "$SCRIPT_SETTINGS_FILE" ]]; then
          local old_alias
          old_alias=$(grep "^alias=" "$SCRIPT_SETTINGS_FILE" 2>/dev/null | cut -d= -f2)
          if [[ -n "$old_alias" ]]; then
            sed -i '' "/alias ${old_alias}=/d" ~/.zshrc 2>/dev/null || true
            sed -i '' "/# OpenClaw macOS 管理工具快捷启动/d" ~/.zshrc 2>/dev/null || true
            source ~/.zshrc 2>/dev/null || true
            rm -f "$SCRIPT_SETTINGS_FILE"
            cecho "✅ 已删除别名 '${old_alias}'"
          else
            warn "未设置别名"
          fi
        else
          warn "未设置别名"
        fi
        press_enter
        ;;
      0) return 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

ensure_macos(){ step "检查系统"; if [[ "$TEST_MODE" == "1" ]]; then return 0; fi; [[ "$(uname -s)" == "Darwin" ]] || die "这个脚本只支持 macOS。"; }
load_brew_env(){ [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || true; [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)" || true; }
ensure_xcode_clt(){ step "检查 Xcode CLT"; xcode-select -p >/dev/null 2>&1 || { xcode-select --install || true; die "请先安装 Xcode Command Line Tools。"; }; }
ensure_homebrew(){ step "检查 Homebrew"; command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; load_brew_env; need_cmd brew; }
install_dependencies(){ step "安装依赖"; brew update; brew install git jq node python tmux coreutils gnu-tar sqlite || true; }
configure_npm_registry_if_needed(){ step "配置 npm 镜像"; local c=""; c=$(curl -fsSL --max-time 3 ipinfo.io/country 2>/dev/null || true); [[ "$c" == "CN" || "$c" == "HK" ]] && npm config set registry https://registry.npmmirror.com || true; }
ensure_openclaw_dirs(){ step "创建目录"; mkdir -p "$OPENCLAW_HOME" "$WORKSPACE_DIR" "$BACKUP_DIR" "$OPENCLAW_HOME/logs" "$(dirname "$LAUNCH_AGENT_PLIST")"; }
ensure_openclaw_config(){ step "准备配置文件"; ensure_openclaw_dirs; [[ -f "$OPENCLAW_CONFIG_FILE" ]] || printf '{}\n' > "$OPENCLAW_CONFIG_FILE"; }

self_check(){
  step "环境自检"
  clear
  cecho "======================================="
  cecho "🔍 环境自检"
  cecho "======================================="
  cecho "脚本版本: $SCRIPT_VERSION"
  cecho "测试模式: $TEST_MODE"
  cecho "系统: $(sw_vers -productName 2>/dev/null || uname -s) $(sw_vers -productVersion 2>/dev/null || true)"
  cecho "架构: $(uname -m)"
  echo
  for cmd in bash curl python3 git; do
    if command -v "$cmd" >/dev/null 2>&1; then echo "✅ $cmd: $(command -v "$cmd")"; else echo "❌ $cmd: 未安装"; fi
  done
  if xcode-select -p >/dev/null 2>&1; then echo "✅ Xcode CLT: 已安装"; else echo "❌ Xcode CLT: 未安装"; fi
  load_brew_env
  if command -v brew >/dev/null 2>&1; then echo "✅ brew: $(command -v brew)"; else echo "❌ brew: 未安装"; fi
  if command -v node >/dev/null 2>&1; then echo "✅ node: $(node -v 2>/dev/null)"; else echo "❌ node: 未安装"; fi
  if command -v npm >/dev/null 2>&1; then echo "✅ npm: $(npm -v 2>/dev/null)"; else echo "❌ npm: 未安装"; fi
  if command -v openclaw >/dev/null 2>&1; then echo "✅ openclaw: $(command -v openclaw)"; else echo "⚠️ openclaw: 未安装"; fi
  echo
  press_enter
}

json_update_base(){
step "写基础配置"
python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except Exception:d={}
d.setdefault('tools',{})
d['tools'].setdefault('profile','full')
d['tools'].setdefault('elevated',{})
d['tools']['elevated'].setdefault('enabled',True)
d.setdefault('session',{})
d['session']['dmScope']=d['session'].get('dmScope','per-channel-peer')
d['session']['resetTriggers']=['/new','/reset']
d['session']['reset']={'mode':'idle','idleMinutes':10080}
d['session']['resetByType']={'direct':{'mode':'idle','idleMinutes':10080},'thread':{'mode':'idle','idleMinutes':1440},'group':{'mode':'idle','idleMinutes':120}}
d.setdefault('gateway',{})
d['gateway'].setdefault('controlUi',{})
d['gateway']['controlUi'].setdefault('allowedOrigins',['http://127.0.0.1'])
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
PY
}
