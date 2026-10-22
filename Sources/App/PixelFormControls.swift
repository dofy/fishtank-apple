#if os(macOS)
import SwiftUI

struct PixelChoice: Identifiable {
    let id: String
    let title: String
    var language: L10n.Language? = nil
}

@MainActor final class PixelChoiceController: ObservableObject {
    struct Menu {
        let id: String
        let choices: [PixelChoice]
        let selected: String
        let select: (String) -> Void
    }
    @Published var menu: Menu?
    @Published var highlighted = 0
    @Published var restoreFocus = ""
    func toggle(id: String, choices: [PixelChoice], selected: String, select: @escaping (String) -> Void) {
        if menu?.id == id { dismiss(); return }
        restoreFocus = ""
        highlighted = choices.firstIndex { $0.id == selected } ?? 0
        menu = Menu(id: id, choices: choices, selected: selected, select: select)
    }
    func dismiss() { restoreFocus = menu?.id ?? ""; menu = nil }
    func choose(_ value: String) { let action = menu?.select; dismiss(); action?(value) }
    func move(_ offset: Int) {
        guard let menu, !menu.choices.isEmpty else { return }
        highlighted = (highlighted + offset + menu.choices.count) % menu.choices.count
    }
}

struct PixelChoiceAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, right in right })
    }
}

/// Popup contents render inside the pixel window, avoiding platform popup chrome and scroll clipping.
struct PixelChoiceField: View {
    @ObservedObject private var localization = AppLocalization.shared
    let id: String
    let label: String
    @Binding var selection: String
    let choices: [PixelChoice]
    @EnvironmentObject private var controller: PixelChoiceController
    @FocusState private var focused: Bool
    var body: some View {
        Button {
            controller.toggle(id: id, choices: choices, selected: selection) { selection = $0 }
        } label: {
            HStack(spacing: 12) {
                Text(choices.first { $0.id == selection }?.title ?? label)
                    .font(PixelTheme.font(language: choices.first { $0.id == selection }?.language)).lineLimit(1)
                Spacer(minLength: 8)
                Text(controller.menu?.id == id ? "▴" : "▾").font(PixelTheme.font())
            }.frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(PixelButtonStyle(compact: true))
        .focused($focused)
        .overlay(PixelOutline().stroke(focused ? PixelTheme.gold : .clear, lineWidth: 2).allowsHitTesting(false))
        .accessibilityLabel(label).accessibilityValue(choices.first { $0.id == selection }?.title ?? "")
        .accessibilityIdentifier(id)
        .anchorPreference(key: PixelChoiceAnchors.self, value: .bounds) { [id: $0] }
        .onChange(of: controller.restoreFocus) { value in if value == id { focused = true } }
    }
}

struct PixelChoicePopup: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var controller: PixelChoiceController
    let menu: PixelChoiceController.Menu
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(menu.choices.enumerated()), id: \.element.id) { index, item in
                Button { controller.choose(item.id) } label: {
                    HStack(spacing: 10) {
                        PixelIcon("check", color: index == controller.highlighted ? PixelTheme.ink : PixelTheme.text)
                            .opacity(item.id == menu.selected ? 1 : 0).frame(width: 16)
                        Text(item.title).font(PixelTheme.font(language: item.language)).lineLimit(1)
                        Spacer(minLength: 0)
                    }.font(PixelTheme.font()).foregroundStyle(index == controller.highlighted ? PixelTheme.ink : PixelTheme.text)
                        .padding(.horizontal, 12).frame(height: 36).frame(maxWidth: .infinity)
                        .background(index == controller.highlighted ? PixelTheme.green : PixelTheme.card)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .keyboardShortcut(index == controller.highlighted ? KeyboardShortcut.defaultAction : nil)
                    .onHover { inside in if inside { controller.highlighted = index } }
                    .accessibilityLabel(item.title)
                    .accessibilityIdentifier(menu.id + ".option." + item.id)
                    .accessibilityAddTraits(item.id == menu.selected ? .isSelected : [])
            }
        }.padding(6).background(PixelTheme.ink)
            .overlay(PixelOutline().stroke(PixelTheme.shell, lineWidth: 2).allowsHitTesting(false))
            .compositingGroup()
            .shadow(color: .black.opacity(0.2), radius: 0, x: 2, y: 2)
            .focusable().focused($focused).modifier(PixelNoSystemFocus())
            .onAppear { focused = true }
            .onMoveCommand { direction in
                if direction == .down { controller.move(1) }
                if direction == .up { controller.move(-1) }
            }
            .onExitCommand { controller.dismiss() }
            .onSubmit { if menu.choices.indices.contains(controller.highlighted) { controller.choose(menu.choices[controller.highlighted].id) } }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(menu.id + ".popup")
    }
}

private struct PixelNoSystemFocus: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) { content.focusEffectDisabled() } else { content }
    }
}

struct PixelTextField: View {
    @ObservedObject private var localization = AppLocalization.shared
    let prompt: String
    @Binding var text: String
    let id: String
    @FocusState private var focused: Bool
    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.plain).font(PixelTheme.font()).foregroundStyle(PixelTheme.text)
            .focused($focused).padding(.horizontal, 12).frame(height: 40)
            .background(PixelOutline().fill(PixelTheme.ink))
            .overlay(PixelOutline().stroke(focused ? PixelTheme.gold : PixelTheme.shell, lineWidth: focused ? 2 : 1).allowsHitTesting(false))
            .contentShape(Rectangle()).onTapGesture { focused = true }
            .accessibilityIdentifier(id)
    }
}
#endif
