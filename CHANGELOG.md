# Changelog

All notable changes to SayRight. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Filters for the places a writing assistant is not wanted.** The bar no longer appears
  in browser address bars, search fields or combo boxes, over selections shorter than a
  configurable minimum, over text with no words in it, or over a lone URL, path or email
  address. The hotkey still reaches all of those, since pressing it is a deliberate answer.
- **Hard blocks that the hotkey cannot override**, because the harm is in the sending:
  fields labelled like a credential (card number, CVV, PIN, one-time code, API key,
  recovery phrase, account number), and text shaped like a Luhn-valid card number, a JWT,
  a PEM private key or an API key.
- **An ignore list of apps**, seeded with password managers, Keychain Access, terminals
  and launchers, editable in Settings with an app picker.
- Every suppressed selection is logged with the rule that fired, so it is possible to see
  why the bar did not appear.

### Fixed

- **Password fields could be read through a descendant element.** The secure-field check
  ran only on the outer focused element, so a password in a Chrome or Electron login form
  was reachable via the `AXFocusedUIElement` hop — and a refusal was indistinguishable
  from a failed read, so the clipboard fallback would then copy it out. Both closed.
- **Granting Accessibility with the onboarding window closed left the app inert** until
  the next relaunch: closing the window stopped the app-wide trust poller.
- **Dismissing the result panel did not cancel the request** behind it, so it completed,
  billed, and announced itself to VoiceOver after the user had moved on.
- **A cancelled request was reported as an error** (`URLError(.cancelled)` is not
  `CancellationError`), flipping a freshly opened panel into "error -999".
- **Replace could paste into the wrong app**: `NSRunningApplication.activate()` returns
  before the app is frontmost. It now waits, and leaves the result on the clipboard
  rather than dropping it if the app never comes forward.
- **Truncated answers were presented as complete.** All three cloud providers now report
  `finish_reason` / `stop_reason`, Anthropic asks for enough output budget, and a cut-off
  result carries a warning and loses its Return-key binding.
- **A hotkey with no ⌃, ⌥ or ⌘ could be recorded**, consuming that key in every app.
  Rejected now, and a combination another app already owns no longer leaves you with no
  hotkey at all while the UI claims success.
- **The clipboard fallback failed in the apps it exists for**: the synthetic ⌘C inherited
  the physically-held hotkey modifiers. It now uses a private event source.
- **A pending clipboard restore could be mistaken for the copy it was racing**, returning
  the previous clipboard contents as the selection.
- **Retry could act on a different selection than the panel was showing.** The selection
  is now passed by value per request; nothing is stored on the coordinator.
- Launch-at-login and hotkey failures are now surfaced instead of silently swallowed, and
  a hotkey chosen before Accessibility is granted is kept rather than discarded.

### Security

- The diagnostics log moved from world-readable `/tmp/sayright.log` to
  `~/Library/Logs/SayRight.log`, created `0600` and capped at 256 KB. Any stale `/tmp`
  copy is deleted on launch.
- The system prompt now tells the model that the selection is text to edit and never an
  instruction to follow, blunting prompt injection from selected web content.
- Settings warns when an OpenAI-compatible base URL would send an API key over plain
  http to a remote host.
- `NSAllowsLocalNetworking` added, so local models work over http while remote cleartext
  stays blocked by App Transport Security.

## [0.1.0] — 2026-09-15

First working version.

### Added

- **Selection-triggered action bar.** A labelled floating bar appears next to text you
  select in any app: Grammar, Rewrite, Shorter, Longer, Formal, Casual.
- **Preview before replacing.** Results appear in a panel with Replace, Copy and Retry;
  the document is never modified until you choose.
- **Changed words in bold** for grammar fixes, with a count, using a word-level diff.
- **Five providers**: Apple's on-device model (free, offline, the default), OpenAI,
  Anthropic, Google Gemini, and any OpenAI-compatible endpoint (Ollama, LM Studio,
  OpenRouter, Groq, vLLM).
- **Model dropdowns** listing each provider's current lineup, editable so a newly
  released model works without an app update.
- **⌃⌥Space hotkey**, configurable, which also works in apps that do not expose their
  selection — including over read-only text, where it offers Copy instead of Replace.
- **Clipboard fallback** with restore, for Chromium, Electron and Word. Only ever used on
  the hotkey path, never automatically.
- **Settings**: provider, API key per provider, model, output language, hotkey, clipboard
  fallback, launch at login.
- **Onboarding** window that requests Accessibility access and notices when it is granted.
- **Accessibility**: words next to every icon, VoiceOver labels, hints and result
  announcements, keyboard operation via the hotkey path, no colour-only status.
- API keys stored in the macOS Keychain, one item per provider.
- Builds with SwiftPM and a `Makefile`; Xcode is not required.

### Security and privacy

- Password fields are never read.
- The automatic path only triggers over editable text.
- Selections over 12,000 characters are refused, to avoid a surprise provider bill.
- No telemetry, analytics, crash reporting or update checks. The only outbound request is
  the provider call you triggered.

### Known limitations

- No live underlining as you type — see the README.
- No streaming output; results appear when complete.
- Prebuilt CI artifacts are unsigned and unnotarized; building from source is recommended.

[Unreleased]: https://github.com/parvsharma13/sayright/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/parvsharma13/sayright/releases/tag/v0.1.0
