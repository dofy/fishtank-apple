import SwiftUI
import CoreText
#if os(macOS)
import AppKit
#endif

enum PixelTheme {
    static let ink = Color(hex: 0x101F36)
    static let shell = Color(hex: 0x7797A0)
    static let panel = Color(hex: 0x142F40)
    static let card = Color(hex: 0x224555)
    static let text = Color(hex: 0xF1EED4)
    static let muted = Color(hex: 0xACCCD0)
    static let gold = Color(hex: 0xF0C66E)
    static let green = Color(hex: 0x8CC5A5)
    static let pink = Color(hex: 0xEC9FAD)
    static let highlight = Color(hex: 0xC9E0DF)
    static var fontName = "FusionPixel-12px-monospaced-zh_hans"
    private static var fontNames: [L10n.Language: String] = [:]

    static func registerFont() {
        for language in L10n.Language.allCases where fontNames[language] == nil {
            guard let url = Bundle.main.url(forResource: language.fontResource, withExtension: "otf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
               let descriptor = descriptors.first,
               let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String { fontNames[language] = name }
        }
        if let name = fontNames[L10n.language] { fontName = name }
    }
    static var filterButtonWidth: CGFloat {
        switch L10n.language {
        case .english: return metric(96, 96)
        case .japanese: return metric(64, 88)
        default: return metric(48, 56)
        }
    }
    static var isPad: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    static func metric(_ mac: CGFloat, _ pad: CGFloat) -> CGFloat { isPad ? pad : mac }
    private static func fontPoints(_ size: CGFloat, language: L10n.Language) -> CGFloat {
        language == .english
            ? (size == 12 ? metric(13.75, 16.5) : max(16.5, (size / 11).rounded() * 11))
            : (size == 12 ? metric(13, 18) : size)
    }
    /// Popup width includes the complete localized label, measured in its actual face.
    static func textWidth(_ text: String, language: L10n.Language? = nil) -> CGFloat {
        let language = language ?? L10n.language
        let font = CTFontCreateWithName((fontNames[language] ?? fontName) as CFString, fontPoints(12, language: language), nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font
        ]))
        return ceil(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
    static func font(_ size: CGFloat = 12, language: L10n.Language? = nil) -> Font {
        let language = language ?? L10n.language
        let points = fontPoints(size, language: language)
        let name = fontNames[language] ?? fontName
        if language == .english {
            let fallback = CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: fontNames[.simplifiedChinese] ?? "Fusion-Pixel-12px-Mono-zh-Hans-Regular"
            ] as CFDictionary)
            let descriptor = CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute: name, kCTFontCascadeListAttribute: [fallback]
            ] as CFDictionary)
            return Font(CTFontCreateWithFontDescriptor(descriptor, points, nil))
        }
        return .custom(name, fixedSize: points)
    }
    static func captionFont() -> Font {
        if L10n.language == .english { return font() }
        return .custom(fontName, fixedSize: metric(13, 15))
    }
}

extension Color {
    init(hex: Int) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct PixelOutline: Shape {
    var cut: CGFloat = 4
    var steps: Int = 1
    func path(in r: CGRect) -> Path {
        let c = min(cut, min(r.width, r.height) / 3)
        var p = Path()
        p.move(to: CGPoint(x: c, y: 0)); p.addLine(to: CGPoint(x: r.width - c, y: 0))
        let n = max(1, steps), u = c / CGFloat(n)
        for i in 1...n { let t = CGFloat(i); p.addLine(to: CGPoint(x: r.width - c + (t - 1) * u, y: t * u)); p.addLine(to: CGPoint(x: r.width - c + t * u, y: t * u)) }
        p.addLine(to: CGPoint(x: r.width, y: r.height - c))
        for i in 1...n { let t = CGFloat(i); p.addLine(to: CGPoint(x: r.width - t * u, y: r.height - c + (t - 1) * u)); p.addLine(to: CGPoint(x: r.width - t * u, y: r.height - c + t * u)) }
        p.addLine(to: CGPoint(x: c, y: r.height))
        for i in 1...n { let t = CGFloat(i); p.addLine(to: CGPoint(x: c - (t - 1) * u, y: r.height - t * u)); p.addLine(to: CGPoint(x: c - t * u, y: r.height - t * u)) }
        p.addLine(to: CGPoint(x: 0, y: c))
        for i in 1...n { let t = CGFloat(i); p.addLine(to: CGPoint(x: t * u, y: c - (t - 1) * u)); p.addLine(to: CGPoint(x: t * u, y: c - t * u)) }
        p.closeSubpath()
        return p
    }
}

#if os(macOS)
/// Paint the entire rim inside the hosting view; centered strokes lose their
/// outer half at the borderless window edge. The inner cut follows the same grid.
struct PixelWindowRim: Shape {
    var width: CGFloat = 2
    func path(in rect: CGRect) -> Path {
        let bounds = CGRect(origin: .zero, size: rect.size)
        var path = PixelOutline(cut: 18, steps: 3).path(in: bounds)
        let inner = CGRect(origin: .zero, size: CGSize(width: max(0, rect.width - width * 2),
                                                       height: max(0, rect.height - width * 2)))
        path.addPath(PixelOutline(cut: max(0, 18 - width), steps: 3).path(in: inner),
                     transform: CGAffineTransform(translationX: width, y: width))
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

struct PixelWindowFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(PixelOutline(cut: 12, steps: 3))
            .padding(6)
            .background(PixelOutline(cut: 18, steps: 3).fill(PixelTheme.shell, style: FillStyle(antialiased: false)))
            .overlay {
                PixelWindowRim().fill(PixelTheme.ink, style: FillStyle(eoFill: true, antialiased: false))
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
    }
}
#endif

/// A collection milestone, using the same flat pixel tags as display badges.
struct PixelDiscoveryBadge: View {
    @ObservedObject private var localization = AppLocalization.shared
    var newSpecies: Bool
    var body: some View {
        HStack(spacing: 6) {
            PixelIcon(newSpecies ? "fish" : "book", color: PixelTheme.ink)
            Text(newSpecies ? L10n.text("新鱼种") : L10n.text("新外观"))
        }
        .font(PixelTheme.font()).foregroundStyle(PixelTheme.ink)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(PixelOutline().fill(newSpecies ? PixelTheme.gold : PixelTheme.green))
        .overlay(PixelOutline().stroke(PixelTheme.ink, lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(newSpecies ? L10n.text("首次发现新鱼种") : L10n.text("首次获得此鱼种的品阶外观"))
    }
}

struct PixelPanel: ViewModifier {
    var fill: Color = PixelTheme.card
    var selected = false
    func body(content: Content) -> some View {
        content
            .background(PixelOutline().fill(fill))
            .overlay(PixelOutline().stroke(selected ? PixelTheme.gold : PixelTheme.ink, lineWidth: 1))
            .overlay(PixelOutline(cut: 3).stroke(PixelTheme.highlight.opacity(selected ? 0.3 : 0.13), lineWidth: 1).padding(2))
            .overlay(alignment: .top) { Rectangle().fill(selected ? PixelTheme.gold : PixelTheme.highlight.opacity(0.45)).frame(height: 1).padding(.horizontal, 5) }
            .overlay(alignment: .bottom) { Rectangle().fill(PixelTheme.ink.opacity(0.7)).frame(height: 2).padding(.horizontal, 5) }
    }
}

/// Recessed glass display shared by fish and decoration cards.
struct PixelSpecimenWell: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x173644)))
            for row in 0..<4 {
                context.fill(Path(CGRect(x: 1, y: CGFloat(row * 16 + 8), width: size.width - 2, height: 1)),
                             with: .color(PixelTheme.highlight.opacity(0.025)))
            }
            for i in 0..<5 {
                let x = floor(size.width * 0.72) + CGFloat(i * 3)
                context.fill(Path(CGRect(x: x, y: 3, width: 2, height: 7 + CGFloat(i % 2) * 3)),
                             with: .color(PixelTheme.highlight.opacity(0.1)))
            }
            context.fill(Path(CGRect(x: 6, y: size.height - 3, width: max(0, size.width - 12), height: 1)),
                         with: .color(PixelTheme.highlight.opacity(0.12)))
        }.clipShape(PixelOutline(cut: 4))
            .overlay(PixelOutline(cut: 4).stroke(PixelTheme.ink.opacity(0.8), lineWidth: 1))
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}
extension View {
    func pixelPanel(_ fill: Color = PixelTheme.card, selected: Bool = false) -> some View { modifier(PixelPanel(fill: fill, selected: selected)) }

    /// Shared display treatment; material selection takes precedence over display status.
    func pixelCard(displayed: Bool, selected: Bool = false) -> some View {
        pixelPanel(selected ? Color(hex: 0x315A6A) : displayed ? Color(hex: 0x2E565C) : PixelTheme.card, selected: selected)
            .overlay(PixelOutline().stroke(displayed && !selected ? PixelTheme.green : Color.clear, lineWidth: 2)
                .allowsHitTesting(false))
    }
}

private struct PixelClickKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
extension EnvironmentValues {
    var pixelClick: () -> Void { get { self[PixelClickKey.self] } set { self[PixelClickKey.self] = newValue } }
}

struct PixelButtonStyle: ButtonStyle {
    var primary = false
    var compact = false
    var fixedWidth: CGFloat? = nil
    func makeBody(configuration: Configuration) -> some View {
        PixelButtonBody(configuration: configuration, primary: primary, compact: compact, fixedWidth: fixedWidth)
    }
}

/// Own the locale observation inside the rendered body. An unchanged label must
/// update its font without waiting for a press/hover to invalidate ButtonStyle.
private struct PixelButtonBody: View {
    let configuration: ButtonStyleConfiguration
    var primary: Bool
    var compact: Bool
    var fixedWidth: CGFloat?
    @ObservedObject private var localization = AppLocalization.shared
    @Environment(\.isEnabled) private var enabled
    @Environment(\.pixelClick) private var click
    var body: some View {
        configuration.label
            .font(PixelTheme.font())
            .lineLimit(1)
            .fixedSize(horizontal: fixedWidth != nil, vertical: false)
            .foregroundStyle(primary ? PixelTheme.ink : PixelTheme.text)
            .padding(.horizontal, fixedWidth == nil ? (compact ? PixelTheme.metric(12, 16) : PixelTheme.metric(16, 18)) : 8)
            .frame(width: fixedWidth.map { PixelTheme.isPad ? max(56, $0) : $0 }, height: PixelTheme.metric(40, 48))
            .frame(minWidth: fixedWidth == nil && !compact ? PixelTheme.metric(64, 84) : nil)
            .contentShape(Rectangle())
            .background(PixelOutline().fill(primary ? PixelTheme.green : PixelTheme.card))
            .overlay(PixelOutline().stroke(PixelTheme.ink, lineWidth: 1))
            .overlay(PixelOutline(cut: 3).stroke(PixelTheme.highlight.opacity(primary ? 0.45 : 0.18), lineWidth: 1).padding(2))
            .overlay(alignment: .top) { Rectangle().fill(PixelTheme.highlight.opacity(configuration.isPressed ? 0.1 : 0.4)).frame(height: 1).padding(.horizontal, 5) }
            .overlay(alignment: .bottom) { Rectangle().fill(PixelTheme.ink.opacity(0.5)).frame(height: configuration.isPressed ? 0 : 3).padding(.horizontal, 4) }
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.35)
            .onChange(of: configuration.isPressed) { if $0 && enabled { click() } }
    }
}

struct PixelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        PixelToggleBody(configuration: configuration)
    }
}

private struct PixelToggleBody: View {
    let configuration: ToggleStyleConfiguration
    @ObservedObject private var localization = AppLocalization.shared
    var body: some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 10) {
                ZStack {
                    Rectangle().fill(PixelTheme.ink).frame(width: 20, height: 20)
                    if configuration.isOn { PixelIcon("check", color: PixelTheme.green).frame(width: 16, height: 16) }
                }
                configuration.label.font(PixelTheme.captionFont()).foregroundStyle(PixelTheme.text)
                    .lineLimit(PixelTheme.isPad ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.buttonStyle(PixelButtonStyle())
            .accessibilityValue(configuration.isOn ? L10n.text("已开启") : L10n.text("已关闭"))
    }
}

struct PixelMeter: View {
    var value: Double
    var total: Double
    var color = PixelTheme.green
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(PixelTheme.ink)
                Rectangle().fill(color).frame(width: max(0, proxy.size.width - 4) * min(1, max(0, value / max(1, total))))
                    .padding(2)
            }
        }.frame(height: 10)
            .accessibilityValue("\(Int(min(1, max(0, value / max(1, total))) * 100))%")
    }
}

struct PixelIcon: View {
    var name: String
    var color: Color
    init(_ name: String, color: Color = PixelTheme.text) { self.name = name; self.color = color }
    private var rows: [String] { Self.pattern(name) }
    private static func pattern(_ name: String) -> [String] {
        switch name {
        case "size": return ["######..","#....#..","#..#....","..#.....",".#....#.",".#....#.",".######.","........"]
        case "pin": return ["..####..","...##...","...##...","..####..",".######.","...##...","...#....","........"]
        case "drop": return ["...#....","..###...","..###...",".#####..",".#####..",".#####..","..###...","........"]
        case "move": return ["...#....","..###...","...#....","#######.","...#....","..###...","...#....","........"]
        case "food": return ["..####..","..#..#..",".######.",".#....#.",".######.","...#....",".#...#..","........"]
        case "bell": return ["...#....","..###...",".#...#..",".#...#..",".#...#..","#######.","...#....","........"]
        case "power": return ["...#....",".#.#.#..","#..#..#.","#.....#.","#.....#.",".#...#..","..###...","........"]
        case "eye": return ["........","..###...",".#...#..","#..#..#.",".#...#..","..###...","........","........"]
        case "heartEmpty": return [".##.##..","#..#..#.","#.....#.",".#...#..","..#.#...","...#....","........","........"]
        case "heart": return [".##.##..","#######.","#######.",".#####..","..###...","...#....","........","........"]
        case "plant": return ["...#....",".#.#.#..",".###.#..","...###..",".#.#....",".###....","...#....",".#####.."]
        case "book": return [".######.",".#....#.",".####.#.",".#....#.",".####.#.",".#....#.",".######.","........"]
        case "gear": return ["..#.#...",".#####..","##...##.",".#.#.#..","##...##.",".#####..","..#.#...","........"]
        case "merge": return ["#.....#.",".#...#..","..#.#...","...#....","..###...",".#####..","..###...","........"]
        case "medal": return ["##...##.",".##.##..","..###...",".#####..",".##.##..",".#####..","..###...","........"]
        case "lock": return ["..###...",".#...#..",".#...#..",".#####..",".##.##..",".##.##..",".#####..","........"]
        case "unlock": return ["....##..","...#..#.","...#....",".#####..",".##.##..",".##.##..",".#####..","........"]
        case "infinity": return ["........",".##..##.","#..##..#","#..##..#",".##..##.","........","........","........"]
        case "check": return ["........","......#.",".....##.","#...##..","##.##...",".###....","..#.....","........"]
        case "close": return ["#.....#.",".#...#..","..#.#...","...#....","..#.#...",".#...#..","#.....#.","........"]
        case "sun": return ["...#....",".#...#..","..###...","#.###.#.","..###...",".#...#..","...#....","........"]
        case "moon": return ["..###...",".##.....",".##.....",".##...#.",".###.##.","..####..","...##...","........"]
        default: return ["........","....##..","#..####.","####.##.","#######.","#..####.","....##..","........"]
        }
    }
    #if os(macOS)
    static func menuImage(_ name: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.labelColor.setFill()
            for (y, row) in pattern(name).enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "#" {
                    NSRect(x: x * 2, y: y * 2, width: 2, height: 2).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
    #endif
    var body: some View {
        Canvas { context, size in
            let cell = floor(min(size.width, size.height) / 8)
            for (y, row) in rows.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "#" {
                    context.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)), with: .color(color))
                }
            }
        }.frame(width: 16, height: 16).accessibilityHidden(true)
    }
}

#if os(macOS)
/// Shared chrome for the handbook and settings; native drag behavior, pixel visuals.
struct PixelWindowChrome: View {
    let title: String
    let closeLabel: String
    let close: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            PixelDragBar().overlay(alignment: .leading) {
                HStack(spacing: 8) {
                    PixelIcon("fish", color: PixelTheme.ink)
                    Text(title).font(PixelTheme.font(18)).foregroundStyle(PixelTheme.ink)
                }.padding(.leading, 10).allowsHitTesting(false)
            }.frame(height: 44).accessibilityLabel(L10n.text("拖动窗口"))
                .accessibilityIdentifier("window.dragBar")
            Button(action: close) { PixelIcon("close", color: PixelTheme.pink) }
                .buttonStyle(PixelButtonStyle(fixedWidth: 40)).accessibilityLabel(closeLabel)
        }.padding(.horizontal, 12).padding(.vertical, 8)
            .background(PixelTheme.shell).padding(.bottom, 12)
    }
}

struct PixelDragBar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Region() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class Region: NSView {
        override func mouseDown(with event: NSEvent) {
            NotificationCenter.default.post(name: .aquariumWindowWillDrag, object: window)
            window?.performDrag(with: event)
        }
    }
}
#endif
