#!/usr/bin/env bash

install_openclaw(){ ensure_macos; ensure_xcode_clt; ensure_homebrew; install_dependencies; configure_npm_registry_if_needed; step "安装 OpenClaw"; npm install -g "$OPENCLAW_NPM_PACKAGE"; detect_oc_cmd; need_cmd "$OC_CMD"; ensure_openclaw_config; $OC_CMD onboard || true; json_update_base; cecho "✅ 安装完成"; }
start_gateway(){
  step "启动 Gateway"
  detect_oc_cmd
  need_cmd "$OC_CMD"
  if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
    launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
    launchctl load "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
    cecho "✅ Gateway 已通过 launchctl 启动"
  else
    $OC_CMD gateway start 2>&1 || {
      warn "gateway start 失败，尝试手动启动..."
      $OC_CMD gateway >/dev/null 2>&1 &
      cecho "✅ Gateway 已后台启动"
    }
  fi
}
stop_gateway(){
  step "停止 Gateway"
  detect_oc_cmd
  need_cmd "$OC_CMD"
  if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
    launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
    sleep 2
    pkill -f "openclaw.*gateway" 2>/dev/null || true
    pkill -f "clawd.*gateway" 2>/dev/null || true
    cecho "✅ Gateway 已停止"
  else
    $OC_CMD gateway stop 2>/dev/null || true
    pkill -f "$OC_CMD.*gateway" 2>/dev/null || true
    cecho "✅ Gateway 已停止"
  fi
}
restart_gateway(){
  step "重启 Gateway"
  detect_oc_cmd
  need_cmd "$OC_CMD"
  if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
    launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
    sleep 1
    launchctl load "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  else
    $OC_CMD gateway stop >/dev/null 2>&1 || true
    pkill -f "$OC_CMD.*gateway" 2>/dev/null || true
    sleep 1
    $OC_CMD gateway start >/dev/null 2>&1 || {
      $OC_CMD gateway >/dev/null 2>&1 &
    }
  fi
}
view_logs(){ step "查看日志"; detect_oc_cmd; need_cmd "$OC_CMD"; $OC_CMD status || true; echo; $OC_CMD gateway status || true; echo; $OC_CMD logs || true; }
change_model(){ step "切换模型"; detect_oc_cmd; need_cmd "$OC_CMD"; cecho "当前模型列表："; $OC_CMD models list || true; read -r -p "输入要切换的模型 ID（0 返回）：" m; [[ -z "$m" || "$m" == "0" ]] && return 0; $OC_CMD models set "$m"; cecho "✅ 已切换到：$m"; }
run_onboard(){ step "运行配置向导"; detect_oc_cmd; need_cmd "$OC_CMD"; $OC_CMD onboard || true; }
doctor_fix(){ step "健康检测"; detect_oc_cmd; need_cmd "$OC_CMD"; $OC_CMD doctor --fix || true; press_enter; }
update_openclaw(){
  step "更新 OpenClaw"
  detect_oc_cmd
  # 保存当前版本到历史
  local current_version
  current_version=$($OC_CMD --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | sed 's/^v//' || echo "unknown")
  if [[ "$current_version" != "unknown" ]]; then
    if [[ ! -f "$VERSION_HISTORY_FILE" ]]; then
      echo '[]' > "$VERSION_HISTORY_FILE"
    fi
    python3 - "$VERSION_HISTORY_FILE" "$current_version" <<'PY'
import json,sys
p,v=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
from datetime import datetime
d.append({'version':v,'timestamp':datetime.now().strftime('%Y-%m-%d %H:%M:%S')})
d=d[-20:]
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
PY
    cecho "📌 已保存当前版本 $current_version 到历史记录"
  fi
  ensure_homebrew
  install_dependencies
  npm install -g "$OPENCLAW_NPM_PACKAGE"
  restart_gateway || true
  cecho "✅ 已更新 OpenClaw"
  press_enter
}
uninstall_openclaw(){ step "卸载 OpenClaw"; detect_oc_cmd; read -r -p "确认卸载输入 yes：" y; [[ "$y" == "yes" ]] || return 0; remove_launch_agent || true; $OC_CMD uninstall >/dev/null 2>&1 || true; npm uninstall -g openclaw >/dev/null 2>&1 || true; cecho "✅ 已卸载 npm 包，配置目录保留：$OPENCLAW_HOME"; press_enter; }

# --- 版本回滚 ---
rollback_openclaw(){
  step "版本回滚"
  detect_oc_cmd
  clear
  cecho "======================================="
  cecho "⏪ 版本回滚"
  cecho "======================================="
  echo

  if [[ ! -f "$VERSION_HISTORY_FILE" ]]; then
    warn "暂无版本历史记录"
    cecho "💡 更新 OpenClaw 后会自动保存版本历史"
    press_enter
    return 0
  fi

  local history_count
  history_count=$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1],'r',encoding='utf-8'))
print(len(d))
" "$VERSION_HISTORY_FILE" 2>/dev/null || echo "0")

  if [[ "$history_count" == "0" ]]; then
    warn "暂无版本历史记录"
    press_enter
    return 0
  fi

  cecho "📋 版本历史（最近 $history_count 个）："
  echo
  python3 -c "
import json,sys
d=json.load(open(sys.argv[1],'r',encoding='utf-8'))
for i,v in enumerate(d[::-1]):
    print(f\"{i+1}. {v.get('version')}  ({v.get('timestamp')})\")
" "$VERSION_HISTORY_FILE" 2>/dev/null || true
  echo
  cecho "0. 返回"
  echo

  read -r -p "选择要回滚到的版本（输入序号）：" idx
  [[ -z "$idx" || "$idx" == "0" ]] && return 0

  local target_version
  target_version=$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1],'r',encoding='utf-8'))
i=int(sys.argv[2])-1
d=d[::-1]
if 0<=i<len(d): print(d[i]['version'])
" "$VERSION_HISTORY_FILE" "$idx" 2>/dev/null || echo "")

  if [[ -z "$target_version" ]]; then
    warn "无效选项"
    press_enter
    return 0
  fi

  cecho "⚠️  将回滚到版本: $target_version"
  read -r -p "确认回滚输入 yes：" confirm
  [[ "$confirm" != "yes" ]] && { cecho "已取消"; press_enter; return 0; }

  cecho "🔄 正在回滚..."
  stop_gateway || true
  npm install -g "openclaw@$target_version" || {
    warn "npm 安装失败，版本可能不存在"
    restart_gateway || true
    press_enter
    return 0
  }
  OC_CMD=""
  detect_oc_cmd
  restart_gateway || true
  cecho "✅ 已回滚到版本: $target_version"
  press_enter
}
  # 重置命令检测（可能版本间 CLI 名称不同）
  OC_CMD=""
  detect_oc_cmd
  restart_gateway || true
  cecho "✅ 已回滚到版本: $target_version"
  press_enter
}
extract_dashboard_url(){ detect_oc_cmd; $OC_CMD dashboard 2>/dev/null | grep -Eo 'http://[^ ]+|https://[^ ]+' | head -n 1 || true; }
extract_dashboard_token(){ extract_dashboard_url | sed -n 's/.*#token=//p' | head -n 1; }
webui_add_origin(){ step "添加 WebUI origin"; read -r -p "输入 origin：" origin; [[ -n "$origin" ]] || return 0; python3 - "$OPENCLAW_CONFIG_FILE" "$origin" <<'PY'
import json,sys
p,o=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
ao=d.setdefault('gateway',{}).setdefault('controlUi',{}).setdefault('allowedOrigins',['http://127.0.0.1'])
if o not in ao: ao.append(o)
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
PY
restart_gateway || true; }
webui_remove_origin(){ step "删除 WebUI origin"; jq '.gateway.controlUi.allowedOrigins // []' "$OPENCLAW_CONFIG_FILE" 2>/dev/null || true; read -r -p "输入要移除的 origin：" origin; [[ -n "$origin" ]] || return 0; python3 - "$OPENCLAW_CONFIG_FILE" "$origin" <<'PY'
import json,sys
p,o=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
ao=d.setdefault('gateway',{}).setdefault('controlUi',{}).setdefault('allowedOrigins',[])
d['gateway']['controlUi']['allowedOrigins']=[x for x in ao if x!=o]
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
PY
restart_gateway || true; }
webui_menu(){ step "WebUI 管理"; while true; do clear; cecho "OpenClaw WebUI"; local url token; url=$(extract_dashboard_url); token=$(extract_dashboard_token); cecho "本地地址：${url:-未获取到}"; [[ -n "$token" ]] && cecho "Token：$token"; jq '.gateway.controlUi.allowedOrigins // []' "$OPENCLAW_CONFIG_FILE" 2>/dev/null || true; echo; cecho "1. 打开本地 WebUI"; cecho "2. 添加 allowedOrigins"; cecho "3. 删除 allowedOrigins"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) [[ -n "$url" ]] && open "$url" || true; press_enter;; 2) webui_add_origin; press_enter;; 3) webui_remove_origin; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
tui_chat(){ step "TUI 对话"; detect_oc_cmd; need_cmd "$OC_CMD"; $OC_CMD tui; }
install_launch_agent(){
  step "安装开机自启"
  detect_oc_cmd
  local oc_bin
  oc_bin=$(command -v "$OC_CMD" || true)
  [[ -n "$oc_bin" ]] || die "未找到 $OC_CMD 命令"
  mkdir -p "$(dirname "$LAUNCH_AGENT_PLIST")" 2>/dev/null || true
  # 清理可能存在的旧文件（权限问题）
  rm -f "$LAUNCH_AGENT_PLIST" 2>/dev/null || sudo rm -f "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
  # 写入 plist
  cat > "$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>ai.openclaw.gateway</string><key>ProgramArguments</key><array><string>$oc_bin</string><string>gateway</string><string>start</string></array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>StandardOutPath</key><string>${OPENCLAW_HOME}/logs/launchd.out.log</string><key>StandardErrorPath</key><string>${OPENCLAW_HOME}/logs/launchd.err.log</string></dict></plist>
EOF
  if [[ ! -f "$LAUNCH_AGENT_PLIST" ]]; then
    warn "写入失败，尝试使用 sudo..."
    sudo bash -c "cat > '$LAUNCH_AGENT_PLIST'" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>ai.openclaw.gateway</string><key>ProgramArguments</key><array><string>$oc_bin</string><string>gateway</string><string>start</string></array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>StandardOutPath</key><string>${OPENCLAW_HOME}/logs/launchd.out.log</string><key>StandardErrorPath</key><string>${OPENCLAW_HOME}/logs/launchd.err.log</string></dict></plist>
EOF
  fi
  launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  launchctl load "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
  cecho "✅ 已安装 launchctl 开机自启"
}
remove_launch_agent(){ step "移除开机自启"; launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true; rm -f "$LAUNCH_AGENT_PLIST"; cecho "✅ 已移除开机自启"; }

# --- 更新脚本自身 ---
update_script(){
  step "更新脚本"
  clear
  cecho "======================================="
  cecho "🔄 更新脚本"
  cecho "======================================="
  echo
  cecho "当前版本: $SCRIPT_VERSION"
  cecho "脚本路径: $SCRIPT_DIR"
  echo

  # 检查是否是 git 仓库
  if [[ -d "$SCRIPT_DIR/.git" ]]; then
    cecho "📡 正在检查更新..."
    cd "$SCRIPT_DIR"
    
    # 使用后台任务和超时机制检查远程版本
    local tmp_file="/tmp/oc_remote_ver_$$.txt"
    (git ls-remote --heads origin main 2>/dev/null | head -1 | cut -f1) > "$tmp_file" &
    local git_pid=$!
    (sleep 5; kill $git_pid 2>/dev/null) &
    local timer_pid=$!
    wait $git_pid 2>/dev/null || true
    kill $timer_pid 2>/dev/null || true
    wait $timer_pid 2>/dev/null || true
    
    local remote_version
    remote_version=$(cat "$tmp_file" 2>/dev/null || echo "")
    rm -f "$tmp_file"
    
    local local_version
    local_version=$(git rev-parse HEAD 2>/dev/null || echo "")

    if [[ -z "$remote_version" ]]; then
      warn "无法连接到 GitHub 或检查超时"
      cecho "💡 建议："
      cecho "   1. 检查网络或配置代理"
      cecho "   2. 使用一键安装命令覆盖更新（自动使用镜像）："
      cecho "      bash <(curl -fsSL https://raw.githubusercontent.com/mjj0001/macosscript/main/scripts/install.sh)"
      press_enter
      return 0
    fi

    if [[ "$remote_version" == "$local_version" ]]; then
      cecho "✅ 脚本已是最新版本！"
      press_enter
      return 0
    fi

    cecho "📦 发现新版本，正在更新..."
    git fetch origin main || {
      warn "git fetch 失败，请检查网络"
      cecho "💡 建议使用一键安装命令更新"
      press_enter
      return 0
    }
    git reset --hard origin/main
    cecho "✅ 脚本已更新到最新版本！"
    cecho "💡 建议重启脚本以应用更新"
  else
    # 非 git 仓库，尝试从 GitHub 下载
    cecho "📦 正在下载最新版..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    # 优先使用镜像
    local base_url="https://gh-proxy.com/https://raw.githubusercontent.com/mjj0001/macosscript/main"

    curl -fsSL --connect-timeout 5 --max-time 15 "$base_url/openclaw-macos-kejilion-rebuild.sh" -o "$tmp_dir/openclaw-macos-kejilion-rebuild.sh" 2>/dev/null || {
      base_url="https://raw.githubusercontent.com/mjj0001/macosscript/main"
      curl -fsSL --connect-timeout 5 --max-time 15 "$base_url/openclaw-macos-kejilion-rebuild.sh" -o "$tmp_dir/openclaw-macos-kejilion-rebuild.sh" 2>/dev/null || {
        warn "下载失败，请检查网络"
        rm -rf "$tmp_dir"
        press_enter
        return 0
      }
    }

    # 下载 lib 文件
    mkdir -p "$tmp_dir/lib"
    for f in common.sh core.sh api.sh memory.sh admin.sh backup.sh bot.sh plugin.sh skill.sh logs.sh config.sh; do
      curl -fsSL --connect-timeout 5 --max-time 15 "$base_url/lib/$f" -o "$tmp_dir/lib/$f" 2>/dev/null || true
    done

    # 复制到当前目录
    cp -f "$tmp_dir/openclaw-macos-kejilion-rebuild.sh" "$SCRIPT_DIR/openclaw-macos-kejilion-rebuild.sh"
    for f in "$tmp_dir/lib/"*.sh; do
      [[ -f "$f" ]] && cp -f "$f" "$SCRIPT_DIR/lib/"
    done
    chmod +x "$SCRIPT_DIR/openclaw-macos-kejilion-rebuild.sh"
    rm -rf "$tmp_dir"

    cecho "✅ 脚本已更新到最新版本！"
    cecho "💡 建议重启脚本以应用更新"
  fi

  press_enter
}
