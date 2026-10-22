# Claude Code 本地提醒

macOS 版可接收 Claude Code command hook 的状态，在悬浮鱼缸正上方显示等宽像素气泡。接收器只监听 `127.0.0.1` 的系统分配端口，使用每次启动重新生成的本地 token，不向外部服务器发送数据。iPad 不提供此功能。

## 接入

先启动新版 Fishtank，再在源码目录执行：

```sh
python3 tools/install-claude-hooks.py
```

默认合并当前用户的 `~/.claude/settings.json`，在同目录创建权限为 `600` 的原始配置备份；保留现有设置及其他 hook，不覆盖或禁用它们。重复执行只更新本应用的 handler。脚本复制到 `~/Library/Application Support/FishtankClaudeHook/claude-hook.py`，不依赖源码目录继续存在。需要本机已有 Python 3，不安装依赖。

安装后重新启动 Claude Code 会话。可用 `--settings /path/to/project/.claude/settings.local.json` 限定到单个项目；默认应用位置为 `/Applications/Fishtank.app`，可用 `--app /path/to/Fishtank.app` 更改。每次事件调用应用自身的 `--export-claude-bridge` 只读命令获取当前本地端口和 token，通过私有进程管道传递，不启动窗口或存档，也不将 token 写入 Claude 配置。这样可绕过命令行读取应用沙盒目录的系统限制，同时保留沙盒隔离。测试环境可用 `--bridge /path/to/claude-bridge.json` 指定临时配置。

菜单栏“Claude Code 气泡提醒”可暂停事件展示，“预览多 Agent 提醒”可同时检查三条气泡。暂停展示仍保留本地接收器；要停止 Claude 调用本应用脚本，可移除已安装的 handler：

```sh
python3 tools/install-claude-hooks.py --uninstall
```

若安装到项目配置，卸载时携带同一个 `--settings` 参数。卸载保留其他 hook、脚本文件与配置备份。Claude 的组织策略、禁用 hook 设置和工作区信任仍由 Claude 自身控制，本应用不绕过。

## 状态与提醒

| Claude 事件 | 展示 | 收起 |
| --- | --- | --- |
| SessionStart | 会话已连接 | 6 秒 |
| UserPromptSubmit | 正在处理 | 6 秒 |
| PermissionRequest / Notification permission_prompt | 等待你的授权 | 最多 12 秒，也可提前关闭 |
| Notification idle_prompt / elicitation_dialog / elicitation_url_dialog / agent_needs_input | 等待你的输入 | 最多 12 秒，也可提前关闭 |
| Stop | 本轮回复已结束 | 8 秒 |
| StopFailure | 本轮运行出错 | 8 秒 |
| SessionEnd | 会话已结束 | 8 秒 |
| PostToolUse / PostToolUseFailure | 静默更新为处理中，解除同会话等待气泡 | 不新增气泡 |

Stop 表示 Claude 回复结束，不表示用户的整个任务完成。单次工具失败也不直接判定整个会话失败。忽略子 Agent 结束、登录成功等不相关事件。

气泡使用 70 点固定高度，宽度跟随 320 / 640 / 960 点鱼缸。拖动、缩放、置顶、隐藏和空间行为跟随鱼缸；顶部空间不足时优先放到缸下方，再回退到屏幕内叠放，避免被菜单栏裁切。气泡不抢键盘焦点，关闭按钮可点击。不自动显示被用户隐藏的鱼缸，也不请求系统通知权限。

事件按来源和会话隔离：最多同时显示 3 条等宽气泡，同会话更新合并成最新一条；独立倒计时和关闭，互不取消。额外普通提醒最多排队 8 条，超过 30 秒的未展示旧事件不再重放。新消息、待处理事件优先展示，已展示过的旧条被替换后不重复排队。设置页展示最近真实事件和时间；缺少后续 hook 时不能当作实时心跳。气泡不保存到游戏存档，重启后不恢复。

来源徽标以 Codex 蓝、Claude 暖橙区分；边框以处理中蓝、授权金、输入紫、回复结束绿、错误红、已中断橙、会话结束灰区分，同时保留文字。提醒触发来源色像素气泡，待处理时水面提示光短暂变化；减少动态效果时只显示短暂静态标记。这些只影响观赏层，不投喂、不改变鱼群行为参数、养成随机数或灯光配置。

## 数据边界

hook 进程从 stdin 读取 Claude 的 JSON 后，只通过白名单转发随机事件 ID、会话 ID、项目目录末级名称、事件类型、通知类型和发送时间。提示词、完整路径、对话记录、工具参数、执行输出、通知原文及 Claude 回复内容不转发。app 内状态只保存在内存。

本地 token 配置权限为 `600`；接口拒绝未鉴权、过期或无效事件，限制连接数、请求大小与读取时间。应用配置读取超时为 0.7 秒、hook 网络超时为 0.35 秒、Claude handler 超时为 2 秒；应用离线、JSON 无效和接收失败时静默成功退出，不输出上下文，不返回审批决定。

## 验证

```sh
swift test
python3 tools/test-claude-hooks.py
# Debug 构建后，运行真实 HTTP 与离屏渲染检查，不启动个人存档或显示窗口：
python3 tools/test-claude-hooks.py --app build/claude-mac/Build/Products/Debug/FishtankMac.app
```

离屏结果位于 `build/claude-hook-validation/`。检查覆盖隐私白名单、配置备份/合并/幂等/卸载、离线静默退出、真实 hook 到接收器链路、鉴权、旧事件拒绝、三档气泡渲染，以及队列合并、等待解除、优先提醒和关闭。主机的实际跨桌面/全屏组合仍需交互验收。

事件协议依据 [Claude Code 官方 Hooks reference](https://code.claude.com/docs/en/hooks)，2026-10-21 核对，本机 Claude Code 2.1.304。

2026-10-21 本机验证：66 项 Swift 测试、5 项 Python 检查（含真实 loopback 链路及离屏渲染）通过；Mac arm64/x86_64 Release、iPad 构建通过。已用原有开发签名更新 `/Applications/Fishtank.app` 并安装用户级 hooks。实际安装的 hook 经应用私有管道读取连接配置，约 0.11 秒完成调用；窗口服务确认真实气泡为 320×70 点，与个人鱼缸左边缘、宽度一致。17 条鱼的 ID、养成进度与窗口偏好核对保留。旧应用和前后存档快照保存在 `build/validation/claude-installation/`；既有 20 个 handler 及其他 Claude 设置保持一致。此项验证不等同于已实测所有 Claude 交互事件或跨桌面组合；新开的 Claude 会话会载入新 hook。

2026-10-21 提醒可见性修复：用户报告重新打开 Claude 会话后发消息未看到提醒；只读辅助功能检查实际项目 `Seven` 的气泡文本为“等待你的输入”，确认自动 hook 已到达。另以失败回归复现等待气泡永久占用显示位、其他会话的新消息只能排队的问题。已改为新消息和需处理事件立即显示、优先于已有队列；普通开始/进度显示 6 秒，等待显示最多 12 秒，菜单等待状态继续保留。菜单预览遇真实事件立即让位。新增检查覆盖跨会话等待阻塞、已有队列中的优先显示、预览让位和真实自动收起；5 项接入检查及 Mac 双架构 Release 通过。已更新本机应用，17 条鱼及偏好保持；备份在 `build/validation/claude-toast-fix/`。用户随后在原有 Claude Code 会话再次发送消息，明确确认“出现了”。未重装 hook，未发起模型 API 调用。

## 轻声音提醒

独立设置窗口「提醒」页中的「提醒声音」默认开启，可单独开关，不影响游戏音乐或音效。关闭会立即停止正在播放和排队的提醒；重新打开不会补播。「提醒」页可调整轻音量并试听全部 8 种状态，所有 Agent 的同一状态共用相同音效，来源由气泡颜色识别。音效为本地合成的短促柔和音，不改变系统音量；多个提醒串行播放，最多保留 3 条，过期或同会话已更新的声音会丢弃。锁屏时不播放；暂停某来源也会停止该来源的声音。

添加、移除、检查接入和预览已迁移到独立设置窗口，完整操作与权限边界见 [Agent 设置](AGENT_SETTINGS.md)。
