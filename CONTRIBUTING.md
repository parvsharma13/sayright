# Contributing to SayRight

Thanks for looking. This is a small, deliberately simple codebase — the goal is that
anyone can read all of it in an afternoon and keep it that way.

## Getting set up

```sh
git clone https://github.com/parvsharma13/sayright.git
cd sayright
make cert     # once: stable signature, so Accessibility is not revoked on each build
make test     # should be green before you change anything
make run      # debug build, bundled and launched
```

Full detail, including why `make cert` exists, is in [docs/SETUP.md](docs/SETUP.md).
Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before touching `Capture/` or
`Overlay/` — several things in there are odd for reasons, and the reasons are written
down.

**You do not need Xcode.** Please keep it that way: the project must build with the
Command Line Tools alone. In practice that means **no `@State`, `@Environment`,
`@Binding` or `@FocusState`** — those are macros in the current SDK and their plugin
ships only with Xcode. Put state in an `@Observable` class and build bindings by hand.

## The shape of a change

### Keep credentials out of Git

Before making commits, install the local secret scanner and enable this repository's
hooks:

```sh
brew install gitleaks
git config core.hooksPath .githooks
```

The commit hook scans staged changes; the push hook scans the complete reachable
history. Both stop if Gitleaks is missing or finds a suspected secret. GitHub also runs
the scanner on pushes and pull requests. A CI scan happens after upload, so keep the
local hooks enabled and review `git diff --cached` before committing.

Never commit API keys, signing certificates, private keys, local configuration, logs,
or screenshots containing credentials. Enter provider keys in the app's Settings so
they stay in macOS Keychain. Use clearly fake values in tests. Ignore rules help prevent
accidents but do not protect files already tracked by Git.

If a real credential is exposed, revoke or rotate it with its provider immediately.
Deleting it in a later commit does not remove it from history. Report the exposure
through [SECURITY.md](SECURITY.md), without posting the credential.

### Development workflow

1. **Open an issue first** for anything beyond a bug fix, so we can agree on the approach
   before you spend an evening on it.
2. Branch from `main`.
3. Add or update a test if the logic is testable without a screen. If it is not (panels,
   Accessibility calls), say in the PR how you verified it by hand and in which apps.
4. `make test` must pass.
5. Open a PR describing what changed and why, and name the apps you tested in.

### Commit messages

A short imperative subject, then prose explaining *why*. The diff already says what.

```
Only pop the bar up over editable text

Selecting a paragraph on a web page to read it was enough to summon the
action bar, because the reader only checked that some text was selected. It
now asks the Accessibility API whether the selected text is writable.
```

## Adding an action

Everything an action needs lives in [`Core/Action.swift`](Sources/SayRight/Core/Action.swift).
Add a case and fill in five things:

```swift
case summarise                                  // 1. the case

var title: String { "Summarise" }               // 2. full name, used in the panel
var shortTitle: String { "Summary" }            // 3. bar label, ≤ 12 characters
var symbol: String { "text.line.first.and.arrowtriangle.forward" }  // 4. SF Symbol
var help: String { "Condense it to the key points." }               // 5. hover + VoiceOver
private var instruction: String { "Summarise the text in ..." }     // 6. the prompt
```

`showsDiff` should stay `false` for anything that rewrites substantially — bolding every
word communicates nothing.

There is no other wiring: the bar, the menu, the prompts and the tests iterate
`Action.allCases`. The existing tests will fail if you forget a label or help string.

Keep the bar readable — it already has six actions, and it has to fit next to a selection
near the edge of a screen. A seventh is a design discussion, not just a case.

## Adding a provider

1. A type in `Providers/` conforming to `TextProvider`:

   ```swift
   struct MyProvider: TextProvider {
       let apiKey: String
       let model: String

       func buildRequest(system: String, user: String) throws -> URLRequest { … }
       func complete(system: String, user: String) async throws -> String {
           let data = try await HTTP.send(try buildRequest(system: system, user: user))
           return cleanCompletion(try Self.parse(data))
       }
       static func parse(_ data: Data) throws -> String { … }
   }
   ```

   Keep `buildRequest` and `parse` separate and non-private — that is what makes the
   provider testable without a network or a key.

2. A case in `ProviderKind` ([`Core/Settings.swift`](Sources/SayRight/Core/Settings.swift))
   with `displayName`, `knownModels`, `defaultModel` and `modelHint`.
3. One line in `ProviderFactory.make`.
4. Tests mirroring the existing ones: request shape, header placement, response parsing,
   and a malformed response.

Rules that are not negotiable:

- **API keys go in headers, never in URLs.** URLs leak into logs and proxies.
- Keys are read from the Keychain through `KeyStore` — never from `UserDefaults`, never
  from a file, never hardcoded.
- Surface real error messages. `HTTP.errorMessage(from:)` digs the provider's own
  explanation out of the response body; a user seeing "Incorrect API key provided" can
  fix their problem, and one seeing "Request failed" cannot.

Before adding a provider, check whether it already speaks the OpenAI chat-completions
API — if it does, it works today through the OpenAI-compatible option and needs no code.

## What is likely to be declined

Not because the ideas are bad, but to keep the project small and honest:

- **New dependencies.** There are currently none. `URLSession`, `SecItem` and SwiftUI
  cover this problem; adding a package has to earn it.
- **Telemetry, analytics or crash reporting of any kind.** See
  [docs/PRIVACY.md](docs/PRIVACY.md) — the promises there are the product.
- **Abstraction for one implementation.** No protocol with a single conformer, no factory
  for one product, no settings for a value that never changes.
- **Anything that requires Xcode to build.**
- **Live underlining as you type**, unless you have solved the hard part: macOS gives no
  way to draw inside another app's text view. A working prototype would be very welcome;
  a design document would not.

## Reporting bugs

Include your macOS version (`sw_vers`), `swift --version`, the app you were in, what you
selected, which provider was active, and any relevant lines from `~/Library/Logs/SayRight.log`.
That log contains app names, accessibility roles and character counts, never your text —
so it is safe to paste.

Security issues go to [SECURITY.md](SECURITY.md) instead, not a public issue.

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
