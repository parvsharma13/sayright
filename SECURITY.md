# Security policy

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Use [GitHub's private vulnerability reporting](https://github.com/parvsharma13/sayright/security/advisories/new):
go to the **Security** tab and choose **Report a vulnerability**. No public email address
is provided. If reporting is unavailable, open an issue asking the maintainer to enable
private reporting, without including vulnerability details or credentials.

Please include what an attacker can achieve, the steps to reproduce it, the macOS and
SayRight versions, and anything you would want to know if you were fixing it.

Expect an acknowledgement within a week. Because this is a volunteer project, a fix may
take longer; you will be told either way. Credit in the release notes is offered unless
you would rather stay anonymous.

## Supported versions

Only `main` and the most recent release are supported. There are no backports.

## What is in scope

SayRight holds Accessibility access and API keys, which makes a handful of things
genuinely serious:

- **Reading text it should not.** Anything that makes SayRight read from a secure text
  field, or read a document the user did not select.
- **Leaking API keys.** A key appearing in a URL, a log file, `UserDefaults`, a crash
  report, or a request to the wrong host.
- **Sending text to the wrong place.** Any path where the selection goes somewhere other
  than the provider the user configured.
- **Writing text where it should not go**, including a paste landing in a different app
  or a different field than the one selected.
- **Clipboard leakage** beyond the documented fallback behaviour, or a failure to restore
  the previous clipboard contents.
- **Privilege escalation via the app bundle** — anything that turns the Accessibility
  grant into broader access.
- **Prompt injection with real consequences.** Text that, when selected and "fixed",
  causes SayRight to do something other than return edited text.

## What is out of scope

- The behaviour, retention or training policies of third-party model providers. Use the
  Apple provider or a local model if that is a concern.
- The macOS Accessibility permission itself being powerful. It is, by design; that is why
  this code is public and small enough to audit.
- Prebuilt CI downloads being unsigned and unnotarized. This is
  [documented](docs/SETUP.md#installing-a-prebuilt-download); building from source is the
  supported path.
- An attacker who already has code execution as your user. They do not need SayRight.

## For reviewers

The fastest audit route:

| Question | Where to look |
|---|---|
| Where does text go over the network? | `Sources/SayRight/Providers/` — four files, one request each |
| How are keys stored? | `Core/Keychain.swift`, `Core/KeyStore.swift` |
| What does it read from other apps? | `Capture/Selection.swift` |
| What does it write, and where? | `Capture/TextWriter.swift`, `Capture/ClipboardCapture.swift` |
| What gets logged? | `Core/Debug.swift` and its call sites |

The threat model and the data-handling promises are in [docs/PRIVACY.md](docs/PRIVACY.md).
