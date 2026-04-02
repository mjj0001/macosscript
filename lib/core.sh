#!/usr/bin/env bash

install_openclaw(){ ensure_macos; ensure_xcode_clt; ensure_homebrew; install_dependencies; configure_npm_registry_if_needed; step "安装 OpenClaw"; npm install -g "$OPENCLAW_NPM_PACKAGE"; need_cmd openclaw; ensure_openclaw_config; openclaw onboard || true; json_update_base; cecho "✅ 安装完成"; }
start_gateway(){ step "启动 Gateway"; need_cmd openclaw; openclaw gateway stop >/dev/null 2>&1 || true; openclaw gateway start; cecho "✅ 已启动"; }
stop_gateway(){ step "停止 Gateway"; need_cmd openclaw; openclaw gateway stop || true; cecho "✅ 已停止"; }
restart_gateway(){ step "重启 Gateway"; need_cmd openclaw; openclaw gateway restart >/dev/null 2>&1 || { openclaw gateway stop >/dev/null 2>&1 || true; openclaw gateway start >/dev/null 2>&1; }; }
view_logs(){ step "查看日志"; need_cmd openclaw; openclaw status || true; echo; openclaw gateway status || true; echo; openclaw logs || true; }
change_model(){ step "切换模型"; need_cmd openclaw; cecho "当前模型列表："; openclaw models list || true; read -r -p "输入要切换的模型 ID（0 返回）：" m; [[ -z "$m" || "$m" == "0" ]] && return 0; openclaw models set "$m"; cecho "✅ 已切换到：$m"; }
run_onboard(){ step "运行配置向导"; need_cmd openclaw; openclaw onboard || true; }
doctor_fix(){ step "健康检测"; need_cmd openclaw; openclaw doctor --fix || true; press_enter; }
update_openclaw(){ step "更新 OpenClaw"; ensure_homebrew; install_dependencies; npm install -g "$OPENCLAW_NPM_PACKAGE"; restart_gateway || true; cecho "✅ 已更新 OpenClaw"; press_enter; }
uninstall_openclaw(){ step "卸载 OpenClaw"; read -r -p "确认卸载输入 yes：" y; [[ "$y" == "yes" ]] || return 0; remove_launch_agent || true; openclaw uninstall >/dev/null 2>&1 || true; npm uninstall -g openclaw || true; cecho "✅ 已卸载 npm 包，配置目录保留：$OPENCLAW_HOME"; press_enter; }
extract_dashboard_url(){ openclaw dashboard 2>/dev/null | grep -Eo 'http://[^ ]+|https://[^ ]+' | head -n 1 || true; }
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
tui_chat(){ step "TUI 对话"; need_cmd openclaw; openclaw tui; }
install_launch_agent(){
  step "安装开机自启"
  local oc_bin
  oc_bin=$(command -v openclaw || true)
  [[ -n "$oc_bin" ]] || die "未找到 openclaw 命令"
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
    local remote_version
    remote_version=$(git ls-remote --heads origin main 2>/dev/null | head -1 | cut -f1)
    local local_version
    local_version=$(git rev-parse HEAD 2>/dev/null)

    if [[ -z "$remote_version" ]]; then
      warn "无法连接到 GitHub，请检查网络"
      press_enter
      return 0
    fi

    if [[ "$remote_version" == "$local_version" ]]; then
      cecho "✅ 脚本已是最新版本！"
      press_enter
      return 0
    fi

    cecho "📦 发现新版本，正在更新..."
    git fetch origin main
    git reset --hard origin/main
    cecho "✅ 脚本已更新到最新版本！"
    cecho "💡 建议重启脚本以应用更新"
  else
    # 非 git 仓库，尝试从 GitHub 下载
    cecho "📦 正在从 GitHub 下载最新版..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local base_url="https://raw.githubusercontent.com/mjj0001/macosscript/main"

    # 尝试镜像
    curl -fsSL --connect-timeout 10 --max-time 30 "$base_url/openclaw-macos-kejilion-rebuild.sh" -o "$tmp_dir/openclaw-macos-kejilion-rebuild.sh" 2>/dev/null || {
      curl -fsSL --connect-timeout 10 --max-time 30 "https://gh-proxy.com/$base_url/openclaw-macos-kejilion-rebuild.sh" -o "$tmp_dir/openclaw-macos-kejilion-rebuild.sh" 2>/dev/null || {
        warn "下载失败，请检查网络或手动 git clone"
        rm -rf "$tmp_dir"
        press_enter
        return 0
      }
    }

    # 下载 lib 文件
    mkdir -p "$tmp_dir/lib"
    for f in common.sh core.sh api.sh memory.sh admin.sh backup.sh bot.sh plugin.sh skill.sh; do
      curl -fsSL --connect-timeout 10 --max-time 30 "$base_url/lib/$f" -o "$tmp_dir/lib/$f" 2>/dev/null || true
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
