import AppKit

/// A panel that floats over other apps without activating SayRight.
///
/// It can become key *on request* so the bar is operable from the keyboard when
/// the user reached it with the hotkey. It deliberately does not when the user
/// got here by dragging a mouse: taking key status then would swallow the next
/// characters they type into their own document.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?
    private var wantsKey = false

    override var canBecomeKey: Bool { wantsKey }

    convenience init(width: CGFloat, height: CGFloat) {
        self.init(contentRect: CGRect(x: 0, y: 0, width: width, height: height),
                  styleMask: [.nonactivatingPanel, .borderless],
                  backing: .buffered,
                  defer: false)
        level = .popUpMenu
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    func present(makeKey: Bool) {
        wantsKey = makeKey
        orderFrontRegardless()
        if makeKey { makeKeyAndOrderFront(nil) }
    }

    /// Escape, wired by AppKit.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
