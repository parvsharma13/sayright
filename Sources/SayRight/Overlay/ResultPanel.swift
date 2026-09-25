import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ResultState {
    enum Phase {
        case loading
        case done(String)
        case failed(String)
    }

    var phase: Phase = .loading
    var action: Action = .fixGrammar
    var providerName: String = ""
    /// False for read-only text reached via the hotkey: Copy is the only honest option.
    var canReplace = true
    /// What the user had, for the changed-word highlighting.
    var original = ""
    /// Set when the answer was cut off, so Replace is not offered as if it were whole.
    var warning: String?
}

/// Shows what the model came back with, and only then touches the user's document.
@MainActor
final class ResultPanel {
    static let shared = ResultPanel()

    let state = ResultState()
    private var panel: FloatingPanel?
    private var hosting: NSView?
    private var anchor: CGRect = .zero
    private var handlers: Handlers?

    struct Handlers {
        let replace: (String) -> Void
        let retry: () -> Void
        /// Called when the user dismisses the panel, so the in-flight request can be
        /// dropped instead of billing for an answer nobody will see.
        let cancel: () -> Void
    }

    private init() {}

    var frame: CGRect? { panel?.frame }
    var isVisible: Bool { panel?.isVisible ?? false }

    func show(action: Action, providerName: String, original: String, anchor: CGRect,
              canReplace: Bool = true, keyboardDriven: Bool = false, handlers: Handlers) {
        self.handlers = handlers
        state.action = action
        state.providerName = providerName
        state.canReplace = canReplace
        state.original = original
        state.warning = nil
        state.phase = .loading
        self.anchor = anchor

        let panel = self.panel ?? makePanel()
        self.panel = panel

        // NSWindow always hands out a contentView of its own, so this has to be an
        // unconditional assignment - checking for nil silently left the panel empty.
        if hosting == nil {
            let view = NSHostingView(rootView: ResultView(
                state: state,
                replace: { [weak self] text in
                    self?.hide()
                    self?.handlers?.replace(text)
                },
                retry: { [weak self] in self?.handlers?.retry() },
                close: { [weak self] in self?.dismiss() }
            ))
            hosting = view
            panel.contentView = view
        }

        layout()
        panel.onCancel = { [weak self] in self?.dismiss() }
        panel.present(makeKey: keyboardDriven)
    }

    func finish(with completion: Completion) {
        state.warning = completion.truncated
            ? "The model ran out of room and this answer is cut off. Retry with less text selected, or copy it instead of replacing."
            : nil
        state.phase = .done(completion.text)
        relayout()
        let text = completion.text
        let edits = state.action.showsDiff
            ? Diff.changes(from: state.original, to: text).count(where: \.changed)
            : 0
        let summary = state.action.showsDiff ? "\(edits) changes. " : ""
        announce("\(state.action.title) ready. \(summary)\(text)")
    }

    func fail(_ message: String) {
        state.phase = .failed(message)
        relayout()
        announce("\(state.action.title) failed. \(message)")
    }

    /// The panel usually is not key, so VoiceOver would otherwise never mention
    /// that an answer arrived.
    private func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [.announcement: message,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Closing by hand also abandons the request behind it.
    func dismiss() {
        handlers?.cancel()
        hide()
    }

    func hide() { panel?.orderOut(nil) }

    /// The panel grows from a one-line spinner to however tall the result is.
    private func layout() {
        guard let panel, let hosting else { return }
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        size.width = Self.width
        size.height = max(size.height, 64)
        panel.setFrame(PanelPlacement.frame(size: size, anchor: anchor, screens: PanelPlacement.visibleScreens),
                       display: true)
    }

    /// SwiftUI has not re-laid-out yet at the moment the phase changes.
    private func relayout() {
        DispatchQueue.main.async { [weak self] in self?.layout() }
    }

    static let width: CGFloat = 420

    private func makePanel() -> FloatingPanel { FloatingPanel(width: Self.width, height: 64) }
}

private struct ResultView: View {
    let state: ResultState

    /// Bold, not colour: it survives Increase Contrast and reads the same to
    /// anyone who cannot distinguish the highlight colour.
    static func highlighted(_ tokens: [Diff.Token]) -> AttributedString {
        var result = AttributedString()
        for token in tokens {
            var piece = AttributedString(token.text)
            if token.changed { piece.font = .body.bold() }
            result += piece
        }
        return result
    }

    let replace: (String) -> Void
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: state.action.symbol)
                Text(state.action.title).bold()
                    .help(state.action.help)
                    .accessibilityAddTraits(.isHeader)
                Text(state.providerName).foregroundStyle(.secondary).font(.caption)
                    .help("The provider this result came from. Change it in Settings.")
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.accessoryBar)
                    .help("Close without changing your text")
                    .accessibilityLabel("Close")
            }

            switch state.phase {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Working on it…").foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", action: close)
                        .buttonStyle(.accessoryBar)
                        .help("Stop this request and close")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .done(let text):
                let diff = state.action.showsDiff
                    ? Diff.changes(from: state.original, to: text)
                    : []
                let editCount = diff.count(where: \.changed)

                ScrollView {
                    Group {
                        if diff.isEmpty {
                            Text(text)
                        } else {
                            Text(Self.highlighted(diff))
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                .accessibilityLabel("Suggested text")
                .accessibilityValue(text)

                if let warning = state.warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if state.action.showsDiff {
                    Text(editCount == 0 ? "No changes needed."
                         : editCount == 1 ? "1 change, in bold."
                         : "\(editCount) changes, in bold.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    if state.canReplace {
                        Button("Replace") { replace(text) }
                            .buttonStyle(.borderedProminent)
                            // A truncated answer is not the safe default: Return should
                            // not overwrite the document with a cut-off sentence.
                            .keyboardShortcut(state.warning == nil
                                              ? .defaultAction
                                              : KeyboardShortcut("r", modifiers: .command))
                            .help(state.warning == nil
                                  ? "Put this text back over your selection (Return)"
                                  : "Put this cut-off text back over your selection (⌘R)")
                    }
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        close()
                    }
                    .help("Copy to the clipboard and close, leaving your text alone")
                    // Return replaces when that is safe, and copies when it is not.
                    .keyboardShortcut(state.canReplace && state.warning == nil
                                      ? KeyboardShortcut("c", modifiers: .command)
                                      : .defaultAction)
                    Button("Retry", action: retry)
                        .help("Ask the model again")
                    Spacer()
                    if !state.canReplace {
                        Label("Read-only", systemImage: "lock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("That text cannot be edited in place, so only Copy is offered.")
                    }
                }

            case .failed(let message):
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Retry", action: retry)
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(width: ResultPanel.width, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("SayRight result")
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
    }
}
