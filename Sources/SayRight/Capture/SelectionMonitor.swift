import AppKit

/// Watches for the end of a selection gesture anywhere on the system.
///
/// Event-driven rather than polled: nothing runs until the user releases the
/// mouse or lets go of a shift-arrow. Global monitors never see events aimed at
/// SayRight itself, so clicks on our own panels do not come through here.
@MainActor
final class SelectionMonitor {
    static let shared = SelectionMonitor()

    /// Long enough for the host app to publish the new selection, short enough to feel instant.
    private let debounce: TimeInterval = 0.12

    private var monitors: [Any] = []
    private var pending: DispatchWorkItem?

    var onSelection: ((TextSelection) -> Void)?
    /// `causedByClick` is false for keystrokes, which have no pointer position.
    var onDismiss: ((_ causedByClick: Bool) -> Void)?

    private init() {}

    func start() {
        guard monitors.isEmpty else { return }
        add(.leftMouseUp) { [weak self] _ in self?.scheduleRead() }
        add(.keyUp) { [weak self] event in
            if event.modifierFlags.contains(.shift) { self?.scheduleRead() }
        }
        add([.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.dismiss(causedByClick: true) }
        add(.keyDown) { [weak self] event in
            // Typing means the user has moved on; extending a selection does not.
            if !event.modifierFlags.contains(.shift) { self?.dismiss(causedByClick: false) }
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func add(_ mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            monitors.append(monitor)
        }
    }

    private func dismiss(causedByClick: Bool) {
        pending?.cancel()
        onDismiss?(causedByClick)
    }

    private func scheduleRead() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let selection = SelectionReader.read(.automatic) else {
                self?.onDismiss?(false)
                return
            }
            self?.onSelection?(selection)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }
}
