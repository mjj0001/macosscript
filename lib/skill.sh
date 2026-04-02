#!/usr/bin/env bash

# --- 技能管理 ---
skill_manage(){
  step "技能管理"
  while true; do
    clear
    cecho "======================================="
    cecho "🎯 技能管理"
    cecho "======================================="
    echo
    cecho "1. 安装技能"
    cecho "2. 卸载技能"
    cecho "3. 启用/禁用技能"
    cecho "4. 查看已安装技能"
    cecho "5. 更新技能"
    cecho "0. 返回"
    read -r -p "请选择：" c
    case "$c" in
      1)
        read -r -p "输入技能名称或 URL: " sname
        [[ -n "$sname" ]] || { warn "名称不能为空"; press_enter; continue; }
        if command -v openclaw >/dev/null 2>&1; then
          openclaw skills install "$sname" || warn "安装失败"
        else
          warn "请确保 openclaw 已安装"
        fi
        restart_gateway || true
        press_enter
        ;;
      2)
        read -r -p "输入要卸载的技能名称: " sname
        [[ -n "$sname" ]] || { warn "名称不能为空"; press_enter; continue; }
        if command -v openclaw >/dev/null 2>&1; then
          openclaw skills uninstall "$sname" || warn "卸载失败"
        fi
        restart_gateway || true
        press_enter
        ;;
      3)
        read -r -p "输入技能名称: " sname
        [[ -n "$sname" ]] || { warn "名称不能为空"; press_enter; continue; }
        cecho "1. 启用"
        cecho "2. 禁用"
        read -r -p "请选择：" a
        python3 - "$OPENCLAW_CONFIG_FILE" "$sname" "$a" <<'PY'
import json,sys
p,name,action=sys.argv[1:4]
d=json.load(open(p,'r',encoding='utf-8'))
skills=d.setdefault('skills',{}).setdefault('installed',[])
found=False
for sk in skills:
  if isinstance(sk,dict) and sk.get('name')==name:
    sk['enabled']=(action=='1')
    found=True
    break
if not found:
  skills.append({'name':name,'enabled':(action=='1')})
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
state='启用' if action=='1' else '禁用'
print(f'✅ 技能 {name} 已{state}')
PY
        restart_gateway || true
        press_enter
        ;;
      4)
        if command -v openclaw >/dev/null 2>&1; then
          openclaw skills list || true
        else
          python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except: print('无配置'); raise SystemExit(0)
skills=d.get('skills',{}).get('installed',[])
if not skills: print('未安装任何技能')
for sk in skills:
  if isinstance(sk,dict):
    status='✅' if sk.get('enabled',True) else '❌'
    print(f"{status} {sk.get('name','unknown')}")
PY
        fi
        press_enter
        ;;
      5)
        if command -v openclaw >/dev/null 2>&1; then
          openclaw skills update || true
        else
          warn "请手动更新"
        fi
        restart_gateway || true
        press_enter
        ;;
      0) return 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
