# 开发与验证

当前版本为 **0.5.0（构建 4）**，核心回归 105 项通过；Mac 通用 Release、iPad Release Archive 与资源核对通过。正式分发门槛仍见 [发布清单](RELEASE_CHECKLIST.md)。

以下记录保留早期开发与验收背景，当前产品介绍见 [README](../README.md)，当前版本变化见 [更新日志](../CHANGELOG.md)。历史测试数量与候选路径不代表当前版本。

# Fishtank Apple

面向 **macOS + iPadOS** 的独立原生像素鱼缸项目。美术方向是 PC FISH 式的**彩色像素感**。鱼、造景、勋章和界面使用原创像素图，不捆绑 PC FISH 素材。

当前开发版 **0.4.0** 已迁移养成、繁育、合成、图鉴、装饰、音频和永久成就。全界面使用中文像素字体与统一像素组件。网页版源项目保持独立。

## 已有能力

- 共用 SwiftUI 界面与 SpriteKit 鱼缸；29 种鱼的彩色像素体型、游动、气泡、观赏投喂；不同品阶拥有不同色相。
- macOS 无边框、无标题栏的悬浮鱼缸；拖动移动，单击空白区域投喂，落点横坐标跟随鼠标。打开养成手册时显示 Dock 图标，支持 Cmd+Tab 切换；菜单栏显示鱼数量和繁育爱心。
- 默认全局置顶，可从菜单栏取消；置顶时加入所有桌面空间，并配置全屏辅助面板行为。普通应用切换不隐藏鱼缸，全屏应用组合仍需实测。
- 水体默认 50% 不透明度，能透出背后桌面和其他 App；菜单栏提供 50% / 75% / 100% 不透明度。仅水体透明，鱼、海草、珊瑚和底砂保持清晰。
- 菜单栏可隐藏/显示、调整三档整数像素尺寸、移回当前屏幕、投喂和切换提醒；置顶、大小和水体不透明度保存到本地偏好。
- iPad 专用应用目标，横竖屏与窄窗口自适应。
- 本地 JSON 原子保存、恢复后按时间结算成年与爱心，爱心上限 5、恢复间隔 7 分钟。
- 用户主动开启后，分别安排下一次幼鱼成年、初始鱼冷却结束与爱心回满提醒；默认关闭。关闭开关会取消本应用的待发提醒。
- 30 FPS 场景；Mac 主动隐藏时暂停，切换到其他 App 时可继续观赏，可见窗口停止出帧时自动恢复；iPad 非活跃时暂停。两端尊重“减少动态效果”。

养成界面包含鱼群、繁育、合成、图鉴与设置。保留原版数值、冷却、经验拆分、等级扩容、推荐配对、自动选材、锁定保护和永久图鉴。Mac 从菜单栏“打开养成手册”进入操作面板。详见 [迁移记录与验证](docs/GAMEPLAY_MIGRATION.md)。

已迁移 18 件装饰、3 首背景音乐与 17 个音效资源、14 项成就勋章。桌面与手册支持拖动造景、翻转、切换灯光和多枚勋章挂载。详见 [像素设计与新增系统](docs/PIXEL_DESIGN.md)。

已补齐显式存档导入/导出、自动备份与恢复，以及河豚、电鳗、追食、浮游生物、结群、海马休息和穿拱门等观赏彩蛋。保留原版昼夜、串灯和音频设定。当前不提供云同步。

## Agent 提醒（macOS）

支持 Claude Code 本地 hook：在鱼缸上方同时显示最多三条等宽像素气泡，提示正在处理、等待授权/输入、本轮回复结束或会话结束；独立设置窗口可管理、暂停和预览。提醒不抢焦点，跟随鱼缸移动与缩放；来源徽标和状态边框分别配色，水面有短暂观赏反馈。只接收本机事件，不转发对话、提示词或工具内容。设置中的「提醒」页可开关轻声音提醒、调整音量并试听 8 种状态音效；同一状态在所有 Agent 间共用音效，多条提示依次播放。

从菜单「Agent 设置」管理 Claude Code、Codex 和自定义来源，支持添加、安装/修复、移除、检查接入和单条/多条预览。已有 hook 命令和信任记录保持；详见 [Agent 设置](docs/AGENT_SETTINGS.md)。

启动新版后执行 `python3 tools/install-claude-hooks.py`，安全合并已有 Claude 配置；重启 Claude 会话生效。详情、移除方式及验证见 [Claude Code 本地提醒](docs/CLAUDE_HOOKS.md)。

也支持 Codex 的原生生命周期 hook，沿用同一套气泡并按来源隔离状态。执行 `python3 tools/install-codex-hooks.py` 后，在 Codex `/hooks` 中审阅并信任新增 handler。开始、授权、同步输入、回复结束和中断说明见 [Codex 接入](docs/CODEX_HOOKS.md)。

## 打开与运行

打开 `FishtankApple.xcodeproj`：

```sh
open FishtankApple.xcodeproj
```

- **FishtankMac**：选择 My Mac 后运行，桌面只显示半透明像素鱼缸。拖动鱼缸移动，单击空白区域投喂，落点横坐标跟随鼠标；点击菜单栏像素鱼，打开养成手册后可布置装饰、查看勋章或调整音乐，也可隐藏/显示、切换全局置顶、调节水体不透明度和尺寸。退出使用菜单里的“退出 Fishtank”。
- **FishtankPad**：选择 iPad 模拟器，或设置自己的签名团队后在 iPad 真机运行。
- 工程已生成并随源码保留；修改 `project.yml` 后用已安装的 `xcodegen generate` 更新。
- 最低目标：macOS 13 / iPadOS 16。当前只在本机 SDK 上编译，最低系统兼容性需单独验证。

## 验证

```sh
swift test
xcodebuild -project FishtankApple.xcodeproj -scheme FishtankMac -derivedDataPath build/Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FishtankApple.xcodeproj -scheme FishtankPad -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/Pad CODE_SIGNING_ALLOWED=NO build
```

`swift test` 当前含 61 项测试，其中直接对照网页版生成的 105 组繁育与 15 组合成样本，并覆盖离线成长、经验拆分、保护规则、合成拒绝路径、图鉴、彩蛋、存档迁移与恢复。通知由系统调度，用户设置、专注模式等可能影响实际呈现。

早期原型的验证记录（不是本轮候选验收）：22 项核心测试和双端 Debug 构建通过。Mac 经本地 ad-hoc 签名运行，鱼缸尺寸 640×360，无标题栏按钮；水体 alpha=0.4、底砂 alpha=1.0，菜单切换 20% 后水体 alpha=0.2。置顶层级 3、取消后 0，再启用后 3；隐藏/显示、鼠标拖动、推荐配对、繁育、收下和重启恢复曾执行验证。0.4.0 仍须补做当前构建的 Mac 交互验收，不能直接沿用旧结论。

存档位于应用容器内 Application Support 下的 `FishtankApplePrototype/aquarium-v1.json`（现为 schema 3）；旧平台原型先备份再迁移。与网页 `localStorage` 隔离；坏档保留原文件并停止覆盖，当前会话临时预览。没有登录或开发者服务器；可选 Claude 接入使用本机回环接口和已有 Python 3。

详细选型与分阶段计划见 [可行性评估](docs/FEASIBILITY.md)。

最新候选证据见 [发布清单](docs/RELEASE_CHECKLIST.md) 和 [隐私说明](docs/PRIVACY.md)。Mac 通用 Release 与 iPad Release Archive 已构建。iPad 模拟器已验证繁育、重启保留、设置持久化、系统导出窗口、横竖屏和 320 点窄布局。2026-10-21 解锁 Mac 后，已实测手册输入、四档透明度、三档尺寸与拖动、置顶/取消遮挡、原生全屏空间、窗口生命周期、繁育与离线成年不重复；实际发现并修复桌面造景拖动冲突。用户确认三首音乐和音效正常。普通多桌面切换、系统减少动态效果、音频中断、睡眠唤醒、Mac 完整文件面板、最低系统及 iPad 真机仍待验。当前不能称为已完成公开发布。

首发渠道已确定为 **Mac 直接下载 + iPad TestFlight**。签名团队和有效证书仍待配置；[分发说明](docs/DISTRIBUTION.md) 包含具体目标与本地导出准备工具。工具不登录、签名或上传。

当前 61 项核心回归通过；此前 5 条 iPad 端到端流程通过，包含完整合成与锁定保护、实际后台通知送达。确认/结果弹窗会隔离背景操作。正式发布前的未验项目仍保留在清单中。

完整本地检查：

```sh
tools/verify-release.sh
# 同时检查已有模拟器：
FISHTANK_SIMULATOR_ID=<existing-device-uuid> tools/verify-release.sh
```

检查脚本只构建和测试，不安装依赖、不登录账号、不签发正式证书、不上传。

检查通过后可运行 `tools/package-local.sh`，在 `build/distribution/0.4.0-candidate/` 生成本机签名 Mac 应用、试玩 ZIP、源码 ZIP 和 SHA-256 清单。Mac 优先使用唯一的 Apple Development 身份，缺少身份时使用 ad-hoc 签名。iPad 未签名 Archive 位于 `build/FishtankPad.xcarchive`，需选定自己的签名团队后才能导出安装包。

打包会拒绝覆盖正在运行的候选应用；可用 `tools/package-local.sh build/distribution/新的目录名` 在独立目录生成审阅副本，不退出个人鱼缸。自定义输出目录必须尚不存在。清单携带 [当前发布门槛](Configuration/ReleaseReadiness.json)、构建 UUID 和文件哈希；生成本地包不会清除未解决项或自动获得发布资格。

## 仓库内容与本机数据

仓库包含原生源码、像素与音频资源、Xcode 工程、测试和构建工具。繁育与合成结果会用金色「新鱼种」或薄荷绿「新外观」徽标标识首次收藏；重复获得不显示徽标。

个人存档、导出文件、验收快照、构建目录、安装包、Xcode 用户状态以及签名私钥和描述文件均不应提交。常见路径和文件类型已列入 `.gitignore`。Mac 正式应用标识为 `net.yahaha.fishtank.mac`，存档保存在其沙盒容器中，不在源码目录中。

`Tests/Fixtures` 中的 JSON 是工具生成的合成测试样本，不是玩家存档，用于跨版本和网页版导入兼容性回归。签名团队 ID 属于构建元数据，证书和私钥由本机钥匙串管理。
