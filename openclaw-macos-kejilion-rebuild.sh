#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/core.sh
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=lib/api.sh
source "$SCRIPT_DIR/lib/api.sh"
# shellcheck source=lib/memory.sh
source "$SCRIPT_DIR/lib/memory.sh"
# shellcheck source=lib/admin.sh
source "$SCRIPT_DIR/lib/admin.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"
# shellcheck source=lib/bot.sh
source "$SCRIPT_DIR/lib/bot.sh"
# shellcheck source=lib/plugin.sh
source "$SCRIPT_DIR/lib/plugin.sh"
# shellcheck source=lib/skill.sh
source "$SCRIPT_DIR/lib/skill.sh"
# shellcheck source=lib/logs.sh
source "$SCRIPT_DIR/lib/logs.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

# --- 启动信息头 ---
show_header(){
  local install_status="❌ 未安装"
  local run_status="❌ 未运行"
  local openclaw_version="N/A"

  if command -v openclaw >/dev/null 2>&1; then
    install_status="✅ 已安装"
    openclaw_version="$(openclaw --version 2>/dev/null || echo '未知')"
  fi
  if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
    run_status="✅ 运行中"
  fi

  clear
  cecho "╔═══════════════════════════════════════════════════════════╗"
  cecho "║  🦞 OPENCLAW macOS 管理工具                              ║"
  cecho "╠═══════════════════════════════════════════════════════════╣"
  cecho "║  脚本版本: $SCRIPT_VERSION"
  cecho "║  安装状态: $install_status"
  cecho "║  运行状态: $run_status"
  if [[ "$openclaw_version" != "N/A" ]]; then
    cecho "║  程序版本: $openclaw_version"
  fi
  cecho "╚═══════════════════════════════════════════════════════════╝"
  echo
}

show_menu(){
  show_header
  cecho "======================================="
  cecho "🦞 OPENCLAW macOS 管理工具（模块拆分版）"
  cecho "版本: $SCRIPT_VERSION"
  cecho "======================================="
  cecho "1.  环境自检"
  cecho "2.  安装"
  cecho "3.  启动"
  cecho "4.  停止"
  cecho "--------------------"
  cecho "5.  状态日志查看"
  cecho "6.  换模型"
  cecho "7.  API 管理"
  cecho "8.  机器人连接对接"
  cecho "9.  插件管理"
  cecho "10. 技能管理"
  cecho "11. 编辑主配置文件"
  cecho "12. 配置向导"
  cecho "13. 健康检测与修复"
  cecho "14. WebUI 访问与设置"
  cecho "15. TUI 命令行对话窗口"
  cecho "16. 记忆 / Memory"
  cecho "17. 权限管理"
  cecho "18. 多智能体管理"
  cecho "--------------------"
  cecho "19. 备份与还原"
  cecho "20. 更新 OpenClaw"
  cecho "21. 版本回滚"
  cecho "22. 卸载"
  cecho "23. 安装开机自启"
  cecho "24. 移除开机自启"
  cecho "25. 快捷别名设置"
cecho "26. 更新脚本自身"
cecho "27. 日志管理"
cecho "0.  退出"
  cecho "--------------------"
}

main(){
  ensure_macos
  load_brew_env
  ensure_openclaw_dirs
  ensure_openclaw_config
  first_run_setup
  while true; do
    show_menu
    read -r -p "请输入选项并回车：" choice
    case "$choice" in
      1) self_check ;;
      2) install_openclaw; press_enter ;;
      3) start_gateway; press_enter ;;
      4) stop_gateway; press_enter ;;
      5) view_logs; press_enter ;;
      6) change_model; press_enter ;;
      7) api_manage_menu ;;
      8) bot_pairing_menu ;;
      9) plugin_manage ;;
      10) skill_manage ;;
      11) edit_main_config ;;
      12) run_onboard; press_enter ;;
      13) doctor_fix ;;
      14) webui_menu ;;
      15) tui_chat ;;
      16) memory_menu ;;
      17) permission_menu ;;
      18) multiagent_menu ;;
      19) backup_restore_menu ;;
      20) update_openclaw ;;
      21) rollback_openclaw ;;
      22) uninstall_openclaw ;;
      23) install_launch_agent; press_enter ;;
      24) remove_launch_agent; press_enter ;;
      25) alias_manage_menu ;;
      26) update_script ;;
      27) log_manage_menu ;;
      0) exit 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

main "$@"
