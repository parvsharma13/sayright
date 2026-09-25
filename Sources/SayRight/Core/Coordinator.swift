import AppKit
import Observation

/// Owns the whole interaction: selection -> icon -> model -> result -> replace.
@MainActor
@Observable
final class Coordinator {
    static let shared = Coordinator()

    /// Guards against a stray Select All costing real money at a cloud provider.
    private let maxCharacters = 12_000

    /// Drives the menu bar icon while a request is in flight.
    private(set) var isBusy = false

    private var task: Task<Void, Never>?
    /// Bumped per request, so a superseded one cannot report state for its successor.
    private var generation = 0

    private init() {}

    private static func frontmostName() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown app"
    }

    func start() {
        let monitor = SelectionMonitor.shared
        monitor.onSelection = { [weak self] selection in self?.present(selection) }
        monitor.onDismiss = { [weak self] causedByClick in self?.dismiss(causedByClick: causedByClick) }
        monitor.start()
        HotkeyStore.shared.install { [weak self] in self?.triggerManually() }
    }

    /// Hotkey and menu path: allowed to use the clipboard fallback, because the
    /// user asked for this exact moment.
    func triggerManually() {
        // Deliberately permissive: asking for it explicitly over read-only text, a
        // search box or an address bar is a reasonable thing to do. Only the hard
        // filters - password fields, ignored apps, secrets - still apply.
        guard let selection = SelectionReader.read(.manual) else {
            dbg("manual trigger in \(Self.frontmostName()): no selection found")
            NSSound.beep()
            return
        }
        present(selection, keyboardDriven: true)
    }

    /// The selection is passed down by value from here on. Nothing is stored on the
    /// Coordinator, so a panel can never act on a selection other than its own.
    private func present(_ selection: TextSelection, keyboardDriven: Bool = false) {
        // A new selection invalidates whatever the last one produced.
        ResultPanel.shared.dismiss()
        dbg("selection in \(Self.frontmostName()): \(selection.text.count) chars, ax=\(selection.element != nil), rect=\(selection.rect)")
        IconPanel.shared.show(near: selection.rect, keyboardDriven: keyboardDriven) { [weak self] action in
            self?.run(action, on: selection, keyboardDriven: keyboardDriven)
        }
    }

    private func run(_ action: Action, on selection: TextSelection, keyboardDriven: Bool) {
        let settings = Settings.shared

        ResultPanel.shared.show(
            action: action,
            providerName: settings.provider.displayName,
            original: selection.text,
            anchor: selection.rect,
            canReplace: selection.isEditable,
            keyboardDriven: keyboardDriven,
            handlers: .init(
                replace: { text in TextWriter.replace(text, in: selection) },
                retry: { [weak self] in self?.run(action, on: selection, keyboardDriven: keyboardDriven) },
                cancel: { [weak self] in self?.cancelRequest() }
            )
        )

        guard selection.text.count <= maxCharacters else {
            ResultPanel.shared.fail("That selection is \(selection.text.count) characters. SayRight stops at \(maxCharacters) to avoid a surprise bill - select less.")
            return
        }

        task?.cancel()
        generation += 1
        let generation = generation
        isBusy = true
        task = Task {
            defer { if generation == self.generation { isBusy = false } }
            do {
                let provider = try ProviderFactory.make(settings)
                let completion = try await provider.complete(
                    system: action.systemPrompt(outputLanguage: settings.outputLanguage),
                    user: selection.text
                )
                guard !Task.isCancelled else { return }
                ResultPanel.shared.finish(with: completion)
            } catch {
                // A cancelled URLSession throws URLError(.cancelled), not
                // CancellationError, and reporting that as a failure would flip a
                // freshly opened panel into "error -999".
                guard !Task.isCancelled, !error.isCancellation else { return }
                ResultPanel.shared.fail(error.localizedDescription)
            }
        }
    }

    /// Clicks on our own panels are delivered to SayRight and never reach the
    /// global monitor, but a non-activating panel makes that easy to get wrong -
    /// so check the pointer before tearing the UI down.
    func cancelRequest() {
        task?.cancel()
        task = nil
        generation += 1
        isBusy = false
    }

    private func dismiss(causedByClick: Bool) {
        // Only a click has a meaningful pointer position; a keystroke elsewhere should
        // dismiss regardless of where the pointer happens to be resting.
        if causedByClick {
            let point = NSEvent.mouseLocation
            if IconPanel.shared.isVisible, IconPanel.shared.frame?.contains(point) == true { return }
            if ResultPanel.shared.isVisible, ResultPanel.shared.frame?.contains(point) == true { return }
        }
        IconPanel.shared.hide()
        ResultPanel.shared.hide()
        cancelRequest()
    }
}
