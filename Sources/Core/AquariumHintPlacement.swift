import CoreGraphics

/// Places the interaction hint under the tank, clear of the agent bubbles that
/// stack above it, and moves it over the tank when the bottom edge has no room.
/// A hint wider than a small tank hugs the tank edge nearest its screen corner
/// instead of hanging off both sides.
/// Shares geometry with offscreen validation; tank coordinates and canvas stay unchanged.
enum AquariumHintPlacement {
    static func frame(tank: CGRect, visibleFrame: CGRect, size: CGSize) -> CGRect {
        let gap: CGFloat = 8
        let width = min(max(size.width, tank.width), visibleFrame.width)
        let anchored = tank.midX > visibleFrame.midX ? tank.maxX - width : tank.minX
        let x = min(max(anchored, visibleFrame.minX), visibleFrame.maxX - width)
        var y = tank.minY - gap - size.height
        if y < visibleFrame.minY {
            let above = tank.maxY + gap
            y = above + size.height <= visibleFrame.maxY ? above : max(visibleFrame.minY, visibleFrame.maxY - size.height)
        }
        return CGRect(x: x, y: y, width: width, height: size.height)
    }
}
