#!/usr/bin/env bash

# --- 插件管理 ---
plugin_manage(){
  step "插件管理"
  while true; do
    clear
    cecho "======================================="
    cecho "🧩 插件管理"
    cecho "======================================="
    echo
    cecho "1. 安装插件"
    cecho "2. 卸载插件"
    cecho "3. 启用/禁用插件"
    cecho "4. 查看已安装插件"
    cecho "5. 更新插件"
    cecho "0. 返回"
    read -r -p "请选择：" c
    case "$c" in
      1)
        read -r -p "输入插件名称或 npm 包名: " pname
        [[ -n "$pname" ]] || { warn "名称不能为空"; press_enter; continue; }
        if command -v openclaw >/dev/null 2>&1; then
          openclaw plugins install "$pname" || warn "安装失败，请检查网络或包名"
        else
          npm install -g "$pname" || warn "npm 安装失败"
        fi
        restart_gateway || true
        press_enter
        ;;
      2)
        read -r -p "输入要卸载的插件名称: " pname
        [[ -n "$pname" ]] || { warn "名称不能为空"; press_enter; continue; }
        if command -v openclaw >/dev/null 2>&1; then
          openclaw plugins uninstall "$pname" || warn "卸载失败"
        else
          npm uninstall -g "$pname" || warn "npm 卸载失败"
        fi
        restart_gateway || true
        press_enter
        ;;
      3)
        read -r -p "输入插件名称: " pname
        [[ -n "$pname" ]] || { warn "名称不能为空"; press_enter; continue; }
        cecho "1. 启用"
        cecho "2. 禁用"
        read -r -p "请选择：" a
        python3 - "$OPENCLAW_CONFIG_FILE" "$pname" "$a" <<'PY'
import json,sys
p,name,action=sys.argv[1:4]
d=json.load(open(p,'r',encoding='utf-8'))
plugins=d.setdefault('plugins',{}).setdefault('installed',[])
found=False
for pl in plugins:
  if isinstance(pl,dict) and pl.get('name')==name:
    pl['enabled']=(action=='1')
    found=True
    break
if not found:
  plugins.append({'name':name,'enabled':(action=='1')})
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
state='启用' if action=='1' else '禁用'
print(f'✅ 插件 {name} 已{state}')
PY
        restart_gateway || true
        press_enter
        ;;
      4)
        if command -v openclaw >/dev/null 2>&1; then
          openclaw plugins list || true
        else
          python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except: print('无配置'); raise SystemExit(0)
plugins=d.get('plugins',{}).get('installed',[])
if not plugins: print('未安装任何插件')
for pl in plugins:
  if isinstance(pl,dict):
    status='✅' if pl.get('enabled',True) else '❌'
    print(f"{status} {pl.get('name','unknown')}")
PY
        fi
        press_enter
        ;;
      5)
        if command -v openclaw >/dev/null 2>&1; then
          openclaw plugins update || true
        else
          warn "请手动更新 npm 包"
        fi
        restart_gateway || true
        press_enter
        ;;
      0) return 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
