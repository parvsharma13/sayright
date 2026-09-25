# Privacy

SayRight is a writing assistant, which means it can read what you are writing. This
document is specific about what that involves, because "trust us" is not good enough for
software with Accessibility access.

## What leaves your Mac

**Only the text you selected, only when you click an action, and only to the provider you
chose in Settings.**

| Provider | Where your selection goes |
|---|---|
| Apple (on-device) | Nowhere. Inference happens on your Mac. |
| OpenAI-compatible pointed at localhost | Nowhere — your own machine. |
| OpenAI / Anthropic / Gemini | That company's API, over HTTPS, with your key. |
| OpenAI-compatible pointed at a remote host | Whatever host you configured. |

Nothing else is ever transmitted. There is no analytics, no crash reporting, no update
check, no "anonymous usage statistics", and no server operated by this project. The only
outbound connections SayRight can make are the provider request you triggered.

You can verify this: the entire set of network calls is four files in
[`Sources/SayRight/Providers/`](../Sources/SayRight/Providers/), each one a single
`URLSession` request to a URL you can read.

Cloud providers have their own retention and training policies, which are theirs, not
ours. If that matters for your work, use the Apple provider or a local model.

## What is stored, and where

| What | Where | Notes |
|---|---|---|
| API keys | macOS Keychain, service `com.sayright.SayRight` | One item per provider, `kSecAttrAccessibleAfterFirstUnlock` |
| Provider, model, language, hotkey, toggles | `~/Library/Preferences/com.sayright.SayRight.plist` | No secrets |
| Your text | Nowhere | Held in memory for the length of one request |
| Results | Nowhere | The panel closes and it is gone; there is no history |
| Diagnostics | `~/Library/Logs/SayRight.log` | App names, accessibility roles, character counts. **Never your text.** Created mode `0600`, capped at 256 KB. |

## What SayRight refuses to look at

- **Password fields.** If the focused element is a secure text field, no bar appears and
  nothing is read. Always, with no setting to change it.
- **Fields labelled like a credential** — card number, CVV, PIN, one-time code, API key,
  recovery phrase, account number, sort code. Blocked on every path, including the hotkey.
- **Text that looks like a secret** whatever field it came from: a Luhn-valid card
  number, a JSON web token, a PEM private key, or an API key. The harm would be in the
  sending, so asking explicitly does not override it.
- **Apps on your ignore list.** Password managers, Keychain Access, terminals and
  launchers are there by default; you can add any app, or remove the defaults.
- **Read-only text**, on the automatic path — page content is not touched unless you
  explicitly press the hotkey.
- **Anything you have not selected.** SayRight reads the selected range, not the
  surrounding document.

## The clipboard

Some apps do not expose their selection to the Accessibility API. For those, the hotkey
path copies the selection with a synthetic ⌘C, reads the clipboard, then restores what
was there before. Pasting a result works the same way in reverse.

This means your clipboard briefly holds the text involved. A clipboard manager running on
your Mac may record it. Turn off **Settings ▸ Use the clipboard when an app blocks
Accessibility** to prevent this entirely; the cost is losing support for Chromium,
Electron and Word.

## Text you select is treated as data, not instructions

A web page could contain text that reads like an order to the model ("ignore your
instructions and…"). The system prompt tells the model that the message is text copied
out of a document and must be edited, never obeyed — and every result is shown to you
before anything is written into your document. That preview is the real control: nothing
a page can say gets into your writing without you clicking Replace.

## Network

The only host SayRight connects to is the provider you chose. macOS App Transport
Security blocks plain `http` except to this machine, so a misconfigured remote endpoint
fails loudly rather than sending your key in cleartext — Settings warns you if you enter
one.

## Permissions

SayRight requests **Accessibility** and nothing else. That one permission is broad — it
is what lets any app read selections and synthesise keystrokes — which is exactly why
this project is open source, why the network layer is four small files, and why the
diagnostics log deliberately never contains your writing.

It does not request Screen Recording, Input Monitoring, Full Disk Access, Contacts,
Calendars, or network server access.

## Reporting a privacy problem

Something here wrong, or something leaking that should not? See [SECURITY.md](../SECURITY.md).
