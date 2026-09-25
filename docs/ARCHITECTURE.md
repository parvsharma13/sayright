# Architecture

How SayRight works, and why the unusual parts are the way they are. Read this before
changing anything in `Capture/` or `Overlay/` — that is where the sharp edges live.

## The flow

```
   user selects text
          │
          ▼
  SelectionMonitor ──── global NSEvent monitor: mouse-up, shift+key-up
          │             120 ms debounce
          ▼
  SelectionReader ───── AXUIElementCreateSystemWide
          │             → kAXFocusedUIElement
          │             → kAXSelectedText            (the text)
          │             → kAXSelectedTextRange       (where in the text)
          │             → kAXBoundsForRange          (where on screen)
          │             → is AXSelectedText settable? (editable at all?)
          ▼
    Coordinator ─────── owns the interaction, holds the TextSelection
          │
          ├──▶ IconPanel ────── the labelled action bar, next to the selection
          │         │
          │         ▼ user picks an action
          │
          ├──▶ ProviderFactory → Provider.complete(system:user:)
          │                       Apple / OpenAI / Anthropic / Gemini / custom
          │
          ├──▶ ResultPanel ──── spinner, then the answer, with a word-level Diff
          │         │
          │         ▼ user clicks Replace
          │
          └──▶ TextWriter ───── AXUIElementSetAttributeValue(kAXSelectedText)
                                falling back to a synthetic ⌘V
```

## Layout

```
Sources/SayRight/
  SayRightApp.swift      @main, MenuBarExtra, AppDelegate
  Core/                  pure logic — no AppKit dependencies worth speaking of
    Action.swift           the six actions and their prompts
    Coordinator.swift      the flow above, in one place
    Diff.swift             word-level diff for the bold highlighting
    Settings.swift         preferences + ProviderKind and its model lists
    Keychain.swift         four functions over SecItem
    KeyStore.swift         observable mirror of the Keychain, for SwiftUI
    HotkeyStore.swift      the stored hotkey and how to render it (⌃⌥Space)
    WindowHost.swift       shows SwiftUI views in real windows from an agent app
  Capture/               talks to other apps
    AX.swift               typed wrappers over the C Accessibility API
    Selection.swift        reads the selection, decides if it is editable
    SelectionMonitor.swift watches for the end of a selection gesture
    TextWriter.swift       writes the result back
    ClipboardCapture.swift the ⌘C / ⌘V fallback, with clipboard restore
    Hotkey.swift           Carbon RegisterEventHotKey
    Permissions.swift      Accessibility trust, and polling for it
  Overlay/               the UI
    FloatingPanel.swift   non-activating panel shared by both popups
    IconPanel.swift       the action bar
    ResultPanel.swift     the preview, Replace / Copy / Retry
    PanelPlacement.swift  pure geometry: where a panel goes near a selection
    SettingsView.swift    the settings form
    OnboardingView.swift  first-run permission screen
    ModelComboBox.swift   editable model dropdown (AppKit NSComboBox)
    HotkeyRecorder.swift  click-then-press-keys control
  Providers/             networking, one file per provider
Tests/SayRightTests/     unit tests for everything pure
```

Only `Capture/` and `Overlay/` touch other applications or the screen. Everything in
`Core/` and `Providers/` is testable without a window server, which is why the test suite
runs in CI.

## Decisions that look strange

### No `@State`, `@Environment` or `@Binding` anywhere

In the macOS 27 SDK these are **macros**, backed by a `SwiftUIMacros` plugin that ships
only with Xcode. A Command-Line-Tools build cannot expand them, and the compiler error is
opaque if you do not know why.

So all state lives in `@Observable` classes — SwiftUI tracks those automatically when
`body` reads them, no property wrapper needed — and bindings are built by hand:

```swift
Toggle("Launch at login", isOn: Binding(
    get: { SMAppService.mainApp.status == .enabled },
    set: { ... }
))
```

The Observation and swift-testing macro plugins *are* in CLT, so `@Observable` and
`@Test` are fine. If you add a view, follow the same pattern or it will not compile for
contributors without Xcode.

### `swift test` needs a plugin flag

CLT hides `libTestingMacros.dylib` in a `plugins/testing/` subdirectory that is not on
the default plugin search path. The `Makefile` finds it and passes
`-load-plugin-library`. With full Xcode the flag is unnecessary and the `Makefile`
omits it.

### Carbon `RegisterEventHotKey`, not an `NSEvent` monitor

A global `NSEvent` monitor observes keystrokes but does not consume them, so ⌃⌥Space
would also type a space into whatever you were writing. Carbon's hotkey API is old, ugly
and correct.

### Non-activating `NSPanel`, not a SwiftUI window

The bar must appear without taking focus from the app you are typing in, which
`.nonactivatingPanel` gives. Consequences to know about:

- **Tooltips do not fire.** AppKit will not run the tooltip timer for a panel that never
  becomes key in a background app. This is why every action is labelled in words instead.
- **The panel is invisible to VoiceOver navigation** unless it is key, which is why the
  result is *announced* via `NSAccessibility.post`.
- It becomes key **only** when the user arrived via the hotkey — taking key status on a
  mouse-driven selection would swallow the next characters they type.

### The element is captured, not looked up again

`TextSelection` holds the `AXUIElement` and the character range from the moment the
selection was read. Re-resolving "the focused element" at Replace time would write into
whatever the user clicked on since. This has bitten the project once already; do not
change it.

### Accessibility coordinates are flipped, relative to the origin display

`kAXPositionAttribute` and `kAXBoundsForRange` are measured from the **top-left of the
display at (0,0)**, y increasing downwards. AppKit windows are bottom-left origin, y up.
`AX.flipToScreenCoordinates` converts, and looks up the origin display explicitly —
`NSScreen.screens.first` is *not* guaranteed to be it, and assuming so throws every
rectangle onto the wrong monitor.

### The clipboard fallback is opt-in per call

`SelectionReader.read(allowClipboardFallback:)` defaults to `false`. The automatic
mouse-up path must never pass `true`: it runs on every mouse-up system-wide, and
synthesising ⌘C that often would be hostile. Only the hotkey and menu paths ask for it.

## Adding things

Both of the common extensions are deliberately small. See
[CONTRIBUTING.md](../CONTRIBUTING.md#adding-an-action) for the step-by-step.

- **A new action** is a case in `Action` plus four strings (title, bar label, symbol,
  prompt). No wiring.
- **A new provider** is one type conforming to `TextProvider`, one case in
  `ProviderKind`, and one line in `ProviderFactory`.

## Testing

`make test` covers what can be tested without a screen: prompt construction, every
provider's request shape and response parsing, error extraction, the diff (including the
invariant that rendering reproduces the model's text exactly), panel geometry across
multiple displays, the editable-role list, and model-list consistency.

Anything that needs a real selection in a real app cannot be automated here — the manual
matrix is in [TROUBLESHOOTING.md](TROUBLESHOOTING.md#app-compatibility).
