#!/usr/bin/env bash

# --- 配置管理 ---

# 配置模板
config_templates(){
  step "加载配置模板"
  local template="$1"
  case "$template" in
    dev)
      python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except:d={}
d.setdefault('tools',{})['profile']='full'
d['tools'].setdefault('elevated',{})['enabled']=True
d.setdefault('session',{})['dmScope']='per-channel-peer'
d['session'].setdefault('reset',{'mode':'idle','idleMinutes':1440})
d.setdefault('gateway',{}).setdefault('controlUi',{}).setdefault('allowedOrigins',['http://127.0.0.1'])
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ 已应用开发模式配置（完全权限，宽松限制）')
PY
      ;;
    prod)
      python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except:d={}
d.setdefault('tools',{})['profile']='coding'
d['tools'].setdefault('elevated',{})['enabled']=False
d.setdefault('session',{})['dmScope']='per-channel-peer'
d['session'].setdefault('reset',{'mode':'idle','idleMinutes':120})
d.setdefault('gateway',{}).setdefault('controlUi',{}).setdefault('allowedOrigins',['http://127.0.0.1'])
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ 已应用生产模式配置（安全限制，严格权限）')
PY
      ;;
    test)
      python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except:d={}
d.setdefault('tools',{})['profile']='full'
d['tools'].setdefault('elevated',{})['enabled']=True
d.setdefault('session',{})['dmScope']='per-channel-peer'
d['session'].setdefault('reset',{'mode':'idle','idleMinutes':60})
d.setdefault('gateway',{}).setdefault('controlUi',{}).setdefault('allowedOrigins',['http://127.0.0.1','http://localhost'])
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ 已应用测试模式配置（完全权限，短超时）')
PY
      ;;
    *)
      warn "未知模板: $template"
      return 1
      ;;
  esac
  restart_gateway || true
}

# 配置导出
config_export(){
  step "导出配置"
  [[ -f "$OPENCLAW_CONFIG_FILE" ]] || { warn "配置文件不存在"; return 0; }
  local export_file="$BACKUP_DIR/config-export-$(date +%Y%m%d-%H%M%S).json"
  cp -f "$OPENCLAW_CONFIG_FILE" "$export_file"
  cecho "✅ 配置已导出到: $export_file"
}

# 配置导入
config_import(){
  step "导入配置"
  cecho "可用的导入文件:"
  ls -1 "$BACKUP_DIR"/config-export-*.json 2>/dev/null || echo "无可用文件"
  echo
  read -r -p "输入要导入的文件路径（留空手动输入）：" import_file
  if [[ -z "$import_file" ]]; then
    read -r -p "输入完整路径: " import_file
  fi
  [[ -f "$import_file" ]] || { warn "文件不存在"; press_enter; return 0; }
  # 先备份当前配置
  cp -f "$OPENCLAW_CONFIG_FILE" "$BACKUP_DIR/config-pre-import-$(date +%Y%m%d-%H%M%S).json"
  cp -f "$import_file" "$OPENCLAW_CONFIG_FILE"
  cecho "✅ 配置已导入，重启 Gateway 生效"
  restart_gateway || true
}

# 配置对比
config_diff(){
  step "配置对比"
  [[ -f "$OPENCLAW_CONFIG_FILE" ]] || { warn "当前配置文件不存在"; return 0; }
  local backups
  backups=$(ls -1t "$BACKUP_DIR"/config-*.json 2>/dev/null | head -5)
  if [[ -z "$backups" ]]; then
    warn "没有可用的备份文件进行对比"
    press_enter
    return 0
  fi
  cecho "可用的备份文件:"
  echo "$backups" | nl
  echo
  read -r -p "输入要对比的备份文件序号: " num
  local target
  target=$(echo "$backups" | sed -n "${num}p")
  [[ -n "$target" && -f "$target" ]] || { warn "无效选择"; press_enter; return 0; }
  cecho "=== 配置差异 ==="
  diff <(python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True,indent=2))" "$OPENCLAW_CONFIG_FILE" 2>/dev/null) \
       <(python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1])),sort_keys=True,indent=2))" "$target" 2>/dev/null) || true
  echo
  cecho "=== 结束 ==="
  press_enter
}

# 配置管理菜单
config_manage_menu(){
  step "配置管理"
  while true; do
    clear
    cecho "======================================="
    cecho "⚙️  配置管理"
    cecho "======================================="
    echo
    cecho "📋 配置模板"
    cecho "1. 开发模式（完全权限）"
    cecho "2. 生产模式（安全限制）"
    cecho "3. 测试模式（完全权限+短超时）"
    echo
    cecho "📦 导入/导出"
    cecho "4. 导出当前配置"
    cecho "5. 导入配置"
    cecho "6. 对比配置差异"
    echo
    cecho "0. 返回"
    read -r -p "请选择：" c
    case "$c" in
      1) config_templates dev; press_enter ;;
      2) config_templates prod; press_enter ;;
      3) config_templates test; press_enter ;;
      4) config_export; press_enter ;;
      5) config_import; press_enter ;;
      6) config_diff; press_enter ;;
      0) return 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
