#!/usr/bin/env bash

# --- 机器人连接对接 ---
bot_pairing_menu(){
  step "机器人连接管理"
  while true; do
    clear
    cecho "======================================="
    cecho "🤖 机器人连接对接"
    cecho "======================================="
    echo
    cecho "1. 添加 Telegram Bot"
    cecho "2. 添加 Discord Bot"
    cecho "3. 添加 Slack Bot"
    cecho "4. 添加飞书 Bot"
    cecho "5. 查看已连接机器人"
    cecho "6. 断开机器人连接"
    cecho "0. 返回"
    read -r -p "请选择：" c
    case "$c" in
      1)
        read -r -p "输入 Telegram Bot Token: " token
        [[ -n "$token" ]] || { warn "Token 不能为空"; press_enter; continue; }
        python3 - "$OPENCLAW_CONFIG_FILE" "$token" <<'PY'
import json,sys
p,t=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
bots=d.setdefault('bots',{}).setdefault('telegram',{})
bots['enabled']=True
bots['token']=t
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ Telegram Bot 已添加')
PY
        restart_gateway || true
        press_enter
        ;;
      2)
        read -r -p "输入 Discord Bot Token: " token
        [[ -n "$token" ]] || { warn "Token 不能为空"; press_enter; continue; }
        python3 - "$OPENCLAW_CONFIG_FILE" "$token" <<'PY'
import json,sys
p,t=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
bots=d.setdefault('bots',{}).setdefault('discord',{})
bots['enabled']=True
bots['token']=t
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ Discord Bot 已添加')
PY
        restart_gateway || true
        press_enter
        ;;
      3)
        read -r -p "输入 Slack Bot Token: " token
        [[ -n "$token" ]] || { warn "Token 不能为空"; press_enter; continue; }
        python3 - "$OPENCLAW_CONFIG_FILE" "$token" <<'PY'
import json,sys
p,t=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
bots=d.setdefault('bots',{}).setdefault('slack',{})
bots['enabled']=True
bots['token']=t
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ Slack Bot 已添加')
PY
        restart_gateway || true
        press_enter
        ;;
      4)
        read -r -p "输入飞书 Bot Webhook URL: " url
        [[ -n "$url" ]] || { warn "URL 不能为空"; press_enter; continue; }
        python3 - "$OPENCLAW_CONFIG_FILE" "$url" <<'PY'
import json,sys
p,u=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
bots=d.setdefault('bots',{}).setdefault('feishu',{})
bots['enabled']=True
bots['webhook']=u
json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
print('✅ 飞书 Bot 已添加')
PY
        restart_gateway || true
        press_enter
        ;;
      5)
        python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except: print('无配置'); raise SystemExit(0)
bots=d.get('bots',{})
if not bots: print('未连接任何机器人')
for k,v in bots.items():
  if isinstance(v,dict) and v.get('enabled'):
    print(f'✅ {k}: 已启用')
  else:
    print(f'❌ {k}: 未启用')
PY
        press_enter
        ;;
      6)
        read -r -p "输入要断开的机器人名称 (telegram/discord/slack/feishu): " name
        [[ -n "$name" ]] || { warn "名称不能为空"; press_enter; continue; }
        python3 - "$OPENCLAW_CONFIG_FILE" "$name" <<'PY'
import json,sys
p,n=sys.argv[1:3]
d=json.load(open(p,'r',encoding='utf-8'))
bots=d.get('bots',{})
if n in bots:
  bots[n]['enabled']=False
  json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(p,'a',encoding='utf-8').write('\n')
  print(f'✅ 已断开 {n}')
else:
  print(f'❌ 未找到 {n}')
PY
        restart_gateway || true
        press_enter
        ;;
      0) return 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}
