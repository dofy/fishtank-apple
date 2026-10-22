#if os(macOS)
import SwiftUI

struct AppIconSettingsView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var icons: AppIconStore
    @ObservedObject var store: AquariumStore
    @State private var selectedID = AppIconCatalog.original.id
    @State private var tier = -1
    private var selectedTier: Int? { tier < 0 ? nil : tier }
    private var selected: AppIconDesign { AppIconCatalog.design(selectedID) }
    private func unlocked(_ design: AppIconDesign) -> Bool { AppIconCatalog.isUnlocked(design, discovered: store.state.discovered) }
    private var applyTitle: String {
        if !unlocked(selected) { return icons.currentID == selectedID ? L10n.text("正在使用") : L10n.text("发现品种后解锁") }
        return icons.currentID == selectedID ? L10n.text("重新应用") : L10n.text("使用此图标")
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 20) {
                    artwork(selected, size: 64)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("应用图标")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
                        Text(selected.name).foregroundStyle(PixelTheme.text)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button(applyTitle) { icons.apply(selected) }
                            .disabled(!unlocked(selected) || (icons.currentID == selectedID && selectedID == AppIconCatalog.original.id))
                            .accessibilityIdentifier("appearance.applyIcon")
                        Button(L10n.text("恢复默认")) {
                            selectedID = AppIconCatalog.original.id
                            if icons.currentID != selectedID { icons.apply(AppIconCatalog.original) }
                        }
                        .disabled(icons.currentID == AppIconCatalog.original.id && selectedID == icons.currentID)
                        .accessibilityIdentifier("appearance.resetIcon")
                    }
                }
                Text(L10n.text("发现品种即可解锁对应图标，初始与双鱼款默认可用。首次应用需授权；原来已使用的图标继续保留。"))
                    .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
                if let error = icons.error { Text(error).foregroundStyle(PixelTheme.pink).accessibilityIdentifier("appearance.iconError") }
                Text(L10n.text("已解锁 \(AppIconCatalog.all.filter { unlocked($0) }.count) / \(AppIconCatalog.all.count)")).foregroundStyle(PixelTheme.muted)
                HStack(spacing: 6) {
                    ForEach(-1...5, id: \.self) { value in
                        Button(value == -1 ? L10n.text("全部") : value == 0 ? L10n.text("初始") : "\(value)★") { tier = value }
                            .buttonStyle(PixelButtonStyle(primary: tier == value, compact: true, fixedWidth: PixelTheme.filterButtonWidth))
                            .accessibilityIdentifier("appearance.iconTier.\(value)")
                            .accessibilityValue(tier == value ? L10n.text("已选择") : L10n.text("未选择"))
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(AppIconCatalog.filtered(tier: selectedTier)) { design in
                        Button { selectedID = design.id } label: {
                            VStack(spacing: 8) {
                                artwork(design, size: 56).opacity(unlocked(design) || icons.currentID == design.id ? 1 : 0.35)
                                Text(AppIconCatalog.label(design)).foregroundStyle(PixelTheme.text).lineLimit(2).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                                .overlay(alignment: .topTrailing) {
                                    if icons.currentID == design.id {
                                        PixelIcon("check", color: PixelTheme.green).padding(6).accessibilityHidden(true)
                                    } else if !unlocked(design) {
                                        PixelIcon("lock", color: PixelTheme.muted).padding(5).accessibilityHidden(true)
                                    }
                                }.contentShape(Rectangle())
                        }
                        .buttonStyle(IconTileStyle(selected: selectedID == design.id))
                        .accessibilityLabel(AppIconCatalog.label(design))
                        .accessibilityValue(icons.currentID == design.id ? L10n.text("使用中") : !unlocked(design) ? L10n.text("尚未发现") : selectedID == design.id ? L10n.text("已选中") : L10n.text("未选择"))
                        .accessibilityIdentifier("appearance.icon.\(design.id)")
                    }
                }
            }.padding(20).frame(maxWidth: 840).frame(maxWidth: .infinity)
        }
        .onAppear { selectedID = icons.currentID }
    }
    @ViewBuilder private func artwork(_ design: AppIconDesign, size: CGFloat) -> some View {
        if let image = AppIconStore.image(design) {
            Image(nsImage: image).resizable().interpolation(.none).scaledToFit().frame(width: size, height: size)
                .accessibilityHidden(true)
        } else { Rectangle().fill(PixelTheme.card).frame(width: size, height: size).overlay(Text(L10n.text("图标缺失"))) }
    }
}

private struct IconTileStyle: ButtonStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? PixelTheme.panel : PixelTheme.card)
            .clipShape(PixelOutline(cut: 5))
            .overlay(PixelOutline(cut: 5).stroke(selected ? PixelTheme.gold : PixelTheme.shell.opacity(0.45), lineWidth: selected ? 2 : 1).allowsHitTesting(false))
            .contentShape(Rectangle())
    }
}
#endif
