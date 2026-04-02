#!/usr/bin/env bash

# --- 日志管理 ---
log_cleanup(){
  step "清理旧日志"
  local log_dir="$OPENCLAW_HOME/logs"
  [[ -d "$log_dir" ]] || { warn "日志目录不存在"; return 0; }
  local count
  count=$(find "$log_dir" -type f -mtime +7 | wc -l | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then
    cecho "✅ 没有超过 7 天的旧日志"
  else
    find "$log_dir" -type f -mtime +7 -delete
    cecho "✅ 已清理 $count 个超过 7 天的日志文件"
  fi
}

log_rotate(){
  step "日志轮转"
  local log_dir="$OPENCLAW_HOME/logs"
  [[ -d "$log_dir" ]] || { warn "日志目录不存在"; return 0; }
  local rotated=0
  for f in "$log_dir"/*.log; do
    [[ -f "$f" ]] || continue
    local size
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
    if [[ "$size" -gt 10485760 ]]; then
      mv -f "$f" "${f}.$(date +%Y%m%d-%H%M%S)"
      touch "$f"
      rotated=$((rotated + 1))
    fi
  done
  [[ "$rotated" -gt 0 ]] && cecho "🔄 已轮转 $rotated 个日志文件" || cecho "✅ 无需轮转"
}

log_manage_menu(){
  step "日志管理"
  while true; do
    clear
    cecho "======================================="
    cecho "📜 日志管理"
    cecho "======================================="
    cecho "1. 清理 7 天前的旧日志"
    cecho "2. 执行日志轮转（>10MB 自动切割）"
    cecho "3. 查看日志目录占用"
    cecho "0. 返回"
    read -r -p "请选择：" c
    case "$c" in
      1) log_cleanup; press_enter ;;
      2) log_rotate; press_enter ;;
      3) du -sh "$OPENCLAW_HOME/logs" 2>/dev/null || echo "日志目录不存在"; press_enter ;;
      0) return 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
