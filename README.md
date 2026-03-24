# macosscript

macOS 版 OpenClaw 管理脚本（kejilion 风格复刻增强版）。

## 快速开始

### 一键安装 / 运行

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mjj0001/macosscript/main/scripts/install.sh)
```

### 本地运行

```bash
chmod +x openclaw-macos-kejilion-rebuild.sh
./openclaw-macos-kejilion-rebuild.sh
```

## 项目结构

- `openclaw-macos-kejilion-rebuild.sh` - 主脚本
- `scripts/install.sh` - 一键安装入口
- `docs/USAGE.md` - 使用说明
- `LICENSE` - MIT 许可

## 功能

- 安装 / 启动 / 停止 OpenClaw
- API 管理
- 插件管理
- 技能管理
- WebUI 设置
- Memory 管理
- 权限管理
- 多智能体管理
- 备份与还原
- launchctl 开机自启

## 说明

这是面向 macOS 的适配发布版，不是 Linux 原脚本的原样搬运。
