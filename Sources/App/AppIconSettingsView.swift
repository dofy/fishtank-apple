#if os(macOS)
import SwiftUI

struct AppIconSettingsView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject var icons: AppIconStore
    @ObservedObject var store: AquariumStore
    @State private var selectedID = AppIconCatalog.original.id
    @State private var tier = -1
    private var selectedTier: Int? { tier < 0 ? nil : tier }
    private var available: [AppIconDesign] { AppIconCatalog.filtered(discovered: store.state.discovered) }
    private var selected: AppIconDesign { available.first { $0.id == selectedID } ?? available.first ?? AppIconCatalog.original }
    private func unlocked(_ design: AppIconDesign) -> Bool { AppIconCatalog.isUnlocked(design, discovered: store.state.discovered) }
    private var applyTitle: String {
        return icons.currentID == selected.id ? L10n.text("Apply Again") : L10n.text("Use This Icon")
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !available.isEmpty { HStack(alignment: .center, spacing: 20) {
                    artwork(selected, size: 64)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("App Icon")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
                        Text(selected.name).foregroundStyle(PixelTheme.text)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Button(applyTitle) { icons.apply(selected) }
                            .disabled(!unlocked(selected) || (icons.currentID == selected.id && selected.id == AppIconCatalog.original.id))
                            .accessibilityIdentifier("appearance.applyIcon")
                        Button(L10n.text("Restore Defaults")) {
                            selectedID = AppIconCatalog.original.id
                            if icons.currentID != selectedID { icons.apply(AppIconCatalog.original) }
                        }
                        .disabled(!unlocked(AppIconCatalog.original) || (icons.currentID == AppIconCatalog.original.id && selected.id == icons.currentID))
                        .accessibilityIdentifier("appearance.resetIcon")
                    }
                } }
                Text(L10n.text("Icons appear after you discover their species. The first change needs permission; your current icon is kept."))
                    .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
                if let error = icons.error { Text(error).foregroundStyle(PixelTheme.pink).accessibilityIdentifier("appearance.iconError") }
                Text(L10n.text("\(available.count) icons discovered")).foregroundStyle(PixelTheme.muted)
                HStack(spacing: 6) {
                    ForEach(-1...5, id: \.self) { value in
                        Button(value == -1 ? L10n.text("All") : value == 0 ? L10n.text("Starter") : "\(value)★") { tier = value }
                            .buttonStyle(PixelButtonStyle(primary: tier == value, compact: true, fixedWidth: PixelTheme.filterButtonWidth))
                            .accessibilityIdentifier("appearance.iconTier.\(value)")
                            .accessibilityValue(tier == value ? L10n.text("Selected [choice]") : L10n.text("None Selected"))
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(AppIconCatalog.filtered(tier: selectedTier, discovered: store.state.discovered)) { design in
                        Button { selectedID = design.id } label: {
                            VStack(spacing: 8) {
                                artwork(design, size: 56)
                                Text(AppIconCatalog.label(design)).foregroundStyle(PixelTheme.text).lineLimit(2).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                                .overlay(alignment: .topTrailing) {
                                    if icons.currentID == design.id {
                                        PixelIcon("check", color: PixelTheme.green).padding(6).accessibilityHidden(true)
                                    }
                                }.contentShape(Rectangle())
                        }
                        .buttonStyle(IconTileStyle(selected: selectedID == design.id))
                        .accessibilityLabel(AppIconCatalog.label(design))
                        .accessibilityValue(icons.currentID == design.id ? L10n.text("In Use") : selectedID == design.id ? L10n.text("Selected") : L10n.text("None Selected"))
                        .accessibilityIdentifier("appearance.icon.\(design.id)")
                    }
                }
            }.padding(20).frame(maxWidth: 840).frame(maxWidth: .infinity)
        }
        .onAppear { selectedID = available.first { $0.id == icons.currentID }?.id ?? selected.id }
        .onChange(of: store.state.discovered) { _ in selectedID = selected.id }
    }
    @ViewBuilder private func artwork(_ design: AppIconDesign, size: CGFloat) -> some View {
        if let image = AppIconStore.image(design) {
            Image(nsImage: image).resizable().interpolation(.none).scaledToFit().frame(width: size, height: size)
                .accessibilityHidden(true)
        } else { Rectangle().fill(PixelTheme.card).frame(width: size, height: size).overlay(Text(L10n.text("Icon Missing"))) }
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
