import AppKit
import SwiftUI

/// The small action bar that appears next to a selection.
@MainActor
final class IconPanel {
    static let shared = IconPanel()

    private var panel: FloatingPanel?
    private var onPick: ((Action) -> Void)?

    private init() {}

    var frame: CGRect? { panel?.frame }
    var isVisible: Bool { panel?.isVisible ?? false }

    func show(near anchor: CGRect, keyboardDriven: Bool = false, onPick: @escaping (Action) -> Void) {
        self.onPick = onPick
        let view = ActionBar { [weak self] action in
            self?.hide()
            self?.onPick?(action)
        }
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        panel.setFrame(PanelPlacement.frame(size: size, anchor: anchor, screens: PanelPlacement.visibleScreens),
                       display: true)
        panel.onCancel = { [weak self] in self?.hide() }
        panel.present(makeKey: keyboardDriven)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> FloatingPanel { FloatingPanel(width: 1, height: 1) }
}

private struct ActionBar: View {
    let pick: (Action) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Action.allCases) { action in
                Button { pick(action) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: action.symbol)
                            .imageScale(.small)
                        Text(action.shortTitle)
                            .font(.callout)
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .contentShape(.rect)
                }
                .buttonStyle(.accessoryBar)
                .help("\(action.title) — \(action.help)")
                .accessibilityLabel(action.title)
                .accessibilityHint(action.help)

                if action != Action.allCases.last {
                    Divider().frame(height: 14)
                }
            }
        }
        .padding(4)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("SayRight actions for the selected text")
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator))
        .fixedSize()
    }
}
