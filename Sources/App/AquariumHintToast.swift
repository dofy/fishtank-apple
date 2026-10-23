#if os(macOS)
import AppKit
import SwiftUI

/// Replaces the system tooltip with the same pixel bubble the agent alerts use.
struct AquariumHintView: View {
    @ObservedObject private var localization = AppLocalization.shared
    let lines: [String]
    let dismiss: () -> Void
    let silence: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    Text(line).foregroundStyle(PixelTheme.text).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, 24).padding(.trailing, 24)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button(L10n.text("Don't Show Again")) { silence() }
                    .buttonStyle(PixelButtonStyle(compact: true, height: 28))
            }
        }
        .font(PixelTheme.font(12))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PixelOutline(cut: 6, steps: 2).fill(PixelTheme.panel))
        .overlay(PixelOutline(cut: 6, steps: 2).stroke(PixelTheme.gold, lineWidth: 2).padding(1).allowsHitTesting(false))
        // Badge and close button float in the corners; neither takes layout width.
        .overlay(alignment: .topLeading) {
            PixelIcon("fish", color: PixelTheme.gold).padding(10).allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: dismiss) {
                Text("×").font(PixelTheme.font(24)).frame(width: 22, height: 22)
            }.buttonStyle(.plain).foregroundStyle(PixelTheme.muted).padding(8)
                .accessibilityLabel(L10n.text("Hide Tips"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(lines.joined(separator: " "))
    }
}

/// A child panel keeps the hint outside the tank canvas and out of the render loop.
@MainActor
final class AquariumHintPresenter {
    static let preferenceKey = "aquarium.hintSilenced"
    static let minimumWidth: CGFloat = 320
    static let maximumWidth: CGFloat = 520
    static let minimumHeight: CGFloat = 70
    private weak var parent: NSWindow?
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?
    private var hosting: NSHostingView<AnyView>?
    private var resizeObserver: NSObjectProtocol?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isSilenced: Bool { defaults.bool(forKey: Self.preferenceKey) }

    /// Natural phrasing in one bubble instead of a shortcut table.
    static var sentences: [String] {
        [L10n.text("Drag the water surface to move the aquarium, and drag scenery to rearrange the seabed."),
         L10n.text("Click empty water to feed the fish, double-click to open the care guide, and right-click to shake the tank."),
         L10n.text("The menu bar adjusts opacity, size, and always-on-top.")]
    }

    func attach(to parent: NSWindow) { self.parent = parent }

    /// A fixed width with free height makes the hosting view report the exact
    /// bubble size, so the panel never clips the outline at the top and bottom.
    private func hintView(width: CGFloat) -> AnyView {
        AnyView(
        AquariumHintView(lines: Self.sentences,
                         dismiss: { [weak self] in self?.dismiss() },
                         silence: { [weak self] in self?.silence() })
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true))
    }

    func present(duration: TimeInterval = 20) {
        guard !isSilenced, let parent else { return }
        dismiss()
        let panel = HintPanel(contentRect: NSRect(x: 0, y: 0, width: Self.maximumWidth, height: Self.minimumHeight),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.setAccessibilityLabel(L10n.text("Interaction Tips"))
        // The hosting view sizes the panel to the bubble it draws; the presenter
        // only owns the origin, so the outline is never clipped at the edges.
        let content = NSHostingView(rootView: hintView(width: hintWidth))
        panel.contentView = content
        hosting = content
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.position() }
            }
        self.panel = panel
        parent.addChildWindow(panel, ordered: .above)
        position()
        panel.orderFrontRegardless()
        dismissal = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(max(0.001, duration) * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    /// The longest sentence sets the bubble width, measured in the active pixel
    /// face, capped so a long line wraps instead of spanning the screen.
    private var hintWidth: CGFloat {
        let chrome: CGFloat = 72
        let longest = Self.sentences.map { PixelTheme.textWidth($0) }.max() ?? 0
        let available = (parent?.screen?.visibleFrame.width).map { $0 - 16 } ?? Self.maximumWidth
        return min(min(Self.maximumWidth, available), max(Self.minimumWidth, longest + chrome))
    }

    func position() {
        guard let parent, let panel else { return }
        let visibleFrame = parent.screen?.visibleFrame ?? parent.frame
        let width = hintWidth
        if let hosting, abs(hosting.frame.width - width) > 0.5 { hosting.rootView = hintView(width: width) }
        let frame = AquariumHintPlacement.frame(tank: parent.frame, visibleFrame: visibleFrame,
                                                size: panel.frame.size)
        panel.level = parent.level
        panel.collectionBehavior = parent.collectionBehavior
        panel.setFrameOrigin(frame.origin)
    }

    func setVisible(_ value: Bool) {
        guard let panel else { return }
        if value { position(); panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func dismiss() {
        dismissal?.cancel(); dismissal = nil
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        resizeObserver = nil
        hosting = nil
        guard let panel else { return }
        parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.close()
        self.panel = nil
    }

    func silence() {
        defaults.set(true, forKey: Self.preferenceKey)
        dismiss()
    }

    func allowAgain() { defaults.set(false, forKey: Self.preferenceKey) }
}

private final class HintPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
#endif
