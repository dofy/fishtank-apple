import Foundation
import CoreGraphics

/// AppKit desktop points (origin at bottom left), never backing pixels.
struct AquariumDisplayGeometry {
    var frame: CGRect
    var visibleFrame: CGRect
}

/// The mouse-down anchor stays fixed, including while a boundary is being pressed.
struct AquariumWindowDrag {
    let initialFrame: CGRect
    let mouseDown: CGPoint

    func frame(at mouse: CGPoint, displays: [AquariumDisplayGeometry]) -> CGRect {
        var proposed = initialFrame.offsetBy(dx: mouse.x - mouseDown.x, dy: mouse.y - mouseDown.y)
        // Use the pointer's column: a vertical crossing is possible only where the
        // physical displays share a horizontal portal. A lower side monitor must
        // not remove the floor from an unrelated part of the upper display.
        let column = displays.filter { mouse.x >= $0.frame.minX && mouse.x < $0.frame.maxX }
            .sorted { $0.frame.minY < $1.frame.minY }
        guard !column.isEmpty else { return proposed }

        var components: [[AquariumDisplayGeometry]] = []
        for display in column {
            if let last = components.last,
               display.frame.minY <= last.map(\.frame.maxY).max()! + 0.5 {
                components[components.count - 1].append(display)
            } else {
                components.append([display])
            }
        }
        // Prefer the component containing the pointer; nearest is a deterministic
        // fallback for restored/synthetic coordinates in a gap between displays.
        let component = components.min { a, b in
            func distance(_ group: [AquariumDisplayGeometry]) -> CGFloat {
                let lower = group.map(\.frame.minY).min()!
                let upper = group.map(\.frame.maxY).max()!
                return max(lower - mouse.y, mouse.y - upper, 0)
            }
            return distance(a) < distance(b)
        }!
        let physicalBottom = component.map(\.frame.minY).min()!
        let physicalTop = component.map(\.frame.maxY).max()!
        // Dock/menu-bar insets matter only at outer desktop edges. Insets at an
        // internal seam must not block entry to the display above or below.
        let bottom = component.filter { abs($0.frame.minY - physicalBottom) < 0.5 }
            .map(\.visibleFrame.minY).max()!
        let top = component.filter { abs($0.frame.maxY - physicalTop) < 0.5 }
            .map(\.visibleFrame.maxY).min()!
        // Keep the canvas size unchanged; if it cannot fit, prioritize its bottom.
        proposed.origin.y = max(bottom, min(proposed.minY, max(bottom, top - proposed.height)))
        return proposed
    }
}

/// AppKit may remap autosaved positions to the main display. Keep a reachable
/// desktop coordinate intact, including monitors below or left of the primary.
enum AquariumWindowPlacement {
    static func restoredOrigin(from saved: String?, size: CGSize, displays: [AquariumDisplayGeometry]) -> CGPoint? {
        guard let saved else { return nil }
        let parts = saved.split(whereSeparator: { $0.isWhitespace }).prefix(4)
        let values = parts.compactMap { Double($0) }
        guard values.count == 4, values.allSatisfy(\.isFinite), values[2] > 0, values[3] > 0,
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
        let origin = CGPoint(x: values[0], y: values[1])
        let frame = CGRect(origin: origin, size: size)
        return displays.contains(where: { $0.visibleFrame.intersects(frame) }) ? origin : nil
    }
}
