#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="OpenClaw"
SCRIPT_VERSION="v0.2.0-stable"
OPENCLAW_NPM_PACKAGE="openclaw@latest"
OPENCLAW_HOME="${HOME}/.openclaw"
OPENCLAW_CONFIG_FILE="${OPENCLAW_HOME}/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_HOME}/workspace"
BACKUP_DIR="${OPENCLAW_HOME}/backups"
LAUNCH_AGENT_PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"
LAST_ERROR_STEP="初始化"

cecho(){ printf '%s\n' "$*"; }
warn(){ printf '⚠️ %s\n' "$*"; }
die(){ printf '❌ %s\n' "$*" >&2; exit 1; }
press_enter(){ read -r -p "按回车继续..." _; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"; }
step(){ LAST_ERROR_STEP="$1"; }
trap 'rc=$?; if [ $rc -ne 0 ]; then printf "\n❌ 失败步骤：%s\n" "$LAST_ERROR_STEP" >&2; printf "💡 建议先看上方报错，再决定重试哪一步。\n" >&2; fi' ERR

ensure_macos(){ step "检查系统"; [[ "$(uname -s)" == "Darwin" ]] || die "这个脚本只支持 macOS。"; }
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
  cecho "系统: $(sw_vers -productName 2>/dev/null || echo macOS) $(sw_vers -productVersion 2>/dev/null || true)"
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

install_openclaw(){ ensure_macos; ensure_xcode_clt; ensure_homebrew; install_dependencies; configure_npm_registry_if_needed; step "安装 OpenClaw"; npm install -g "$OPENCLAW_NPM_PACKAGE"; need_cmd openclaw; ensure_openclaw_config; openclaw onboard || true; json_update_base; cecho "✅ 安装完成"; }
start_gateway(){ step "启动 Gateway"; need_cmd openclaw; openclaw gateway stop >/dev/null 2>&1 || true; openclaw gateway start; cecho "✅ 已启动"; }
stop_gateway(){ step "停止 Gateway"; need_cmd openclaw; openclaw gateway stop || true; cecho "✅ 已停止"; }
restart_gateway(){ step "重启 Gateway"; need_cmd openclaw; openclaw gateway restart >/dev/null 2>&1 || { openclaw gateway stop >/dev/null 2>&1 || true; openclaw gateway start >/dev/null 2>&1; }; }
view_logs(){ step "查看日志"; need_cmd openclaw; openclaw status || true; echo; openclaw gateway status || true; echo; openclaw logs || true; }
change_model(){ step "切换模型"; need_cmd openclaw; cecho "当前模型列表："; openclaw models list || true; read -r -p "输入要切换的模型 ID（0 返回）：" m; [[ -z "$m" || "$m" == "0" ]] && return 0; openclaw models set "$m"; cecho "✅ 已切换到：$m"; }
provider_health_check(){ step "检查 provider 连通性"; local name="$1"; python3 - "$OPENCLAW_CONFIG_FILE" "$name" <<'PY'
import json,sys,urllib.request
path,name=sys.argv[1:3]
d=json.load(open(path,'r',encoding='utf-8'))
pr=((d.get('models') or {}).get('providers') or {}).get(name)
if not isinstance(pr,dict): print('❌ provider 不存在'); raise SystemExit(2)
base=pr.get('baseUrl'); key=pr.get('apiKey')
if not base or not key: print('❌ provider 缺少 baseUrl/apiKey'); raise SystemExit(3)
req=urllib.request.Request(base.rstrip('/')+'/models',headers={'Authorization':f'Bearer {key}','User-Agent':'Mozilla/5.0'})
with urllib.request.urlopen(req,timeout=8) as resp: resp.read(1024)
print('✅ /models 可访问')
PY
}
provider_add_interactive(){ step "添加 provider"; local provider_name base_url api_key models_json available_models default_model input_model confirm; read -r -p "请输入 Provider 名称: " provider_name; [[ -n "$provider_name" ]] || { warn "Provider 名称不能为空"; return 1; }; read -r -p "请输入 Base URL (如 https://api.xxx.com/v1): " base_url; [[ -n "$base_url" ]] || { warn "Base URL 不能为空"; return 1; }; base_url="${base_url%/}"; read -r -s -p "请输入 API Key: " api_key; echo; [[ -n "$api_key" ]] || { warn "API Key 不能为空"; return 1; }; cecho "🔍 正在获取可用模型列表..."; models_json=$(curl -s -m 10 -H "Authorization: Bearer $api_key" "${base_url}/models" || true); available_models=$(python3 -c 'import sys,json; raw=sys.stdin.read().strip();
import json
try:
 d=json.loads(raw); arr=d.get("data",[]) if isinstance(d,dict) else []; print("\n".join(sorted(str(x.get("id")) for x in arr if isinstance(x,dict) and x.get("id"))))
except Exception:
 pass' <<< "$models_json"); [[ -z "$available_models" ]] && warn "未拉到模型列表，后续只能手动写默认模型"; [[ -n "$available_models" ]] && { cecho "✅ 发现模型："; nl -w2 -s'. ' <<< "$available_models"; }; read -r -p "请输入默认 Model ID 或序号（留空默认第一个）: " input_model; if [[ -z "$input_model" && -n "$available_models" ]]; then default_model=$(printf '%s\n' "$available_models" | head -n1); elif [[ "$input_model" =~ ^[0-9]+$ ]]; then default_model=$(printf '%s\n' "$available_models" | sed -n "${input_model}p"); else default_model="$input_model"; fi; [[ -n "$default_model" ]] || { warn "默认模型不能为空"; return 1; }; read -r -p "是否写入全部可用模型？(y/N): " confirm; python3 - "$OPENCLAW_CONFIG_FILE" "$provider_name" "$base_url" "$api_key" "$default_model" "$available_models" "$confirm" <<'PY'
import json,sys
path,name,url,key,default_model,available,confirm=sys.argv[1:8]
try:d=json.load(open(path,'r',encoding='utf-8'))
except Exception:d={}
providers=d.setdefault('models',{}).setdefault('providers',{})
models=[]
ids=[x for x in available.splitlines() if x.strip()]
if confirm.lower().startswith('y') and ids:
    for mid in ids:
        models.append({'id':mid,'name':f'{name} / {mid}','input':['text','image'],'contextWindow':1048576,'maxTokens':128000,'cost':{'input':0.15,'output':0.60,'cacheRead':0,'cacheWrite':0}})
else:
    models=[{'id':default_model,'name':f'{name} / {default_model}','input':['text','image'],'contextWindow':1048576,'maxTokens':128000,'cost':{'input':0.15,'output':0.60,'cacheRead':0,'cacheWrite':0}}]
providers[name]={'baseUrl':url,'apiKey':key,'api':'openai-completions','models':models}
defs=d.setdefault('agents',{}).setdefault('defaults',{})
defs_models=defs.get('models') if isinstance(defs.get('models'),dict) else {}
defs['models']=defs_models
for m in models: defs_models.setdefault(f"{name}/{m['id']}",{})
json.dump(d,open(path,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(path,'a',encoding='utf-8').write('\n')
PY
openclaw models set "$provider_name/$default_model" || warn "默认模型设置失败，请稍后手动设置"; restart_gateway || true; cecho "✅ API 已添加"; }
provider_list(){ step "列出 provider"; python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
p=sys.argv[1]
try:d=json.load(open(p,'r',encoding='utf-8'))
except Exception as e: print(f'❌ 读取配置失败: {e}'); raise SystemExit(0)
providers=((d.get('models') or {}).get('providers') or {})
if not providers: print('ℹ️ 当前未配置任何 API provider。'); raise SystemExit(0)
print('--- 已配置 API 列表 ---')
for i,name in enumerate(sorted(providers),1):
 pr=providers.get(name) or {}
 base=pr.get('baseUrl') or '-'
 api=pr.get('api') or '-'
 models=pr.get('models') if isinstance(pr.get('models'),list) else []
 mc=sum(1 for m in models if isinstance(m,dict) and m.get('id'))
 print(f'[{i}] {name} | API: {base} | 协议: {api} | 模型数量: {mc}')
PY
}
provider_sync(){ step "同步 provider 模型"; read -r -p "请输入要同步的 provider 名称: " name; [[ -n "$name" ]] || { warn "provider 名称不能为空"; return 1; }; provider_health_check "$name"; python3 - "$OPENCLAW_CONFIG_FILE" "$name" <<'PY'
import json,sys,urllib.request
path,name=sys.argv[1],sys.argv[2]
d=json.load(open(path,'r',encoding='utf-8'))
providers=((d.get('models') or {}).get('providers') or {})
pr=providers.get(name)
if not isinstance(pr,dict): print('❌ provider 不存在'); raise SystemExit(2)
base=pr.get('baseUrl'); key=pr.get('apiKey')
if not base or not key: print('❌ provider 缺少 baseUrl/apiKey'); raise SystemExit(3)
req=urllib.request.Request(base.rstrip('/')+'/models',headers={'Authorization':f'Bearer {key}','User-Agent':'Mozilla/5.0'})
with urllib.request.urlopen(req,timeout=12) as resp: raw=resp.read().decode('utf-8','ignore')
obj=json.loads(raw)
ids=[str(x.get('id')) for x in obj.get('data',[]) if isinstance(x,dict) and x.get('id')]
if not ids: print('❌ 上游模型为空'); raise SystemExit(4)
tpl={'input':['text','image'],'contextWindow':1048576,'maxTokens':128000,'cost':{'input':0.15,'output':0.60,'cacheRead':0,'cacheWrite':0}}
pr['models']=[dict(tpl, id=mid, name=f'{name} / {mid}') for mid in ids]
defs=d.setdefault('agents',{}).setdefault('defaults',{})
defs_models=defs.get('models') if isinstance(defs.get('models'),dict) else {}
defs['models']=defs_models
for k in list(defs_models.keys()):
 if isinstance(k,str) and k.startswith(name+'/') and k not in {f'{name}/{x}' for x in ids}: defs_models.pop(k,None)
for mid in ids: defs_models.setdefault(f'{name}/{mid}',{})
json.dump(d,open(path,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(path,'a',encoding='utf-8').write('\n')
print(f'✅ {name}: 当前 {len(ids)} 个模型')
PY
restart_gateway || true; }
provider_switch_protocol(){ step "切换 provider 协议"; read -r -p "请输入 provider 名称: " name; [[ -n "$name" ]] || return 1; cecho "1. openai-completions"; cecho "2. openai-responses"; read -r -p "请选择：" c; local api=""; [[ "$c" == "1" ]] && api="openai-completions"; [[ "$c" == "2" ]] && api="openai-responses"; [[ -n "$api" ]] || { warn "无效选择"; return 1; }; python3 - "$OPENCLAW_CONFIG_FILE" "$name" "$api" <<'PY'
import json,sys
path,name,api=sys.argv[1:4]
d=json.load(open(path,'r',encoding='utf-8'))
pr=((d.get('models') or {}).get('providers') or {}).get(name)
if not isinstance(pr,dict): print('❌ provider 不存在'); raise SystemExit(2)
pr['api']=api
json.dump(d,open(path,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(path,'a',encoding='utf-8').write('\n')
print(f'✅ 已更新 {name} 协议为 {api}')
PY
restart_gateway || true; }
provider_delete(){ step "删除 provider"; read -r -p "请输入要删除的 provider 名称: " name; [[ -n "$name" ]] || return 1; read -r -p "输入 DELETE 确认删除：" y; [[ "$y" == "DELETE" ]] || { warn "已取消"; return 0; }; python3 - "$OPENCLAW_CONFIG_FILE" "$name" <<'PY'
import json,sys
path,name=sys.argv[1:3]
d=json.load(open(path,'r',encoding='utf-8'))
providers=((d.get('models') or {}).get('providers') or {})
if name not in providers: print('❌ provider 不存在'); raise SystemExit(2)
providers.pop(name,None)
defs=d.setdefault('agents',{}).setdefault('defaults',{})
defs_models=defs.get('models') if isinstance(defs.get('models'),dict) else {}
defs['models']=defs_models
for k in list(defs_models.keys()):
 if isinstance(k,str) and k.startswith(name+'/'): defs_models.pop(k,None)
json.dump(d,open(path,'w',encoding='utf-8'),ensure_ascii=False,indent=2); open(path,'a',encoding='utf-8').write('\n')
print(f'✅ 已删除 provider: {name}')
PY
restart_gateway || true; }
provider_showcase(){ cat <<'EOF'
🌟 API 厂商推荐
- DeepSeek: https://api-docs.deepseek.com/
- OpenRouter: https://openrouter.ai/
- Kimi: https://platform.moonshot.cn/docs/guide/start-using-kimi-api
- 硅基流动: https://cloud.siliconflow.cn/
- 智谱 GLM: https://www.bigmodel.cn/
- MiniMax: https://www.minimaxi.com/
- NVIDIA: https://build.nvidia.com/settings/api-keys
- Ollama: https://ollama.com/
EOF
}
api_manage_menu(){ while true; do clear; cecho "OpenClaw API 管理"; provider_list; echo; cecho "1. 添加API"; cecho "2. 同步API供应商模型列表"; cecho "3. 切换 API 类型"; cecho "4. 删除API"; cecho "5. 检查 API 连通性"; cecho "6. API 厂商推荐"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) provider_add_interactive; press_enter;; 2) provider_sync; press_enter;; 3) provider_switch_protocol; press_enter;; 4) provider_delete; press_enter;; 5) read -r -p "输入 provider 名称：" name; [[ -n "$name" ]] && provider_health_check "$name"; press_enter;; 6) provider_showcase; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
bot_pairing_menu(){ step "机器人连接管理"; while true; do clear; cecho "机器人连接对接"; cecho "1. Telegram 配对"; cecho "2. WhatsApp 配对"; cecho "3. 飞书/Lark 插件安装"; cecho "4. 微信插件安装"; cecho "5. 查看本地连接状态"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) read -r -p "输入 Telegram 连接码：" code; [[ -n "$code" ]] && openclaw pairing approve telegram "$code"; press_enter;; 2) read -r -p "输入 WhatsApp 连接码：" code; [[ -n "$code" ]] && openclaw pairing approve whatsapp "$code"; press_enter;; 3) npx -y @larksuite/openclaw-lark install || true; openclaw config set channels.feishu.streaming true || true; openclaw config set channels.feishu.requireMention true --json || true; press_enter;; 4) npx -y @tencent-weixin/openclaw-weixin-cli@latest install || true; press_enter;; 5) for d in telegram feishu whatsapp discord slack qqbot weixin; do [[ -d "$OPENCLAW_HOME/$d" ]] && echo "- $d: 已存在本地目录" || echo "- $d: 未发现"; done; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
plugin_manage(){ step "插件管理"; while true; do clear; cecho "插件管理"; openclaw plugins list || true; echo; cecho "1. 安装插件"; cecho "2. 启用插件"; cecho "3. 禁用插件"; cecho "4. 卸载插件"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) read -r -p "输入插件名：" p; [[ -n "$p" ]] && openclaw plugins install "$p"; restart_gateway || true; press_enter;; 2) read -r -p "输入插件 ID：" p; [[ -n "$p" ]] && openclaw plugins enable "$p"; restart_gateway || true; press_enter;; 3) read -r -p "输入插件 ID：" p; [[ -n "$p" ]] && openclaw plugins disable "$p"; restart_gateway || true; press_enter;; 4) read -r -p "输入插件 ID：" p; [[ -n "$p" ]] && openclaw plugins uninstall "$p"; restart_gateway || true; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
skill_manage(){ step "技能管理"; while true; do clear; cecho "技能管理"; openclaw skills list || true; echo; cecho "1. 安装技能"; cecho "2. 卸载技能"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) read -r -p "输入技能名：" s; [[ -n "$s" ]] && npx clawhub install "$s" --yes; restart_gateway || true; press_enter;; 2) read -r -p "输入技能名：" s; [[ -n "$s" ]] && npx clawhub uninstall "$s" --yes; restart_gateway || true; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
edit_main_config(){ step "编辑配置文件"; ensure_openclaw_config; command -v nano >/dev/null 2>&1 && nano "$OPENCLAW_CONFIG_FILE" || open "$OPENCLAW_CONFIG_FILE"; restart_gateway || true; }
run_onboard(){ step "运行配置向导"; need_cmd openclaw; openclaw onboard || true; }
doctor_fix(){ step "健康检测"; need_cmd openclaw; openclaw doctor --fix || true; press_enter; }
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
memory_status(){ step "查看 Memory 状态"; openclaw memory status 2>/dev/null || echo "未安装/未初始化"; }
memory_backend(){ python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
try:d=json.load(open(sys.argv[1],'r',encoding='utf-8'))
except Exception: print('未配置'); raise SystemExit(0)
backend=((d.get('memory') or {}).get('backend')) or '未配置'
print('Local' if backend in ('local','builtin') else backend)
PY
}
memory_scheme_apply(){ step "切换 Memory 方案"; local s="$1"; if [[ "$s" == "qmd" ]]; then openclaw config set memory.backend qmd || true; openclaw config set memory.qmd.command qmd || true; else openclaw config set memory.backend builtin || true; openclaw config set agents.defaults.memorySearch.provider local || true; fi; }
memory_setup_local(){ step "准备本地 embedding 模型"; mkdir -p "$OPENCLAW_HOME/models/embedding"; local model="$OPENCLAW_HOME/models/embedding/embeddinggemma-300M-Q8_0.gguf"; if [[ ! -f "$model" ]]; then curl -L --fail --retry 2 -o "$model" "https://huggingface.co/ggml-org/embeddinggemma-300M-GGUF/resolve/main/embeddinggemma-300M-Q8_0.gguf" || warn "模型下载失败，你之后可手动补"; fi; openclaw config set agents.defaults.memorySearch.local.modelPath "$model" || true; }
memory_auto_setup(){ step "自动推荐 Memory 方案"; cecho "自动推荐逻辑：网络受限优先 QMD，否则优先 Local"; local scheme="local"; curl -I -m 2 -s https://huggingface.co >/dev/null 2>&1 || scheme="qmd"; cecho "推荐方案：$scheme"; read -r -p "输入 yes 确认部署：" y; [[ "$y" == "yes" ]] || return 0; if [[ "$scheme" == "qmd" ]]; then npm install -g @tobilu/qmd || true; memory_scheme_apply qmd; else memory_scheme_apply local; memory_setup_local; fi; openclaw memory index --force || true; restart_gateway || true; }
memory_fix_index(){ step "修复 Memory 索引"; cecho "1. 修复当前默认索引"; cecho "2. 全量重建索引"; read -r -p "请选择：" c; case "$c" in 1) openclaw memory index || true;; 2) openclaw memory index --force || true;; *) warn "无效选择"; return 1;; esac; restart_gateway || true; }
memory_view_files(){ step "查看 Memory 文件"; mkdir -p "$WORKSPACE_DIR/memory"; find "$WORKSPACE_DIR" -maxdepth 2 \( -name 'MEMORY.md' -o -path '*/memory/*.md' \) -print | sort || true; }
memory_scheme_menu(){ step "Memory 方案菜单"; while true; do clear; cecho "OpenClaw 记忆方案"; cecho "当前方案: $(memory_backend)"; cecho "1. 切换 QMD"; cecho "2. 切换 Local"; cecho "3. Auto（自动推荐并部署）"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) npm install -g @tobilu/qmd || true; memory_scheme_apply qmd; restart_gateway || true; press_enter;; 2) memory_scheme_apply local; memory_setup_local; restart_gateway || true; press_enter;; 3) memory_auto_setup; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
memory_menu(){ step "Memory 管理"; while true; do clear; cecho "OpenClaw 记忆管理"; memory_status; echo; cecho "1. 更新记忆索引"; cecho "2. 查看记忆文件"; cecho "3. 索引修复"; cecho "4. 记忆方案（QMD/Local/Auto）"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) openclaw memory index || true; press_enter;; 2) memory_view_files; press_enter;; 3) memory_fix_index; press_enter;; 4) memory_scheme_menu;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
permission_backup_file(){ echo "$BACKUP_DIR/openclaw-permission-last.json"; }
permission_backup_current(){ step "备份权限配置"; cp -f "$OPENCLAW_CONFIG_FILE" "$(permission_backup_file)" 2>/dev/null || true; }
permission_restore_backup(){ step "恢复权限配置"; [[ -f "$(permission_backup_file)" ]] && cp -f "$(permission_backup_file)" "$OPENCLAW_CONFIG_FILE" && restart_gateway; }
permission_render_status(){ step "查看权限状态"; python3 - "$OPENCLAW_CONFIG_FILE" <<'PY'
import json,sys
try:d=json.load(open(sys.argv[1],'r',encoding='utf-8'))
except Exception as e: print(f'❌ 配置解析失败: {e}'); raise SystemExit(0)
def g(path):
 cur=d
 for p in path.split('.'):
  if isinstance(cur,dict) and p in cur: cur=cur[p]
  else: return '(unset)'
 return cur
for k in ['tools.profile','tools.exec.security','tools.exec.ask','tools.elevated.enabled','commands.bash','tools.exec.applyPatch.enabled','tools.exec.applyPatch.workspaceOnly']:
 print(f'{k}: {g(k)}')
PY
}
permission_apply(){ step "应用权限模式"; local mode="$1"; permission_backup_current; case "$mode" in standard) openclaw config set tools.profile coding; openclaw config set tools.exec.security allowlist; openclaw config set tools.exec.ask on-miss; openclaw config set tools.elevated.enabled false; openclaw config set commands.bash false; openclaw config set tools.exec.applyPatch.enabled false; openclaw config set tools.exec.applyPatch.workspaceOnly true;; developer) openclaw config set tools.profile coding; openclaw config set tools.exec.security allowlist; openclaw config set tools.exec.ask on-miss; openclaw config set tools.elevated.enabled true; openclaw config set commands.bash true; openclaw config set tools.exec.applyPatch.enabled true; openclaw config set tools.exec.applyPatch.workspaceOnly true;; full) openclaw config set tools.profile full; openclaw config set tools.exec.security full; openclaw config set tools.exec.ask off; openclaw config set tools.elevated.enabled true; openclaw config set commands.bash true; openclaw config set tools.exec.applyPatch.enabled true; openclaw config set tools.exec.applyPatch.workspaceOnly true;; defaults) openclaw config unset tools.profile >/dev/null 2>&1 || true; openclaw config unset tools.exec.security >/dev/null 2>&1 || true; openclaw config unset tools.exec.ask >/dev/null 2>&1 || true; openclaw config unset tools.elevated.enabled >/dev/null 2>&1 || true; openclaw config unset commands.bash >/dev/null 2>&1 || true; openclaw config unset tools.exec.applyPatch.enabled >/dev/null 2>&1 || true; openclaw config unset tools.exec.applyPatch.workspaceOnly >/dev/null 2>&1 || true;; esac; restart_gateway || true; }
permission_menu(){ step "权限管理"; while true; do clear; cecho "权限管理"; permission_render_status; echo; cecho "1. 标准安全模式"; cecho "2. 开发增强模式"; cecho "3. 完全开放模式"; cecho "4. 恢复官方默认"; cecho "5. 运行安全审计"; cecho "6. 恢复上次权限备份"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) read -r -p "输入 yes 确认：" y; [[ "$y" == "yes" ]] && permission_apply standard; press_enter;; 2) read -r -p "输入 yes 确认：" y; [[ "$y" == "yes" ]] && permission_apply developer; press_enter;; 3) read -r -p "输入 FULL 确认：" y; [[ "$y" == "FULL" ]] && permission_apply full; press_enter;; 4) read -r -p "输入 yes 确认：" y; [[ "$y" == "yes" ]] && permission_apply defaults; press_enter;; 5) openclaw security audit || true; press_enter;; 6) permission_restore_backup; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
multiagent_json(){ step "获取多智能体列表"; openclaw agents list --json 2>/dev/null || echo '[]'; }
multiagent_render_status(){ python3 - <<'PY' "$(multiagent_json)"
import json,sys
try:a=json.loads(sys.argv[1])
except: a=[]
print(f'已配置智能体数: {len(a)}')
for x in a[:8]: print(f"- {x.get('id','?')} | {x.get('workspace','-')}")
PY
}
multiagent_menu(){ step "多智能体管理"; while true; do clear; cecho "多智能体管理"; multiagent_render_status; echo; cecho "1. 列出智能体"; cecho "2. 新增智能体"; cecho "3. 删除智能体"; cecho "4. 新增路由绑定"; cecho "5. 移除路由绑定"; cecho "6. 查看会话概况"; cecho "7. 健康检查"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) openclaw agents list || true; press_enter;; 2) read -r -p "输入 Agent ID：" aid; read -r -p "输入 workspace（默认 ~/.openclaw/workspace-$aid）：" ws; [[ -n "$aid" ]] && openclaw agents add "$aid" --workspace "${ws:-~/.openclaw/workspace-$aid}"; press_enter;; 3) read -r -p "输入 Agent ID：" aid; read -r -p "输入 DELETE 确认：" y; [[ "$y" == "DELETE" && -n "$aid" ]] && openclaw agents delete "$aid"; press_enter;; 4) read -r -p "输入 Agent ID：" aid; read -r -p "输入 bind 值：" bind; [[ -n "$aid" && -n "$bind" ]] && openclaw agents bind --agent "$aid" --bind "$bind"; press_enter;; 5) read -r -p "输入 Agent ID：" aid; read -r -p "输入 bind 值：" bind; [[ -n "$aid" && -n "$bind" ]] && openclaw agents unbind --agent "$aid" --bind "$bind"; press_enter;; 6) find "$OPENCLAW_HOME/agents" -name 'sessions.json' -maxdepth 3 2>/dev/null | sed 's#^#- #'; press_enter;; 7) openclaw config validate || true; find "$OPENCLAW_HOME/agents" -maxdepth 2 -type d 2>/dev/null | sed 's#^#- #'; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
backup_manifest(){ local out="$1" root="$2"; local manifest="${out}.manifest.txt"; find "$root" -type f | sort > "$manifest" || true; while IFS= read -r f; do shasum -a 256 "$f"; done < "$manifest" > "${out}.sha256" 2>/dev/null || true; }
backup_project(){ step "备份项目"; local out="$BACKUP_DIR/openclaw-project-safe-$(date +%Y%m%d-%H%M%S).tar.gz"; local tmp="$(mktemp -d)"; local items=(); [[ -f "$OPENCLAW_HOME/openclaw.json" ]] && items+=("openclaw.json"); [[ -d "$OPENCLAW_HOME/workspace" ]] && items+=("workspace"); [[ -d "$OPENCLAW_HOME/extensions" ]] && items+=("extensions"); [[ -d "$OPENCLAW_HOME/skills" ]] && items+=("skills"); [[ -d "$OPENCLAW_HOME/prompts" ]] && items+=("prompts"); [[ -d "$OPENCLAW_HOME/tools" ]] && items+=("tools"); [[ ${#items[@]} -gt 0 ]] || die "没有可备份项目"; for i in "${items[@]}"; do cp -R "$OPENCLAW_HOME/$i" "$tmp/" 2>/dev/null || true; done; tar -czf "$out" -C "$tmp" .; backup_manifest "$out" "$tmp"; rm -rf "$tmp"; cecho "✅ 备份完成：$out"; }
backup_memory(){ step "备份记忆"; local out="$BACKUP_DIR/openclaw-memory-full-$(date +%Y%m%d-%H%M%S).tar.gz"; local tmp="$(mktemp -d)"; [[ -f "$WORKSPACE_DIR/MEMORY.md" ]] && cp "$WORKSPACE_DIR/MEMORY.md" "$tmp/" || true; [[ -d "$WORKSPACE_DIR/memory" ]] && cp -R "$WORKSPACE_DIR/memory" "$tmp/" || true; find "$tmp" -mindepth 1 | grep -q . || die "没有可备份记忆文件"; tar -czf "$out" -C "$tmp" .; backup_manifest "$out" "$tmp"; rm -rf "$tmp"; cecho "✅ 备份完成：$out"; }
restore_backup(){ step "还原备份"; read -r -p "输入备份包完整路径：" fp; [[ -f "$fp" ]] || die "备份包不存在"; warn "这是高风险操作，会覆盖现有文件。"; read -r -p "确认继续输入 yes：" y; [[ "$y" == "yes" ]] || return 0; local current_backup="$BACKUP_DIR/pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"; tar -czf "$current_backup" -C "$OPENCLAW_HOME" . 2>/dev/null || true; cecho "ℹ️ 已先备份当前状态：$current_backup"; tar -xzf "$fp" -C "$OPENCLAW_HOME"; cecho "✅ 还原完成"; }
delete_backup(){ step "删除备份"; ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null || { warn "暂无备份文件"; return 0; }; read -r -p "输入要删除的备份完整路径：" fp; [[ -f "$fp" ]] || die "文件不存在"; read -r -p "输入 DELETE 确认：" y; [[ "$y" == "DELETE" ]] || return 0; rm -f "$fp"; cecho "✅ 已删除：$fp"; }
backup_restore_menu(){ step "备份还原管理"; while true; do clear; cecho "OpenClaw 备份与还原"; ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "暂无备份文件"; echo; cecho "1. 备份记忆全量"; cecho "2. 还原备份"; cecho "3. 备份 OpenClaw 项目"; cecho "4. 删除备份文件"; cecho "0. 返回"; read -r -p "请选择：" c; case "$c" in 1) backup_memory; press_enter;; 2) restore_backup; press_enter;; 3) backup_project; press_enter;; 4) delete_backup; press_enter;; 0) return 0;; *) warn "无效选项"; sleep 1;; esac; done; }
install_launch_agent(){ step "安装开机自启"; local oc_bin; oc_bin=$(command -v openclaw || true); [[ -n "$oc_bin" ]] || die "未找到 openclaw 命令"; cat > "$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>ai.openclaw.gateway</string><key>ProgramArguments</key><array><string>$oc_bin</string><string>gateway</string><string>start</string></array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>StandardOutPath</key><string>${OPENCLAW_HOME}/logs/launchd.out.log</string><key>StandardErrorPath</key><string>${OPENCLAW_HOME}/logs/launchd.err.log</string></dict></plist>
EOF
launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true; launchctl load "$LAUNCH_AGENT_PLIST"; cecho "✅ 已安装 launchctl 开机自启"; }
remove_launch_agent(){ step "移除开机自启"; launchctl unload "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true; rm -f "$LAUNCH_AGENT_PLIST"; cecho "✅ 已移除开机自启"; }
update_openclaw(){ step "更新 OpenClaw"; ensure_homebrew; install_dependencies; npm install -g "$OPENCLAW_NPM_PACKAGE"; restart_gateway || true; cecho "✅ 已更新 OpenClaw"; press_enter; }
uninstall_openclaw(){ step "卸载 OpenClaw"; read -r -p "确认卸载输入 yes：" y; [[ "$y" == "yes" ]] || return 0; remove_launch_agent || true; openclaw uninstall >/dev/null 2>&1 || true; npm uninstall -g openclaw || true; cecho "✅ 已卸载 npm 包，配置目录保留：$OPENCLAW_HOME"; press_enter; }
show_menu(){ clear; cecho "======================================="; cecho "🦞 OPENCLAW macOS 管理工具（稳定性增强版）"; cecho "版本: $SCRIPT_VERSION"; cecho "======================================="; cecho "1.  环境自检"; cecho "2.  安装"; cecho "3.  启动"; cecho "4.  停止"; cecho "--------------------"; cecho "5.  状态日志查看"; cecho "6.  换模型"; cecho "7.  API管理"; cecho "8.  机器人连接对接"; cecho "9.  插件管理（安装/删除）"; cecho "10. 技能管理（安装/删除）"; cecho "11. 编辑主配置文件"; cecho "12. 配置向导"; cecho "13. 健康检测与修复"; cecho "14. WebUI访问与设置"; cecho "15. TUI命令行对话窗口"; cecho "16. 记忆/Memory"; cecho "17. 权限管理"; cecho "18. 多智能体管理"; cecho "--------------------"; cecho "19. 备份与还原"; cecho "20. 更新"; cecho "21. 卸载"; cecho "22. 安装开机自启（launchctl）"; cecho "23. 移除开机自启"; cecho "0. 退出"; cecho "--------------------"; }
main(){ ensure_macos; load_brew_env; ensure_openclaw_dirs; ensure_openclaw_config; while true; do show_menu; read -r -p "请输入选项并回车：" choice; case "$choice" in 1) self_check;; 2) install_openclaw; press_enter;; 3) start_gateway; press_enter;; 4) stop_gateway; press_enter;; 5) view_logs; press_enter;; 6) change_model; press_enter;; 7) api_manage_menu;; 8) bot_pairing_menu;; 9) plugin_manage;; 10) skill_manage;; 11) edit_main_config;; 12) run_onboard; press_enter;; 13) doctor_fix;; 14) webui_menu;; 15) tui_chat;; 16) memory_menu;; 17) permission_menu;; 18) multiagent_menu;; 19) backup_restore_menu;; 20) update_openclaw;; 21) uninstall_openclaw;; 22) install_launch_agent; press_enter;; 23) remove_launch_agent; press_enter;; 0) exit 0;; *) warn "无效选项"; sleep 1;; esac; done; }
main "$@"
