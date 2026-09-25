import AppKit

enum PanelPlacement {
    /// Puts a panel of `size` just above `anchor` (the selected text), flipping below
    /// it when there is no room, and keeping the whole panel on one screen.
    /// All coordinates are AppKit screen coordinates.
    static func frame(size: CGSize, anchor: CGRect, screens: [CGRect], gap: CGFloat = 8) -> CGRect {
        let screen = screens.first { $0.intersects(anchor) }
            ?? screens.first { $0.contains(anchor.origin) }
            ?? screens.first
            ?? CGRect(x: 0, y: 0, width: size.width, height: size.height)

        var origin = CGPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + gap)

        if origin.y + size.height > screen.maxY {
            origin.y = anchor.minY - size.height - gap   // no room above: go below
        }
        origin.y = min(max(origin.y, screen.minY), screen.maxY - size.height)
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        return CGRect(origin: origin, size: size)
    }

    static var visibleScreens: [CGRect] { NSScreen.screens.map(\.visibleFrame) }
}
