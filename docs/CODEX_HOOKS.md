# Codex 状态气泡（macOS）

Codex 使用与 Claude Code 相同的本机接收器和像素气泡，标题明确显示 `Codex`。会话以来源和会话 ID 共同隔离；Claude 同名会话、提醒开关和排队状态不会覆盖 Codex。

## 安装与信任

先启动新版 `/Applications/Fishtank.app`，再执行：

```sh
python3 tools/install-codex-hooks.py
```

安装器合并 `$CODEX_HOME/hooks.json`（未指定时为 `~/.codex/hooks.json`），先创建权限为 `600` 的原始备份，保留所有其他 handler。脚本复制到 `~/Library/Application Support/FishtankCodexHook/codex-hook.py`，不依赖源码目录继续存在。不会修改 `notify`、模型、认证、提供商或 hook 信任记录。

Codex 要求审阅并信任新的 hook 定义。安装后在 Codex 的 `/hooks` 中找到 `FishtankCodexHook/codex-hook.py` 的新增 handler，检查并信任；未信任前 Codex 会跳过执行。不要使用跳过 hook 信任的参数。已经运行的会话若未刷新 hook，可新开或恢复会话。菜单栏可独立暂停 Codex 气泡，Claude 的开关独立保留。

非默认路径可用 `--app /path/to/Fishtank.app`、`--hooks /path/to/hooks.json`；隔离测试使用 `--bridge /path/to/bridge.json`。

```sh
python3 tools/install-codex-hooks.py --uninstall
```

卸载只移除自己的 handler，保留其他设置和备份。

## 支持的事件

| Codex 事件 | 气泡或状态 |
| --- | --- |
| SessionStart | 会话已连接 |
| UserPromptSubmit | 正在处理，立即显示 |
| PermissionRequest | 等待你的授权 |
| PreToolUse，工具为同步 request_user_input | 等待你的输入 |
| PostToolUse | 静默恢复处理中，解除同会话等待 |
| Stop | 本轮回复已结束 |
| Interrupt | 本轮已中断 |
| SessionEnd | 会话已结束 |

不从回复文本、工具失败或静默时间猜测完成状态。官方当前文档未提供通用的 Codex Notification / StopFailure hook，因此不注册这些 Claude 专用事件；异步提问工具仍可让 Agent 继续工作，不把它误标为同步阻塞等待。子 Agent 的结束不冒充主会话结束。

普通进度显示 6 秒，回复结束/中断显示 8 秒，等待显示 12 秒；等待状态仍保留在菜单中。最多同时显示 3 条气泡，各自关闭和计时，同来源同会话状态合并；额外普通事件排队，新消息和待处理事件优先展示。来源徽标使用 Codex 蓝/Claude 暖橙，边框表达状态：处理中蓝、授权金、输入紫、回复结束绿、错误红、中断橙、会话结束灰。水面提供短暂来源色像素气泡和待处理提示光，尊重减少动态效果，不改变养成数值。宽度随鱼缸变化，不抢键盘焦点、不发系统通知。

## 本机数据边界

脚本从 hook JSON 中只提取来源 `codex`、会话 ID、项目目录末级名称、事件类型、通知类型和事件 ID/时间；不转发 prompt、turn 内容、完整路径、对话文件、模型、工具输入/输出或回复文本。通过签名应用自身的只读命令和私有进程管道取得本地端口与 token，鉴权配置留在沙盒内。

接口只在本机回环地址监听。事件与气泡不写入游戏存档，也不上传。应用离线时 hook 静默成功退出，不输出上下文、不代替审批决定。

依据 [OpenAI 官方 Hooks 文档](https://learn.chatgpt.com/docs/hooks)，2026-10-22 核对。本机 CLI 为 0.154.0；原生 app 的独立 hook 信任策略仍由 Codex 管理。

2026-10-22 用户明确授权启用新增 8 项。通过 Codex 原生 app-server 的 `hooks/list` 重新取得定义并逐项核对与审阅时 hash 一致，随后使用 `config/batchWrite` 写入这 8 个精确信任项。接口复查结果全部为 `enabled=true`、`trustStatus=trusted`。用 TOML 语义比较确认其他配置及原有信任项完全一致；修改前私有配置备份位于 `build/validation/agent-and-wake/`。未重启当前 Codex 会话、未调用模型。启用证据位于 `build/codex-hook-enabled.json`。

## 轻声音提醒

独立设置窗口「提醒」页中的「提醒声音」默认开启，可单独开关，不影响游戏音乐或音效。关闭会立即停止正在播放和排队的提醒；重新打开不会补播。「提醒」页可调整轻音量并试听全部 8 种状态，所有 Agent 的同一状态共用相同音效，来源由气泡颜色识别。音效为本地合成的短促柔和音，不改变系统音量；多个提醒串行播放，最多保留 3 条，过期或同会话已更新的声音会丢弃。锁屏时不播放；暂停某来源也会停止该来源的声音。

添加、移除、检查接入和预览已迁移到独立设置窗口，完整操作与权限边界见 [Agent 设置](AGENT_SETTINGS.md)。
