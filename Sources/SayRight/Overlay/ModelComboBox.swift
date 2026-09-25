import AppKit
import SwiftUI

/// Dropdown of known models that you can also type into, because any hardcoded
/// list goes stale the moment a provider ships something new. SwiftUI has no
/// combo box, so this wraps the AppKit one.
struct ModelComboBox: NSViewRepresentable {
    let options: [String]
    let value: String
    let onChange: (String) -> Void

    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.completes = true
        box.delegate = context.coordinator
        box.isEditable = true
        box.usesDataSource = false
        return box
    }

    func updateNSView(_ box: NSComboBox, context: Context) {
        context.coordinator.onChange = onChange
        if box.objectValues as? [String] != options {
            box.removeAllItems()
            box.addItems(withObjectValues: options)
        }
        if box.stringValue != value, !context.coordinator.isEditing {
            box.stringValue = value
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var onChange: (String) -> Void
        var isEditing = false

        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox,
                  let picked = box.objectValueOfSelectedItem as? String else { return }
            // stringValue has not caught up yet when a row is picked.
            onChange(picked)
        }

        func controlTextDidBeginEditing(_ notification: Notification) { isEditing = true }

        func controlTextDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            onChange(box.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) { isEditing = false }
    }
}
