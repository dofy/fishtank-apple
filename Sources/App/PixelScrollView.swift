#if os(macOS)
import AppKit
import SwiftUI

/// A scroll view with the pixel marker instead of the AppKit scroller.
/// `scrollIndicators(.hidden)` leaves the legacy scroller in place when the system
/// shows scroll bars always, and that scroller reserves layout width.
struct PixelScrollView<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var metrics = ScrollMetrics()
    @State private var space = "pixel.scroll." + UUID().uuidString

    var body: some View {
        ScrollView {
            content
                .background(reader)
                // Inside the content, so the view can reach the enclosing NSScrollView.
                .background(ScrollerHider())
        }
        .scrollIndicators(.hidden)
        .coordinateSpace(name: space)
        .overlay(alignment: .topTrailing) { marker }
    }

    private var reader: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(space))
            Color.clear
                .onAppear { metrics = ScrollMetrics(offset: -frame.minY, content: frame.height) }
                .onChange(of: frame) { value in metrics = ScrollMetrics(offset: -value.minY, content: value.height) }
        }
    }

    @ViewBuilder private var marker: some View {
        GeometryReader { proxy in
            let viewport = proxy.size.height
            let content = max(metrics.content, viewport)
            if content > viewport + 1 {
                let span = max(28, viewport * viewport / content)
                let travel = max(0, viewport - span)
                let progress = min(max(metrics.offset / (content - viewport), 0), 1)
                Rectangle().fill(PixelTheme.highlight.opacity(0.45))
                    .frame(width: 3, height: span)
                    .offset(x: proxy.size.width - 6, y: travel * progress)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var content: CGFloat = 0
}

private struct ScrollerHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ScrollerHidingView(frame: .zero) }
    func updateNSView(_ view: NSView, context: Context) { (view as? ScrollerHidingView)?.hideScroller() }
}

/// Hiding happens as the view joins the hierarchy. Switching pages rebuilds the
/// scroll view, and a deferred pass would show the system scroller for one frame.
private final class ScrollerHidingView: NSView {
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); hideScroller() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); hideScroller() }
    override func layout() { super.layout(); hideScroller() }

    func hideScroller() {
        var next: NSView? = superview
        while let current = next, !(current is NSScrollView) { next = current.superview }
        guard let scroll = next as? NSScrollView else { return }
        scroll.scrollerStyle = .overlay
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.verticalScroller?.isHidden = true
        scroll.scrollerInsets = NSEdgeInsets()
    }
}
#endif
