import AppKit
import SwiftUI

/// Click, then press a combination. Stores the raw keyCode + Carbon modifiers.
struct HotkeyRecorder: NSViewRepresentable {
    let onRecord: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.onRecord = onRecord
        view.title = HotkeyStore.shared.description
    }

    final class RecorderView: NSButton {
        var onRecord: ((UInt32, UInt32) -> Void)?
        private var listening = false

        init() {
            super.init(frame: .zero)
            bezelStyle = .rounded
            title = HotkeyStore.shared.description
            target = self
            action = #selector(startListening)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        @objc private func startListening() {
            listening = true
            title = "Press keys…"
            window?.makeFirstResponder(self)
        }

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard listening else { return super.keyDown(with: event) }
            listening = false
            if event.keyCode == 53 { // Escape cancels
                title = HotkeyStore.shared.description
                return
            }
            onRecord?(UInt32(event.keyCode), HotkeyStore.carbonModifiers(from: event.modifierFlags))
            title = HotkeyStore.shared.description
        }
    }
}
