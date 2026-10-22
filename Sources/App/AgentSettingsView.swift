#if os(macOS)
import SwiftUI
import AppKit

struct AgentSettingsView: View {
    @ObservedObject var aquarium: FloatingAquariumController
    @ObservedObject var model: AgentSettingsStore
    @ObservedObject var store: AquariumStore
    var initialPage = "agents"
    var initialSelection: String? = nil
    @StateObject private var choices = PixelChoiceController()
    @State private var page = "agents"
    @State private var selected = "claude-code"
    @State private var adding = false
    @State private var removing: AgentRegistration?
    @State private var previewStatus = ClaudeHookEvent.Status.working
    @State private var previewSound = false
    @State private var multiple = false
    @State private var copied = false
    @StateObject private var colorPanel = AgentColorPanel()
    private func colors(for agent: AgentRegistration) -> [Int] {
        var values = [0x78C8EB, 0xE9AC86, 0xB9A0E8, 0x8CC5A5, 0xF0C66E, 0xEC9FAD]
        for color in AgentPreset.all.map(\.colorHex) + [agent.colorHex] where !values.contains(color) { values.append(color) }
        return values
    }

    var body: some View {
        ZStack {
            settingsContent.disabled(adding || removing != nil).accessibilityHidden(adding || removing != nil)
            if adding || removing != nil {
                Color.black.opacity(0.6).contentShape(Rectangle()).onTapGesture { choices.dismiss() }
                if adding {
                    AddAgentView(model: model, added: { id in selected = id; adding = false; choices.dismiss() }, cancel: { adding = false; choices.dismiss() })
                        .modifier(PixelWindowFrame()).frame(maxWidth: 480).padding(24)
                } else if let agent = removing {
                    removalConfirmation(agent).modifier(PixelWindowFrame()).frame(maxWidth: 480).padding(24)
                }
            }
        }
        .overlayPreferenceValue(PixelChoiceAnchors.self) { anchors in
            GeometryReader { geometry in
                if let menu = choices.menu, let anchor = anchors[menu.id] {
                    let bounds = geometry[anchor]
                    let width = min(max(bounds.width, 220), geometry.size.width - 24)
                    let height = CGFloat(menu.choices.count * 38 + 10)
                    let x = max(12, min(bounds.minX, geometry.size.width - width - 12))
                    let below = bounds.maxY + 4
                    let y = below + height <= geometry.size.height - 12 ? below : max(12, bounds.minY - height - 4)
                    Color.black.opacity(0.001).contentShape(Rectangle()).onTapGesture { choices.dismiss() }
                    PixelChoicePopup(controller: choices, menu: menu).frame(width: width, height: height)
                        .offset(x: x, y: y)
                }
            }
        }
        .environmentObject(choices)
        .onChange(of: page) { _ in choices.dismiss(); colorPanel.close() }
        .onChange(of: selected) { _ in colorPanel.close() }
        .onDisappear { colorPanel.close() }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PixelWindowChrome(title: "Fishtank / 设置", closeLabel: "关闭设置") { aquarium.closeAgentSettings() }
            HStack(spacing: 8) {
                Button("外观") { page = "appearance" }
                    .buttonStyle(PixelButtonStyle(primary: page == "appearance", compact: true))
                    .accessibilityIdentifier("agents.page.appearance")
                    .accessibilityAddTraits(page == "appearance" ? .isSelected : [])
                Button("Agent 接入") { page = "agents" }
                    .buttonStyle(PixelButtonStyle(primary: page == "agents", compact: true))
                    .accessibilityIdentifier("agents.page.agents")
                    .accessibilityAddTraits(page == "agents" ? .isSelected : [])
                Button("提醒") { page = "notifications" }
                    .buttonStyle(PixelButtonStyle(primary: page == "notifications", compact: true))
                    .accessibilityIdentifier("agents.page.notifications")
                    .accessibilityAddTraits(page == "notifications" ? .isSelected : [])
                Spacer()
                Button("更新日志") { NSWorkspace.shared.open(URL(string: "https://github.com/dofy/fishtank-apple/blob/main/CHANGELOG.md")!) }
                    .buttonStyle(PixelButtonStyle(compact: true)).accessibilityIdentifier("settings.changelog")
                Button("项目地址") { NSWorkspace.shared.open(URL(string: "https://github.com/dofy/fishtank-apple")!) }
                    .buttonStyle(PixelButtonStyle(compact: true)).accessibilityIdentifier("settings.project")
            }.padding(.horizontal, 20).padding(.bottom, 12)
            Divider().overlay(PixelTheme.shell.opacity(0.3))
            if page == "appearance" { AppIconSettingsView(icons: aquarium.appIcons, store: store) }
            else if page == "agents" { agentPage } else { notificationPage }
        }
        .background(PixelTheme.panel).modifier(PixelWindowFrame()).foregroundStyle(PixelTheme.text)
        .font(PixelTheme.font()).preferredColorScheme(.dark)
        .buttonStyle(PixelButtonStyle(compact: true)).toggleStyle(PixelToggleStyle())
        .tint(PixelTheme.green)
        .onAppear { page = initialPage; if let initialSelection { selected = initialSelection }; if model.agent(selected) == nil { selected = model.agents.first?.id ?? "" } }
        .onChange(of: model.agents.map(\.id)) { ids in if !ids.contains(selected) { selected = ids.first ?? "" } }
    }
    private func removalConfirmation(_ agent: AgentRegistration) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("移除 \(agent.name)？").font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            Text(agent.isBuiltIn ? "卸载只删除鱼缸添加的 hook 和本地设置，保留其他 hook、配置和所有信任记录。之后可以重新添加。" : "停止接收这个来源并移除本地设置。外部 Agent 中粘贴过的发送命令需要自行删除。")
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("取消") { removing = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(agent.isBuiltIn ? "卸载并移除" : "移除") {
                    removing = nil
                    if agent.isBuiltIn { DispatchQueue.main.async { model.configure(agent.id, remove: true) } }
                    else { model.removeLocal(agent.id) }
                }.accessibilityIdentifier("agents.confirmRemove")
            }
        }.padding(24).font(PixelTheme.font()).foregroundStyle(PixelTheme.text)
            .background(PixelTheme.panel).buttonStyle(PixelButtonStyle(compact: true))
    }
    private var agentPage: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("已添加 \(model.agents.count)").foregroundStyle(PixelTheme.muted)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.agents) { agent in
                            Button { selected = agent.id; copied = false } label: {
                                HStack(spacing: 10) {
                                    Rectangle().fill(Color(hex: agent.colorHex)).frame(width: 8, height: 24)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(agent.name).lineLimit(1)
                                        Text(agent.enabled ? "已启用" : "已暂停").foregroundStyle(PixelTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selected == agent.id ? PixelTheme.card : .clear)
                                    .overlay(Rectangle().stroke(selected == agent.id ? PixelTheme.gold : PixelTheme.shell.opacity(0.25), lineWidth: 1).allowsHitTesting(false))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("agents.select." + agent.id)
                                .accessibilityValue(selected == agent.id ? "已选择" : "未选择")
                        }
                    }
                }
                Button("＋ 添加 Agent") { adding = true }.disabled(model.agents.count >= 16 || model.storageError != nil).accessibilityIdentifier("agents.add")
                Toggle("暂停全部提醒", isOn: $model.paused).accessibilityIdentifier("agents.pause")
            }.padding(20).frame(width: 216)
            Divider().overlay(PixelTheme.shell.opacity(0.3))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let error = model.storageError { Text(error).foregroundStyle(PixelTheme.pink) }
                    if let agent = model.agent(selected) { detail(agent) }
                    else {
                        Text("把 Agent 的状态带到鱼缸上").font(PixelTheme.font(20)).foregroundStyle(PixelTheme.gold)
                        Text("添加 Claude Code、Codex 或自定义来源，接收处理、待授权和回复结束等事件。")
                        Button("添加 Agent") { adding = true }
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private func binding(_ agent: AgentRegistration, _ path: WritableKeyPath<AgentRegistration, Bool>) -> Binding<Bool> {
        Binding(get: { model.agent(agent.id)?[keyPath: path] ?? false }, set: { value in
            guard var current = model.agent(agent.id) else { return }; current[keyPath: path] = value; model.update(current)
        })
    }
    private func detail(_ agent: AgentRegistration) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(agent.name).font(PixelTheme.font(24)).foregroundStyle(Color(hex: agent.colorHex))
                Spacer()
                Toggle("启用", isOn: binding(agent, \.enabled)).fixedSize().accessibilityIdentifier("agents.enabled")
            }
            if model.paused { Text("全部提醒已暂停。预览和接入检查仍可使用。").foregroundStyle(PixelTheme.gold) }
            VStack(alignment: .leading, spacing: 10) {
                label("接收器", model.receiverReady ? "已就绪" : "正在启动 / 不可用")
                label("接入方式", agent.isBuiltIn ? "自动安装 hook" : "手动配置 hook / 插件")
                label("接入配置", model.configurationChecks[agent.id] ?? (agent.isBuiltIn ? "尚未检查" : "手动配置，不自动检测"))
                label("真实事件", model.lastEvent(agent.id))
                if !agent.isBuiltIn { Text("此来源尚无自动安装器。检查只验证鱼缸接收通路，外部接入需用真实事件确认。").foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true) }
                if agent.source == .codex { Text("新增 hook 需在 Codex /hooks 中审阅信任；检查通路不会代替实际触发。").foregroundStyle(PixelTheme.muted) }
                if let message = model.messages[agent.id] { Text(message).foregroundStyle(PixelTheme.gold).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("agents.result") }
            }
            HStack(spacing: 12) {
                Button(model.busy.contains(agent.id) ? "检查中…" : "检查接入") { model.check(agent.id) }.disabled(model.busy.contains(agent.id)).accessibilityIdentifier("agents.check")
                if agent.isBuiltIn { Button("安装 / 修复") { model.configure(agent.id) }.disabled(model.busy.contains(agent.id)).accessibilityIdentifier("agents.install") }
                Spacer(minLength: 0)
                Button("移除…") { removing = agent }.accessibilityIdentifier("agents.remove")
            }
            Divider()
            Text("提醒方式").foregroundStyle(PixelTheme.gold)
            HStack(spacing: 24) {
                Toggle("气泡", isOn: binding(agent, \.bubbles))
                Toggle("声音", isOn: binding(agent, \.sound))
                Toggle("鱼缸响应", isOn: binding(agent, \.aquariumResponse))
            }.fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("来源颜色").foregroundStyle(PixelTheme.muted)
                ForEach(colors(for: agent), id: \.self) { color in
                    Button {
                        guard var value = model.agent(agent.id) else { return }; value.colorHex = color; model.update(value)
                    } label: {
                        Rectangle().fill(Color(hex: color)).frame(width: 22, height: 22)
                            .padding(3).contentShape(Rectangle())
                            .overlay(Rectangle().stroke(agent.colorHex == color ? PixelTheme.text : .clear, lineWidth: 2).allowsHitTesting(false))
                    }.buttonStyle(.plain).accessibilityLabel(String(format: "来源颜色 #%06X", color))
                        .accessibilityIdentifier(String(format: "agents.color.%06X", color))
                        .accessibilityValue(agent.colorHex == color ? "已选择" : "未选择")
                }
                Button("打开色板") {
                    choices.dismiss()
                    colorPanel.show(hex: agent.colorHex) { color in
                        guard var value = model.agent(agent.id) else { return }
                        value.colorHex = color; model.update(value)
                    }
                }.accessibilityIdentifier("agents.color.custom")
            }
            Text("状态音效由所有 Agent 共用，在「提醒」页试听。").foregroundStyle(PixelTheme.muted)
            Divider()
            previewControls(agent)
            if !agent.isBuiltIn { customIntegration(agent) }
        }
    }
    private func previewControls(_ agent: AgentRegistration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("效果预览").foregroundStyle(PixelTheme.gold)
            HStack(spacing: 12) {
                Text("状态").foregroundStyle(PixelTheme.muted)
                PixelChoiceField(id: "agents.previewStatus", label: "预览状态", selection: Binding(get: { previewStatus.rawValue }, set: { if let value = ClaudeHookEvent.Status(rawValue: $0) { previewStatus = value } }),
                    choices: ClaudeHookEvent.Status.allCases.map { PixelChoice(id: $0.rawValue, title: $0.title) }).frame(maxWidth: 220)
                Toggle("多条", isOn: $multiple).fixedSize()
            }
            HStack(spacing: 16) {
                Toggle("播放声音", isOn: $previewSound).disabled(!aquarium.agentSoundsEnabled)
                Spacer()
                Button("在鱼缸预览") { aquarium.previewAgent(agent.id, status: previewStatus, multiple: multiple, sound: previewSound && aquarium.agentSoundsEnabled) }.accessibilityIdentifier("agents.preview")
            }
            Text("预览含状态栏图标，8 秒后恢复；不改变真实会话，也不调用模型。").foregroundStyle(PixelTheme.muted)
        }
    }
    private func customIntegration(_ agent: AgentRegistration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(AgentPreset.find(agent.id).map { "\($0.name) 接入" } ?? "自定义接入").foregroundStyle(PixelTheme.gold)
            if let preset = AgentPreset.find(agent.id) {
                Text(preset.setup).foregroundStyle(PixelTheme.muted)
                if let url = preset.documentation {
                    Button("查看接入文档") { NSWorkspace.shared.open(url) }
                }
            }
            Text("将发送命令放入对应 Agent 的 hook。它从标准输入读取下面格式的 JSON，只发送事件元数据。")
            Text("{\"hook_event_name\":\"Stop\",\"session_id\":\"你的会话标识\",\"cwd\":\"/项目目录\"}")
                .font(.system(size: 11, design: .monospaced)).textSelection(.enabled).padding(12).background(PixelTheme.ink)
            Button(copied ? "发送命令已复制" : "复制发送命令") {
                guard let command = model.command(for: agent.id) else { return }
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string); copied = true
            }
            Text("标准事件：SessionStart、UserPromptSubmit、PermissionRequest、NeedsInput、Stop、StopFailure、Interrupt、SessionEnd。其他 Agent 的原始事件需由其 hook 映射为这些名称。").foregroundStyle(PixelTheme.muted)
        }
    }
    private func label(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title).foregroundStyle(PixelTheme.muted).frame(width: 72, alignment: .leading)
            Text(value).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var notificationPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Agent 提醒").font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
                HStack { Toggle("提醒声音", isOn: $aquarium.agentSoundsEnabled); Spacer(); Text("轻音量").foregroundStyle(PixelTheme.muted) }
                HStack {
                    Text("音量"); Slider(value: $aquarium.agentSoundVolume, in: 0...0.5).disabled(!aquarium.agentSoundsEnabled)
                    Text("\(Int(aquarium.agentSoundVolume * 100))%").frame(width: 44, alignment: .trailing)
                }
                Text("同一状态共用音效。多条依次播放，关闭立即停止，重新开启不补播。").foregroundStyle(PixelTheme.muted)
                if let error = aquarium.agentSoundError { Text(error).foregroundStyle(PixelTheme.pink) }
                Divider()
                Text("事件提醒、状态栏图标与音效").foregroundStyle(PixelTheme.gold)
                Text("状态栏优先显示出错、待授权、待输入；悬停可查看来源与项目。久无新事件会恢复普通图标。").foregroundStyle(PixelTheme.muted)
                ForEach(ClaudeHookEvent.Status.allCases, id: \.self) { status in
                    HStack {
                        Image(nsImage: MenuFishArt.image(.init(status))).renderingMode(.template)
                            .foregroundStyle(PixelTheme.text).frame(width: 36, height: 18).accessibilityHidden(true)
                        Toggle(status.title, isOn: Binding(get: { !model.disabledStates.contains(status.rawValue) }, set: { enabled in
                            if enabled { model.disabledStates.remove(status.rawValue) } else { model.disabledStates.insert(status.rawValue) }
                        }))
                        Spacer()
                        Button("试听") { aquarium.previewAgentSound(status: status) }.disabled(!aquarium.agentSoundsEnabled)
                    }
                }
                Divider()
                Text("养成提醒").foregroundStyle(PixelTheme.gold)
                Toggle("成年、冷却结束、爱心回满", isOn: Binding(get: { store.remindersEnabled }, set: { store.setReminders($0) }))
                Text("使用系统通知；Agent 提醒显示在鱼缸上，单独控制。").foregroundStyle(PixelTheme.muted)
            }.padding(28).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AddAgentView: View {
    @ObservedObject var model: AgentSettingsStore
    let added: (String) -> Void
    let cancel: () -> Void
    @EnvironmentObject private var choices: PixelChoiceController
    @State private var kind = "custom"
    @State private var name = ""
    @State private var color = 0xB9A0E8
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("添加 Agent").font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            HStack(spacing: 12) {
                Text("Agent 类型").foregroundStyle(PixelTheme.muted)
                PixelChoiceField(id: "agents.kind", label: "Agent 类型", selection: $kind,
                    choices: AgentPreset.all.map { PixelChoice(id: $0.id, title: $0.name) } + [PixelChoice(id: "custom", title: "自定义 Agent")])
            }
            if kind == "custom" {
                PixelTextField(prompt: "名称，例如本地编程助手", text: $name, id: "agents.newName")
                Text("添加后可复制通用发送命令，在对应 Agent 中配置 hook。支持接入的事件取决于对方能力。")
                    .foregroundStyle(PixelTheme.muted)
            } else {
                Text(model.agent(kind) != nil ? "已经添加，点击下方按钮查看。" : (AgentPreset.find(kind)?.setup ?? ""))
                    .foregroundStyle(PixelTheme.muted)
            }
            HStack {
                Button("取消", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button(kind != "custom" && model.agent(kind) != nil ? "查看" : "添加") {
                    let source = kind == "custom" ? nil : ClaudeHookEvent.Source(rawValue: kind)
                    let preset = AgentPreset.find(kind)
                    if let id = model.add(name: preset?.name ?? name, source: source, color: preset?.colorHex ?? color) { added(id) }
                }.disabled(choices.menu != nil || (kind == "custom" && (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 32)))
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("agents.confirmAdd")
            }
        }.padding(24).font(PixelTheme.font()).foregroundStyle(PixelTheme.text)
            .background(PixelTheme.panel).buttonStyle(PixelButtonStyle(compact: true)).preferredColorScheme(.dark)
    }
}
/// Owns only the color-panel session opened by settings; never edits external hook configuration.
@MainActor
private final class AgentColorPanel: NSObject, ObservableObject, NSWindowDelegate {
    private var changed: ((Int) -> Void)?
    func show(hex: Int, changed: @escaping (Int) -> Void) {
        let panel = NSColorPanel.shared
        self.changed = changed
        panel.showsAlpha = false
        panel.color = NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
                              green: Double((hex >> 8) & 255) / 255,
                              blue: Double(hex & 255) / 255, alpha: 1)
        panel.isContinuous = true
        panel.setTarget(self); panel.setAction(#selector(colorChanged(_:))); panel.delegate = self
        panel.orderFront(nil)
    }
    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        let red = Int((rgb.redComponent * 255).rounded()), green = Int((rgb.greenComponent * 255).rounded()), blue = Int((rgb.blueComponent * 255).rounded())
        changed?((red << 16) | (green << 8) | blue)
    }
    func close() {
        let panel = NSColorPanel.shared
        guard panel.delegate === self else { return }
        panel.close()
    }
    func windowWillClose(_ notification: Notification) {
        let panel = NSColorPanel.shared
        guard panel.delegate === self else { return }
        panel.setTarget(nil); panel.setAction(nil); panel.delegate = nil; changed = nil
    }
}
#endif
