import SwiftUI

struct LanguageSettingsView: View {
    @ObservedObject private var localization = AppLocalization.shared
    private var selection: Binding<String> {
        Binding(get: { localization.preference.rawValue },
                set: { if let preference = L10n.Preference(rawValue: $0) { localization.select(preference) } })
    }
    private func title(_ value: L10n.Preference) -> String {
        value.nativeName ?? L10n.text("跟随系统")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("语言")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            #if os(macOS)
            PixelChoiceField(id: "settings.language", label: L10n.text("语言"), selection: selection,
                choices: L10n.Preference.allCases.map { PixelChoice(id: $0.rawValue, title: title($0), language: L10n.Language(rawValue: $0.rawValue)) })
                .frame(maxWidth: 320)
            #else
            ForEach(L10n.Preference.allCases, id: \.self) { value in
                Button { selection.wrappedValue = value.rawValue } label: {
                    Text(title(value)).font(PixelTheme.font(language: L10n.Language(rawValue: value.rawValue)))
                }
                    .buttonStyle(PixelButtonStyle(primary: selection.wrappedValue == value.rawValue, compact: true))
                    .accessibilityIdentifier("settings.language." + value.rawValue)
                    .accessibilityValue(selection.wrappedValue == value.rawValue ? L10n.text("已选中") : L10n.text("未选中"))
            }
            #endif
            Text(L10n.text("选择会自动保存，界面语言和像素字体立即切换。"))
                .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
