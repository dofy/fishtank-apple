# 首发分发：Mac 直接下载 + iPad TestFlight

用户已于 2026-10-21 选择这两个渠道。当前产物仍为本地候选，未上传或公证；源码公开与正式安装包分发独立。当前版本为 0.5.1，构建号 5；每次向 App Store Connect 上传新构建前递增构建号。

| 平台 | 目标标识 | 正式交付 |
| --- | --- | --- |
| macOS | `net.yahaha.fishtank.mac` | arm64/x86_64 通用应用，Developer ID Application 签名、公证并装订后压缩为 ZIP |
| iPadOS | `net.yahaha.fishtank.apple.pad` | 发行签名的设备 Archive，经 App Store Connect 处理后通过 TestFlight 安装 |

## 现有材料和待补信息

已有双端 Release 构建、图标、像素美术、字体许可、隐私清单、离线隐私说明、源码 ZIP、Mac 本地试玩 ZIP、未签名 iPad Archive 及回归证据。

用户已选定 YANG YU 团队，Team ID `2RTHE5H9TX`，双端构建配置沿用该团队。本机 Xcode 只缓存这一个团队，缓存标为 `Personal Team` / `isFreeProvisioningTeam=true`；缓存不能代替账号实时会员状态。早前本机 `security find-identity -v -p codesigning` 返回 0 个有效身份；同日真机安装尝试已取得 Apple Development 身份，见下方补充。仍需核实该团队的分发会员资格，并在 Xcode/钥匙串中配置可用的签名身份及描述文件。证书私钥、Apple 账号密码、应用专用密码和 API 私钥不写入源码或聊天。

用户随后于同日明确确认尚未加入 Apple Developer Program，分发会员状态不再是未知项，而是当前正式签名、Developer ID 公证分发和 TestFlight 的前置阻塞。没有代用户注册或付费。是否加入由用户决定；本地构建和已取得的验收结果继续保留。

同日后续只读检查发现一台配对的 iPad8,1 已通过本地网络可用，系统 26.7.2，开发者模式开启；`ddiServicesAvailable=false`。这只证明设备已连接，不证明开发服务、签名或安装已就绪，也不构成最低 iPadOS 16 验收。没有向该设备安装或启动测试应用。

发布者还需提供公开的支持/隐私地址，以及 TestFlight 测试说明、反馈联系方式和必要的审核信息。外部测试还需要 Beta App Review；不预先声称审批通过。最低系统、真机触控/后台/音频与长时间运行验收见发布清单。

## 当前本地审阅快照

`build/distribution/0.4.0-review-no-recenter/` 用于审阅移除窗口切屏自动居中路径后的源码和构建。打包前重新通过 35 项核心测试、Mac 双架构 Release、iPad 设备 Archive 与资源检查。该目录包含本地 ad-hoc Mac 应用、Mac ZIP、源码 ZIP 和含未完成门槛的哈希清单。用户随后手动确认隔离 QA 跨屏正常、抓取点稳定；本次复核只读核对机器代码与资源，没有启动或替换个人应用、没有自动拖动。系统文件面板仍未验收通过。

`acceptance-2026-10-21.json` 记录打包后的人工验收更新，清单关联该记录并更新发布门槛。Mac 应用和两个 ZIP 均保留原内容与哈希；源码 ZIP 是打包时快照，不伪称包含后续文档与团队配置更新。

## 本地准备

为已确认团队生成本地准备文件：

```sh
python3 tools/prepare-distribution.py --team-id 2RTHE5H9TX --output build/distribution/yuyang-signing-preparation
```

脚本只生成两个本地导出配置和分发计划；不登录、不生成证书、不更新描述文件、不签名或上传。输出目录已存在会拒绝覆盖。两个配置均明确 `destination=export`；iPad 使用当前 Xcode 的 `app-store-connect`，Mac 使用 `developer-id`。这些是目标渠道的准备配置，Personal Team 缓存并不证明具备相应分发权限，不把生成配置当成签名已就绪。

## Mac 正式包

1. 在 Xcode 为 FishtankMac 选择发布者团队，使用 Release 对通用目标 Archive。检查包含 arm64、x86_64，目标 Bundle ID 和沙箱权限与候选一致。
2. 在 Organizer 中选择 Developer ID 分发。先导出并核对签名、版本、隐私清单和已验收的资源；当前 ad-hoc 试玩包不能直接冒充正式包。
3. 将准确的候选版本、文件哈希、签名团队、待上传目标交给发布者审核。确认上传后再通过 Organizer 或已配置的 `notarytool` 提交 Apple 公证。
4. 公证通过后装订票据，检查 `codesign --verify --deep --strict`、`xcrun stapler validate` 和 `spctl --assess --type execute`。重新压缩最终应用并生成 SHA-256。
5. 在启用 Gatekeeper 的另一台 Mac 从真实下载文件首次启动，验收透明度、菜单栏、存档与通知。之后才把 ZIP 发布到选定下载地址。

不要求用户关闭 Gatekeeper 或移除隔离属性来绕过正式分发验收。

## iPad TestFlight

1. 在 Xcode 为 FishtankPad 选择同一发布者团队；确认该团队拥有目标 Bundle ID，签名和描述文件可用。已有未签名 Archive 只作编译证据，正式 Archive 需按选定团队重新生成并核对。
2. 在连接的 iPad 真机验收触控、横竖屏、后台恢复、通知、系统静音/耳机中断和长时间运行；现有模拟器结果不替代真机。
3. 在发布者的 App Store Connect 准备对应应用记录，核对语言、隐私/支持地址、加密声明、测试说明与反馈联系人。此步骤会写入外部账号，执行前核对准确团队及目标。
4. 使用 Organizer Validate App；先本地导出发行包审核。确认具体构建和目标后再上传 App Store Connect；处理完成后先安装 TestFlight 构建复验。
5. 发布者选择测试人员范围。内部测试和外部测试分别按账号权限及 Beta 审核要求启用，不自动邀请测试者或公开测试链接。

## 依据

- [Apple：Developer ID 与 Mac 直接分发](https://developer.apple.com/developer-id/)
- [Apple：macOS 软件公证](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple：通过 TestFlight 分发应用](https://help.apple.com/xcode/mac/current/en.lproj/dev2539d985f.html)
- 导出配置键和值已对照本机 Xcode 27.1 的 `xcodebuild -help`。

## 2026-10-21 iPad 真机安装尝试

7.IPP 已配对、开发者模式开启；用户解锁后 DDI 挂载成功且 isUsable=true。通过 YANG YU 自动签名构建了开发包，当前钥匙串已有 Apple Development 身份。此证据只证明开发签名可用，不证明 Developer ID / App Store 发行资格。

首次安装返回描述文件不包含设备；随后指定 7.IPP 并允许注册设备重建，Apple 明确返回 `Your development team has reached the maximum number of registered iPad devices.`。因此应用未成功安装，真机验收仍未完成。没有移除团队中的其他设备，也未更换团队。日志位于 `build/validation/ipad-device-registered-build.log`。

模拟器已验证去除 iPad 外窗框、预览透明圆角，以及沉浸观赏的进入、隐藏操作条、唤回、投喂、旋转和返回。最新结果为 `build/validation/ipad-immersion-ui-final.xcresult`；320 点六页面布局在 `build/validation/ipad-immersion-ui.xcresult` 中通过，其首次沉浸测试失败记录不作为通过依据。

后续 iPad 界面取消标题栏，按横竖屏改为左右 / 上下分区；沉浸模式去除所有按钮，单击投喂或点鱼互动，双击只弹像素风退出确认。确认框打开时暂停场景并阻止背景交互，辅助功能提供独立投喂 / 退出动作。最终手势结果位于 `build/validation/ipad-layout-gestures-ui-verified.xcresult`；旧操作条验收是此前实现的历史记录。

### 本地 macOS 提醒身份

本地安装优先使用已有的 Apple Development 签名，保留稳定的 designated requirement。临时 ad-hoc 签名每次构建的 cdhash 不同，可能留下不同来源的旧提醒；这些旧提醒不随新来源的繁育操作取消。`tools/package-local.sh` 在只有一个开发签名时自动选用，也可用 `FISHTANK_MAC_SIGN_IDENTITY` 指定。没有开发签名时产物仍标记为 ad-hoc；不得视为通知身份稳定的发布包。

应用启动清理自身遗留提醒，操作立即作废旧计划，前台弹出前校验计划代次和当前状态。回满必须达到 5 颗心，按绝对时间安排，不使用延迟后才计算的相对秒数。`open /Applications/Fishtank.app --args --test-notification` 仅在新启动时安排一条明确标为图标测试的本地提醒，不更改游戏进度。

2026-10-21 排查初期记录（已由下方最终结果取代）：53 项核心测试通过，Mac 和 iPad 构建通过。系统中只有一条当前代次的回满提醒，与存档计算的五心截止时间一致。旧安装的完整进度经正常离线推进后与新版导出逐字段相等，19 条鱼保留。Mac 使用独立的全尺寸 `FishtankIcon.icns`，启动时在通知注册前设置运行图标。通知横幅图标仍显示系统占位图，已实际截图确认；不能声称已修复。重新登记、重启通知与图标服务、普通应用登记实验均未解决，因此恢复后台应用登记。没有清空系统通知数据库、变更应用标识或要求注销系统。

### 通知图标最终修复与原型迁移（2026-10-21）

同一图标资源、相同开发签名的最小通知程序，在旧标识 `net.yahaha.fishtank.apple.mac` 下显示占位图，在干净测试标识下显示正常。旧标识的重新登记、通知服务重启和用户图标索引重建均未纠正这一差异。正式 Mac 标识改为 `net.yahaha.fishtank.mac`，iPad 标识保持原样。最终 `/Applications/Fishtank.app` 的真实通知横幅已截图验证，使用当前像素鱼缸图标；未通过附件图、私有通知 API 或修改系统通知数据库替代应用图标。

原型程序以 `--export-installation-state --verify-update` 在自身沙箱内读取进度和白名单偏好，通过标准输出导出迁移快照；新程序通过 `--migrate-installation-state` 从标准输入接收。安装目标目录必须不存在，所有存档与恢复文件先在临时目录写好再原子移动；已有目标会拒绝覆盖。旧沙箱保留，迁移快照保留在新沙箱 `installation-transfer.json`，本机验证材料位于忽略的 `build/validation/icon-source-isolation/`，不得混入源代码或发行 ZIP。

本机逐字段核对：19 条鱼、5126 经验、鱼 UID/繁育次数/锁定状态、展示位、图鉴、成就、装饰、音效、灯光和随机状态与旧进度正常离线推进后的结果一致；3 份恢复文件随迁移写入，75% 水体透明度、置顶、1 倍尺寸、提醒偏好及原副屏窗口坐标保留。AppKit 会重新映射跨屏自动保存位置，因此在确认原坐标仍可达后显式恢复；断开屏幕时继续使用已有回收逻辑。

防止编译副本同时运行：Mac 在创建存档 Store 前检查同标识进程，第二个副本直接退出。实际启动第二副本已验证只留下一个安装实例。通知授权请求合并为一个进行中的 Task，避免迁移启动与显式测试同时请求权限。59 项核心测试、Mac Release 与 iPad Simulator 构建通过。最终验收截图：`build/validation/notification-icon-fixed.png`。
