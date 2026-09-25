# Troubleshooting

## Nothing happens at all

1. Is it running? The menu bar icon should be there. `pgrep -x SayRight` confirms.
2. Is Accessibility granted? Menu bar ▸ it will offer *"Grant Accessibility Access…"*
   if not. Check **System Settings ▸ Privacy & Security ▸ Accessibility**.
3. If SayRight is listed **and** switched on but still does nothing, remove it from that
   list with the **−** button, then relaunch and grant again. A stale entry from an
   earlier signature is the usual cause.

## The Accessibility permission resets every time I rebuild

You skipped `make cert`. Ad-hoc signatures change on every build, so macOS treats each
build as a different app. Run `make cert` once, then `make install`, then grant access
one final time. See [SETUP.md](SETUP.md#3-create-a-signing-certificate-once).

## The bar doesn't appear in a particular app

First, check it is not one of the places the bar stays out of on purpose:

| Where | Why | Hotkey still works? |
|---|---|---|
| Read-only text — page body, transcripts, code listings | Nothing to replace | Yes, with Copy |
| Browser address bar, search field, combo box | Not prose | Yes |
| Selections under 3 characters, or with no words in them | Usually a stray double-click | Yes |
| A lone URL, file path or email address | Nothing to fix | Yes |
| Password fields, or a field labelled like a card number, CVV, PIN, one-time code or API key | The text must not be sent anywhere | **No, never** |
| Text that looks like a card number, JWT, private key or API key | As above | **No, never** |
| Password managers, Keychain Access, terminals, launchers | On the default ignore list | **No** — remove the app in Settings first |

Every one of these is logged with its reason, so you can see which rule fired:

```sh
tail -f ~/Library/Logs/SayRight.log
# not shown automatically in Safari: address bar
# blocked in Chrome: field looks like a credential or card number
```

The minimum length and the app list are yours to change in **Settings ▸ Where not to
appear**.

If it is a genuine prose text box and none of those apply, the app is not publishing its
selection over the Accessibility API. Use ⌃⌥Space, which falls back to copying.

### App compatibility

| App | Bar on selection | Notes |
|---|---|---|
| TextEdit, Notes, Mail, Pages | ✅ | |
| Safari (form fields, `contenteditable`) | ✅ | |
| Chrome, Edge, Brave | ⚠️ | Often needs ⌃⌥Space |
| VS Code, Slack, Discord, other Electron | ⚠️ | Often needs ⌃⌥Space |
| Microsoft Word, Excel | ⚠️ | Needs ⌃⌥Space |
| Terminal, iTerm | ⚠️ | Read-only by SayRight's definition; ⌃⌥Space + Copy |
| Password fields | 🚫 | Ignored on purpose, always |

### Reporting an app that should work

SayRight logs the accessibility role it saw whenever it ignores a selection:

```sh
tail -f ~/Library/Logs/SayRight.log
# read-only selection ignored in Code: role=AXGroup
```

Open an issue with that line and the app version. The role tells us whether the check can
be widened safely.

## "Turn on Apple Intelligence in System Settings, or pick another provider"

The on-device model needs Apple Intelligence enabled in **System Settings ▸ Apple
Intelligence & Siri**, on a Mac that supports it. The model then downloads in the
background; until it finishes you may see *"still downloading"*.

If your Mac does not support it, pick any other provider in Settings — or run a local
model through the OpenAI-compatible option, which is equally private.

## "No API key for …" / HTTP 401

Your key is stored against the **provider that was selected when you pasted it**. Open
Settings, select the provider you actually want, and read the caption under the key
field: it names the provider it saved to. If it says *"No key saved for …"*, paste it
there.

While you are in there, select any other provider you may have pasted a key into by
mistake and clear the field.

## HTTP 429, or a bill you did not expect

429 is the provider rate-limiting you; wait and retry. On cost: SayRight refuses
selections over 12,000 characters outright, and defaults to the cheapest capable model
for each provider. If you selected a whole document and it felt slow or expensive, that
is a large request — select less, or switch to the Apple provider, which is free.

## The popup appears in the wrong place

The panel is positioned from the rectangle the app reports for the selected text, falling
back to the text field's frame, then to the pointer. Some apps report nothing useful, in
which case it appears at the pointer.

If it appears in a corner of the wrong display on a multi-monitor setup, that is a bug —
please report your display arrangement (**System Settings ▸ Displays**, noting which is
the main display).

## Replace does nothing, or pastes in the wrong place

Some apps accept the accessibility write and silently ignore it, so SayRight reads the
text back and falls back to a synthetic ⌘V when the write did not take. For the paste to
land, the original app has to be frontmost — SayRight re-activates it first, but if you
have clicked into a *different* app in the meantime, use **Copy** instead.

Enable **Settings ▸ Use the clipboard when an app blocks Accessibility** if you have
turned it off; without it there is no fallback.

## My clipboard changed

The fallback copies your selection and pastes results using the clipboard, then restores
the previous contents. The restore happens ~0.35 s after a paste, so a clipboard manager
may record the intermediate value. Turn the fallback off in Settings if that matters to
you — at the cost of Chromium, Electron and Word support.

## Typing goes into the popup instead of my document

Only possible when you opened the bar with the hotkey, which intentionally makes the
panel focusable so it can be operated by keyboard. Press **Escape** to dismiss it.
Mouse-driven selections never take focus.

## Build failures

| Message | Cause |
|---|---|
| `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found` | Code is using `@State`. Not supported without Xcode — use an `@Observable` class. See [ARCHITECTURE.md](ARCHITECTURE.md#no-state-environment-or-binding-anywhere). |
| `external macro implementation type 'TestingMacros…' could not be found` | Run tests through `make test`, not bare `swift test`. |
| `platform 'macOS 26' …` | Toolchain older than the SDK the project targets. `xcode-select --install`, or point `xcode-select -s` at a current Xcode. |

## Still stuck?

Open an issue with: macOS version (`sw_vers`), `swift --version`, the app you were in,
what you selected, the provider, and anything in `~/Library/Logs/SayRight.log`. That log records
app names, accessibility roles and character counts — **never the text itself**.
