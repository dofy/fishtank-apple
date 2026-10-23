#if os(macOS)
import SwiftUI
import AppKit

/// Open-bottom pixel tabs join the selected page; external links remain actions.
struct SettingsTabBar: View {
    @Binding var selection: String
    @ObservedObject private var localization = AppLocalization.shared
    private var tabs: [(String, String)] {
        [("general", L10n.text("通用")), ("appearance", L10n.text("外观")),
         ("agents", L10n.text("Agent 接入")), ("notifications", L10n.text("提醒"))]
    }
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(tabs, id: \.0) { id, title in
                Button { selection = id } label: { Text(title) }
                    .buttonStyle(PixelTabStyle(selected: selection == id, width: max(88, PixelTheme.textWidth(title) + 36)))
                    .accessibilityIdentifier("agents.page." + id)
                    .accessibilityAddTraits(selection == id ? .isSelected : [])
            }
            Spacer(minLength: 16)
            HStack(spacing: 8) {
                Button(L10n.text("更新日志")) { NSWorkspace.shared.open(URL(string: "https://github.com/dofy/fishtank-apple/blob/main/CHANGELOG.md")!) }
                    .accessibilityIdentifier("settings.changelog")
                Button(L10n.text("项目地址")) { NSWorkspace.shared.open(URL(string: "https://github.com/dofy/fishtank-apple")!) }
                    .accessibilityIdentifier("settings.project")
            }.padding(.bottom, 4)

        }
        .buttonStyle(PixelButtonStyle(compact: true))
        .padding(.horizontal, 20).padding(.top, 4)
        .background(alignment: .bottom) {
            Rectangle().fill(PixelTheme.shell.opacity(0.5)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.tabs")
    }
}

#endif
