#if os(macOS)
import SwiftUI

struct PixelTabStyle: ButtonStyle {
    var selected: Bool
    var width: CGFloat? = nil
    var edge: Edge = .top
    enum Edge { case top, bottom }
    func makeBody(configuration: Configuration) -> some View {
        PixelTabBody(configuration: configuration, selected: selected, width: width, edge: edge)
    }
}

private struct PixelTabBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    let width: CGFloat?
    let edge: PixelTabStyle.Edge
    @ObservedObject private var localization = AppLocalization.shared
    @Environment(\.pixelClick) private var click
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        configuration.label
            .font(PixelTheme.font()).lineLimit(1).fixedSize()
            .foregroundStyle(selected ? PixelTheme.green : PixelTheme.muted)
            .frame(width: width, height: 44)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(PixelTabOutline(edge: edge).fill(selected ? PixelTheme.panel : PixelTheme.card.opacity(hovering || configuration.isPressed ? 1 : 0.45)))
            .overlay(PixelTabOutline(edge: edge, open: selected).stroke(selected ? PixelTheme.shell : PixelTheme.shell.opacity(0.35), style: StrokeStyle(lineWidth: 1)))
            .overlay(alignment: edge == .top ? .top : .bottom) {
                if selected { Rectangle().fill(PixelTheme.green).frame(height: 2).padding(.horizontal, 5) }
            }
            .overlay(alignment: edge == .top ? .bottom : .top) {
                if selected { Rectangle().fill(PixelTheme.panel).frame(height: 2).padding(.horizontal, 1).offset(y: edge == .top ? 1 : -1) }
            }
            .overlay {
                if focused { PixelTabOutline(edge: edge).stroke(PixelTheme.gold, lineWidth: 1).padding(3) }
            }
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.35)
            .onHover { hovering = $0 }
            .onChange(of: configuration.isPressed) { if $0 && enabled { click() } }
    }
}

/// Stepped top corners, square bottom corners shared with the content surface.
private struct PixelTabOutline: Shape {
    var edge: PixelTabStyle.Edge
    var open = false
    func path(in r: CGRect) -> Path {
        let c: CGFloat = 4
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.height))
        p.addLine(to: CGPoint(x: 0, y: c))
        p.addLine(to: CGPoint(x: c, y: c))
        p.addLine(to: CGPoint(x: c, y: 0))
        p.addLine(to: CGPoint(x: r.width-c, y: 0))
        p.addLine(to: CGPoint(x: r.width-c, y: c))
        p.addLine(to: CGPoint(x: r.width, y: c))
        p.addLine(to: CGPoint(x: r.width, y: r.height))
        if !open { p.closeSubpath() }
        return edge == .top ? p : p.applying(CGAffineTransform(translationX: 0, y: r.height).scaledBy(x: 1, y: -1))
    }
}
#endif
