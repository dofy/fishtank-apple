#if os(macOS)
import SwiftUI
import AppKit

struct AgentSettingsView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var aquarium: FloatingAquariumController
    @ObservedObject var model: AgentSettingsStore
    @ObservedObject var store: AquariumStore
    var initialPage = "general"
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
                    let labelWidth = menu.choices.map { PixelTheme.textWidth($0.title, language: $0.language) }.max() ?? 0
                    let width = min(max(bounds.width, labelWidth + 76), geometry.size.width - 24)
                    let height = CGFloat(menu.choices.count * 38 + 10)
                    let x = max(12, min(bounds.minX, geometry.size.width - width - 12))
                    let below = bounds.maxY + 4
                    let y = below + height <= geometry.size.height - 12 ? below : max(12, bounds.minY - height - 4)
                    // Leave the 72-point window chrome available to native dragging.
                    Color.black.opacity(0.001).frame(height: max(0, geometry.size.height - 72))
                        .contentShape(Rectangle()).onTapGesture { choices.dismiss() }.offset(y: 72)
                    PixelChoicePopup(controller: choices, menu: menu).frame(width: width, height: height)
                        .offset(x: x, y: y)
                }
            }
        }
        .environmentObject(choices)
        .onChange(of: page) { _ in choices.dismiss(); colorPanel.close() }
        .onChange(of: selected) { _ in colorPanel.close() }
        .onDisappear { colorPanel.close() }
        .onReceive(NotificationCenter.default.publisher(for: .aquariumLanguageDidChange)) { _ in
            choices.dismiss(); colorPanel.close()
        }
        .onReceive(NotificationCenter.default.publisher(for: .aquariumWindowWillDrag)) { _ in choices.dismiss() }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PixelWindowChrome(title: L10n.text("Fishtank / Settings"), closeLabel: L10n.text("Close Settings")) { aquarium.closeAgentSettings() }
            SettingsTabBar(selection: $page)
            if page == "general" {
                PixelScrollView { VStack(alignment: .leading, spacing: 28) { LanguageSettingsView(); KeepAwakeSettingsView() }.padding(24) }
            }
            else if page == "appearance" { AppIconSettingsView(icons: aquarium.appIcons, store: store) }
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
            Text(L10n.text("Remove \(agent.name)?")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            Text(agent.isBuiltIn ? L10n.text("Uninstalling removes only Fishtank hooks and local settings. Other hooks, settings, and trust records remain. You can add it again later.") : L10n.text("Stops receiving from this source and removes local settings. You must remove any pasted send commands from the external Agent yourself."))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L10n.text("Cancel")) { removing = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(agent.isBuiltIn ? L10n.text("Uninstall and Remove") : L10n.text("Remove")) {
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
                Text(L10n.text("Added \(model.agents.count)")).foregroundStyle(PixelTheme.muted)
                PixelScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.agents) { agent in
                            Button { selected = agent.id; copied = false } label: {
                                HStack(spacing: 10) {
                                    Rectangle().fill(Color(hex: agent.colorHex)).frame(width: 8, height: 24)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(agent.name).lineLimit(1)
                                        Text(agent.enabled ? L10n.text("Enabled") : L10n.text("Paused")).foregroundStyle(PixelTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selected == agent.id ? PixelTheme.card : .clear)
                                    .overlay(Rectangle().stroke(selected == agent.id ? PixelTheme.gold : PixelTheme.shell.opacity(0.25), lineWidth: 1).allowsHitTesting(false))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("agents.select." + agent.id)
                                .accessibilityValue(selected == agent.id ? L10n.text("Selected [choice]") : L10n.text("None Selected"))
                        }
                    }
                }
                Button(L10n.text("+ Add Agent")) { adding = true }.disabled(model.agents.count >= 16 || model.storageError != nil).accessibilityIdentifier("agents.add")
                Toggle(L10n.text("Pause all"), isOn: $model.paused).accessibilityIdentifier("agents.pause")
            }.padding(20).frame(width: 216)
            Divider().overlay(PixelTheme.shell.opacity(0.3))
            PixelScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let error = model.storageError { Text(error).foregroundStyle(PixelTheme.pink) }
                    if let agent = model.agent(selected) { detail(agent) }
                    else {
                        Text(L10n.text("Bring Agent status into your aquarium")).font(PixelTheme.font(20)).foregroundStyle(PixelTheme.gold)
                        Text(L10n.text("Add Claude Code, Codex, or a custom source to receive working, permission, completion, and other events."))
                        Button(L10n.text("Add Agent")) { adding = true }
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
                Toggle(L10n.text("Enable"), isOn: binding(agent, \.enabled)).fixedSize().accessibilityIdentifier("agents.enabled")
            }
            if model.paused { Text(L10n.text("All alerts are paused. Previews and integration checks are still available.")).foregroundStyle(PixelTheme.gold) }
            VStack(alignment: .leading, spacing: 10) {
                label(L10n.text("Receiver"), model.receiverReady ? L10n.text("Ready") : L10n.text("Starting / Unavailable"))
                label(L10n.text("Method"), agent.isBuiltIn ? L10n.text("Install Hook Automatically") : L10n.text("Configure Hook / Plugin Manually"))
                label(L10n.text("Setup"), model.configurationChecks[agent.id].map(L10n.text) ?? (agent.isBuiltIn ? L10n.text("Not Checked") : L10n.text("Manual setup; no automatic detection")))
                label(L10n.text("Last event"), model.lastEvent(agent.id))
                if !agent.isBuiltIn { Text(L10n.text("This source has no automatic installer yet. The check only verifies Fishtank's receiver path; confirm external integration with a real event.")).foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true) }
                if agent.source == .codex { Text(L10n.text("New hooks require trust review in Codex /hooks. A connection check does not replace a real trigger.")).foregroundStyle(PixelTheme.muted) }
                if let message = model.messages[agent.id] { Text(L10n.text(message)).foregroundStyle(PixelTheme.gold).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("agents.result") }
            }
            HStack(spacing: 12) {
                Button(model.busy.contains(agent.id) ? L10n.text("Checking…") : L10n.text("Check Integration")) { model.check(agent.id) }.disabled(model.busy.contains(agent.id)).accessibilityIdentifier("agents.check")
                if agent.isBuiltIn { Button(L10n.text("Install / Repair")) { model.configure(agent.id) }.disabled(model.busy.contains(agent.id)).accessibilityIdentifier("agents.install") }
                Spacer(minLength: 0)
                Button(L10n.text("Remove…")) { removing = agent }.accessibilityIdentifier("agents.remove")
            }
            Divider()
            Text(L10n.text("Alert Method")).foregroundStyle(PixelTheme.gold)
            HStack(spacing: 24) {
                Toggle(L10n.text("Bubbles"), isOn: binding(agent, \.bubbles))
                Toggle(L10n.text("Sound"), isOn: binding(agent, \.sound))
                Toggle(L10n.text("Reaction"), isOn: binding(agent, \.aquariumResponse))
            }.fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(L10n.text("Color")).foregroundStyle(PixelTheme.muted)
                ForEach(colors(for: agent), id: \.self) { color in
                    Button {
                        guard var value = model.agent(agent.id) else { return }; value.colorHex = color; model.update(value)
                    } label: {
                        Rectangle().fill(Color(hex: color)).frame(width: 22, height: 22)
                            .padding(3).contentShape(Rectangle())
                            .overlay(Rectangle().stroke(agent.colorHex == color ? PixelTheme.text : .clear, lineWidth: 2).allowsHitTesting(false))
                    }.buttonStyle(.plain).accessibilityLabel(String(format: L10n.text("Source Color #%06X"), color))
                        .accessibilityIdentifier(String(format: "agents.color.%06X", color))
                        .accessibilityValue(agent.colorHex == color ? L10n.text("Selected [choice]") : L10n.text("None Selected"))
                }
                Button(L10n.text("Palette")) {
                    choices.dismiss()
                    colorPanel.show(hex: agent.colorHex) { color in
                        guard var value = model.agent(agent.id) else { return }
                        value.colorHex = color; model.update(value)
                    }
                }.accessibilityIdentifier("agents.color.custom")
            }
            Text(L10n.text("Status sounds are shared by all Agents. Preview them on the Alerts page.")).foregroundStyle(PixelTheme.muted)
            Divider()
            previewControls(agent)
            if !agent.isBuiltIn { customIntegration(agent) }
        }
    }
    private func previewControls(_ agent: AgentRegistration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("Effect Preview")).foregroundStyle(PixelTheme.gold)
            HStack(spacing: 12) {
                Text(L10n.text("Status")).foregroundStyle(PixelTheme.muted)
                PixelChoiceField(id: "agents.previewStatus", label: L10n.text("Preview Status"), selection: Binding(get: { previewStatus.rawValue }, set: { if let value = ClaudeHookEvent.Status(rawValue: $0) { previewStatus = value } }),
                    choices: ClaudeHookEvent.Status.allCases.map { PixelChoice(id: $0.rawValue, title: $0.title) }).frame(maxWidth: .infinity)
                Toggle(L10n.text("Multiple"), isOn: $multiple).fixedSize()
            }
            HStack(spacing: 16) {
                Toggle(L10n.text("Play Sound"), isOn: $previewSound).disabled(!aquarium.agentSoundsEnabled)
                Spacer()
                Button(L10n.text("Preview in Aquarium")) { aquarium.previewAgent(agent.id, status: previewStatus, multiple: multiple, sound: previewSound && aquarium.agentSoundsEnabled) }.accessibilityIdentifier("agents.preview")
            }
            Text(L10n.text("The preview includes the menu bar icon and resets after 8 seconds. It does not affect real sessions or call a model.")).foregroundStyle(PixelTheme.muted)
        }
    }
    private func customIntegration(_ agent: AgentRegistration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(AgentPreset.find(agent.id).map { L10n.text("\($0.name) Integration") } ?? L10n.text("Custom Integration")).foregroundStyle(PixelTheme.gold)
            if let preset = AgentPreset.find(agent.id) {
                Text(preset.setup).foregroundStyle(PixelTheme.muted)
                if let url = preset.documentation {
                    Button(L10n.text("View Integration Guide")) { NSWorkspace.shared.open(url) }
                }
            }
            Text(L10n.text("Add the send command to the matching Agent hook. It reads JSON in the format below from standard input and sends only event metadata."))
            Text(L10n.text("{\"hook_event_name\":\"Stop\",\"session_id\":\"your-session-id\",\"cwd\":\"/project-path\"}"))
                .font(PixelTheme.font()).textSelection(.enabled).padding(12).background(PixelTheme.ink)
            Button(copied ? L10n.text("Send command copied") : L10n.text("Copy Send Command")) {
                guard let command = model.command(for: agent.id) else { return }
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string); copied = true
            }
            Text(L10n.text("Standard events: SessionStart, UserPromptSubmit, PermissionRequest, NeedsInput, Stop, StopFailure, Interrupt, SessionEnd. Raw events from other Agents must be mapped to these names by their hooks.")).foregroundStyle(PixelTheme.muted)
        }
    }
    private func label(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title).foregroundStyle(PixelTheme.muted).frame(width: L10n.language == .english ? 140 : 72, alignment: .leading)
            Text(value).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var notificationPage: some View {
        PixelScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.text("Agent Alerts")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
                HStack { Toggle(L10n.text("Alert Sounds"), isOn: $aquarium.agentSoundsEnabled); Spacer(); Text(L10n.text("Low Volume")).foregroundStyle(PixelTheme.muted) }
                HStack {
                    Text(L10n.text("Volume")); Slider(value: $aquarium.agentSoundVolume, in: 0...0.5).disabled(!aquarium.agentSoundsEnabled)
                    Text("\(Int(aquarium.agentSoundVolume * 100))%").frame(width: 44, alignment: .trailing)
                }
                Text(L10n.text("Each status shares one sound. Multiple sounds play in sequence; turning them off stops playback immediately, and missed sounds will not replay.")).foregroundStyle(PixelTheme.muted)
                if let error = aquarium.agentSoundError { Text(error).foregroundStyle(PixelTheme.pink) }
                Divider()
                Text(L10n.text("Event alerts, menu bar icon, and sounds")).foregroundStyle(PixelTheme.gold)
                Text(L10n.text("The menu bar prioritizes errors, permission requests, and input requests. Hover to see the source and project. The regular icon returns after a period without events.")).foregroundStyle(PixelTheme.muted)
                ForEach(ClaudeHookEvent.Status.allCases, id: \.self) { status in
                    HStack {
                        Image(nsImage: MenuFishArt.image(.init(status))).renderingMode(.template)
                            .foregroundStyle(PixelTheme.text).frame(width: 36, height: 18).accessibilityHidden(true)
                        Toggle(status.title, isOn: Binding(get: { !model.disabledStates.contains(status.rawValue) }, set: { enabled in
                            if enabled { model.disabledStates.remove(status.rawValue) } else { model.disabledStates.insert(status.rawValue) }
                        }))
                        Spacer()
                        Button(L10n.text("Preview")) { aquarium.previewAgentSound(status: status) }.disabled(!aquarium.agentSoundsEnabled)
                    }
                }
                Divider()
                Text(L10n.text("Care Alerts")).foregroundStyle(PixelTheme.gold)
                Toggle(L10n.text("Growth, cooldown complete, full hearts"), isOn: Binding(get: { store.remindersEnabled }, set: { store.setReminders($0) }))
                Text(L10n.text("Uses system notifications. Agent alerts appear on the aquarium and are controlled separately.")).foregroundStyle(PixelTheme.muted)
            }.padding(28).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AddAgentView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var model: AgentSettingsStore
    let added: (String) -> Void
    let cancel: () -> Void
    @EnvironmentObject private var choices: PixelChoiceController
    @State private var kind = "custom"
    @State private var name = ""
    @State private var color = 0xB9A0E8
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L10n.text("Add Agent")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            HStack(spacing: 12) {
                Text(L10n.text("Agent Type")).foregroundStyle(PixelTheme.muted)
                PixelChoiceField(id: "agents.kind", label: L10n.text("Agent Type"), selection: $kind,
                    choices: AgentPreset.all.map { PixelChoice(id: $0.id, title: $0.name) } + [PixelChoice(id: "custom", title: L10n.text("Custom Agent"))])
            }
            if kind == "custom" {
                PixelTextField(prompt: L10n.text("Name, such as Local Coding Assistant"), text: $name, id: "agents.newName")
                Text(L10n.text("After adding, copy the universal send command and configure a hook in the matching Agent. Available events depend on that Agent."))
                    .foregroundStyle(PixelTheme.muted)
            } else {
                Text(model.agent(kind) != nil ? L10n.text("Already added. Use the button below to view it.") : (AgentPreset.find(kind)?.setup ?? ""))
                    .foregroundStyle(PixelTheme.muted)
            }
            HStack {
                Button(L10n.text("Cancel"), action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button(kind != "custom" && model.agent(kind) != nil ? L10n.text("View") : L10n.text("Add")) {
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
