#if os(macOS)
import SwiftUI

/// A stable two-line status surface shared by all six manual pages.
struct AquariumFooter<Actions: View>: View {
    let title: String
    let detail: String
    var emphasized = false
    @ViewBuilder var actions: Actions
    @ObservedObject private var localization = AppLocalization.shared
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(PixelTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(height: 18)
                    .accessibilityIdentifier("footer.title")
                Text(detail).foregroundStyle(emphasized ? PixelTheme.gold : PixelTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(height: 18)
                    .accessibilityIdentifier("footer.detail")
            }
            .font(PixelTheme.captionFont()).lineLimit(1).truncationMode(.tail)
            .help(title + "\n" + detail)
            .frame(maxWidth: .infinity, alignment: .leading)
            actions.buttonStyle(PixelButtonStyle(compact: true))
                .fixedSize(horizontal: true, vertical: false).layoutPriority(1)
        }
        .padding(.horizontal, 12).frame(height: 64)
        .frame(maxWidth: .infinity).background(PixelTheme.panel)
        .overlay(alignment: .top) { Rectangle().fill(PixelTheme.highlight.opacity(0.25)).frame(height: 1).allowsHitTesting(false) }
        .accessibilityElement(children: .contain)
    }
}
#endif
