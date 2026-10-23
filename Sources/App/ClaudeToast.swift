#if os(macOS)
import AppKit
import SwiftUI

struct ClaudeToastView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let event: ClaudeHookEvent
    let dismiss: () -> Void
    private var accent: Color { Color(hex: event.status?.colorHex ?? 0xACB9C4) }
    private var sourceColor: Color { Color(hex: event.agentColorHex) }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(accent).frame(width: 4)
            VStack(alignment: .leading, spacing: L10n.language == .english ? 4 : 8) {
                HStack(spacing: 8) {
                    Text(event.agentTitle).foregroundStyle(sourceColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(sourceColor.opacity(0.13))
                    Text(event.project).foregroundStyle(PixelTheme.muted).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                Text(event.status?.title ?? L10n.text("Status Update")).foregroundStyle(PixelTheme.text).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Text("×").font(PixelTheme.font(24))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain).foregroundStyle(PixelTheme.muted)
            .accessibilityLabel(L10n.text("Turn Off \(event.agentTitle) Alerts"))
        }
        .font(PixelTheme.font(12))
        .padding(L10n.language == .english ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelOutline(cut: 6, steps: 2).fill(PixelTheme.panel))
        .overlay(PixelOutline(cut: 6, steps: 2).strokeBorderFallback(accent))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(event.agentTitle)，\(event.project)，\(event.status?.title ?? L10n.text("Status Update"))")
    }
}

private extension PixelOutline {
    func strokeBorderFallback(_ color: Color) -> some View {
        stroke(color, lineWidth: 2).padding(1).allowsHitTesting(false)
    }
}

extension ClaudeToastView {
    /// Measures the bubble in the active pixel face so it is only as wide as the
    /// agent name, project and status it shows.
    static func width(for event: ClaudeHookEvent) -> CGFloat {
        let padding = (L10n.language == .english ? 10.0 : 12.0) * 2
        let badge = PixelTheme.textWidth(event.agentTitle) + 12
        let project = min(PixelTheme.textWidth(event.project), 220)
        let status = PixelTheme.textWidth(event.status?.title ?? L10n.text("Status Update"))
        let content = max(badge + 8 + project, status)
        // Accent bar, its spacing, the close button and the outer padding.
        return min(520, max(260, padding + 4 + 12 + content + 12 + 24))
    }
}

/// Independent child panels keep gaps transparent to mouse input and timers isolated.
@MainActor
final class ClaudeToastPresenter {
    private final class Entry {
        let panel: ClaudeToastPanel
        var dismissal: Task<Void, Never>?
        init(panel: ClaudeToastPanel) { self.panel = panel }
    }
    private weak var parent: NSWindow?
    private var entries: [String: Entry] = [:]
    private var stack = AgentToastStack()
    var current: ClaudeHookEvent? { stack.visible.first }
    var visibleEvents: [ClaudeHookEvent] { stack.visible }
    private var visible = false
    private let duration: (ClaudeHookEvent) -> TimeInterval

    init(duration: @escaping (ClaudeHookEvent) -> TimeInterval = { event in
        if event.isPreview { return 8 }
        if event.status?.holdsToast == true { return 12 }
        return event.status == .working || event.status == .ready ? 6 : 8
    }) { self.duration = duration }

    func attach(to parent: NSWindow) { self.parent = parent; reconcile() }

    func receive(_ event: ClaudeHookEvent, notify: Bool) {
        stack.receive(event, notify: notify)
        reconcile()
    }
    func dismiss(id: String) { stack.dismiss(id: id); reconcile() }
    func dismiss() { if let event = current { dismiss(id: event.id) } }
    func remove(source: ClaudeHookEvent.Source) { stack.remove(source: source); reconcile() }
    func clear() { stack.clear(); reconcile() }

    func refreshLocalization() {
        for event in stack.visible {
            entries[event.id]?.panel.setAccessibilityLabel(L10n.text("\(event.agentTitle) alert bubbles"))
        }
    }

    func setVisible(_ value: Bool) {
        visible = value
        position()
        for entry in entries.values {
            if value { entry.panel.orderFrontRegardless() } else { entry.panel.orderOut(nil) }
        }
    }

    func position() {
        guard let parent else { return }
        let frames = ClaudeToastPlacement.frames(tank: parent.frame,
            visibleFrame: parent.screen?.visibleFrame ?? parent.frame,
            widths: stack.visible.map { ClaudeToastView.width(for: $0) })
        for (event, frame) in zip(stack.visible, frames) {
            guard let panel = entries[event.id]?.panel else { continue }
            panel.level = parent.level
            panel.collectionBehavior = parent.collectionBehavior
            panel.setFrame(frame, display: true)
        }
    }

    private func reconcile() {
        let ids = Set(stack.visible.map(\.id))
        for id in Array(entries.keys) where !ids.contains(id) {
            guard let entry = entries.removeValue(forKey: id) else { continue }
            entry.dismissal?.cancel()
            parent?.removeChildWindow(entry.panel)
            entry.panel.orderOut(nil)
            entry.panel.close()
        }
        for event in stack.visible where entries[event.id] == nil {
            let panel = ClaudeToastPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 70),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = false; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.setAccessibilityLabel(L10n.text("\(event.agentTitle) alert bubbles"))
            panel.contentView = NSHostingView(rootView: ClaudeToastView(event: event,
                dismiss: { [weak self] in self?.dismiss(id: event.id) }))
            let entry = Entry(panel: panel)
            entries[event.id] = entry
            parent?.addChildWindow(panel, ordered: .above)
            let seconds = duration(event)
            entry.dismissal = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: UInt64(max(0.001, seconds) * 1_000_000_000)) }
                catch { return }
                guard !Task.isCancelled else { return }
                self?.dismiss(id: event.id)
            }
        }
        position()
        for entry in entries.values {
            if visible { entry.panel.orderFrontRegardless() } else { entry.panel.orderOut(nil) }
        }
    }
}

private final class ClaudeToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
#endif
