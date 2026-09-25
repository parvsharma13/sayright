# Setup guide

Everything needed to get SayRight running, and to understand what each step is for.
If something goes wrong, [TROUBLESHOOTING.md](TROUBLESHOOTING.md) covers the common cases.

## 1. Requirements

| | |
|---|---|
| macOS | 26 (Tahoe) or newer |
| Toolchain | Swift 6.4+ — full Xcode, or just the Command Line Tools |
| Disk | ~200 MB for the build directory |
| Apple silicon or Intel | Both build; Apple's on-device provider needs Apple silicon |

You do **not** need Xcode. `xcode-select --install` gives you a Swift toolchain that can
build the whole app, which is why this project uses SwiftPM and a `Makefile` rather than
an `.xcodeproj`.

Check what you have:

```sh
swift --version          # want 6.4 or newer
xcrun --show-sdk-version # want 26.x or newer
```

## 2. Get the source

```sh
git clone https://github.com/parvsharma13/sayright.git
cd sayright
```

## 3. Create a signing certificate (once)

```sh
make cert
```

This creates a self-signed code-signing certificate called `SayRight Self Signed` in your
login keychain. It is worth understanding why:

macOS ties the Accessibility permission to an app's **code signature**. Without a
certificate the build is *ad-hoc* signed, meaning its signature changes every single time
you rebuild — so macOS decides it is a different app and revokes the permission. You
would be re-granting Accessibility access after every `make run`. A stable self-signed
certificate keeps one grant valid forever.

It is not a substitute for a real Apple Developer ID: it does not make the app notarized,
and other people cannot verify it. It only makes your local builds consistent.

The script may ask for your login keychain password. If you skip this step everything
still works, you will just see a warning on each build and have to re-grant access.

## 4. Build and install

```sh
make install     # release build → /Applications/SayRight.app
open /Applications/SayRight.app
```

Other targets:

| Command | What it does |
|---|---|
| `make build` | Compiles only (`.build/`) |
| `make bundle` | Assembles and signs `build/SayRight.app` |
| `make run` | Debug build, bundle, then launch it |
| `make test` | Runs the unit tests |
| `make install` | Release build into `/Applications` |
| `make clean` | Removes `.build/` and `build/` |
| `make cert` | Creates the self-signed certificate |

`CONFIG=release make bundle` builds an optimised bundle without installing it.

## 5. Grant Accessibility access

On first launch SayRight opens a window asking for Accessibility access, with a button
that takes you to the right pane. Switch **SayRight** on in
**System Settings ▸ Privacy & Security ▸ Accessibility**.

The window notices the moment you grant it — no relaunch needed.

SayRight needs this permission to:

- read the text you have selected, from the app you selected it in;
- find out where on screen that text is, so the bar appears next to it;
- write the corrected text back;
- register a system-wide hotkey.

It is the **only** permission requested. There is no Screen Recording, no Full Disk
Access, no Input Monitoring. If SayRight ever asks for more, something is wrong —
please [report it](../SECURITY.md).

## 6. Pick a provider

Open the menu bar icon ▸ **Settings…**

### Apple (on-device) — the default

Free, offline, and nothing leaves your Mac. Requires Apple Intelligence to be turned on
in **System Settings ▸ Apple Intelligence & Siri**, on a Mac that supports it. The model
downloads once, in the background.

Best at grammar and punctuation. Weaker than the cloud models at long or creative
rewrites. If it reports as unavailable, SayRight tells you which of the two reasons it is
(not supported, or not enabled) rather than failing silently.

### OpenAI

1. Create a key at <https://platform.openai.com/api-keys>
2. Settings ▸ Provider ▸ **OpenAI**, paste the key
3. Confirm it says *"Saved in your Keychain for OpenAI."*
4. Model: `gpt-5.6-luna` (cheapest) through `gpt-6-astra` (most capable)

### Anthropic

1. Create a key at <https://console.anthropic.com/settings/keys>
2. Settings ▸ Provider ▸ **Anthropic**, paste the key
3. Model: `claude-haiku-4-5` (fastest, cheapest) through `claude-opus-5` / `claude-fable-5-1`

### Google Gemini

1. Create a key at <https://aistudio.google.com/apikey>
2. Settings ▸ Provider ▸ **Google Gemini**, paste the key
3. Model: `gemini-3.5-flash-lite` (cheapest) through `gemini-3.8-flash`

The key is sent in an `x-goog-api-key` header rather than a query string, so it does not
end up in URLs, proxy logs, or crash reports.

### OpenAI-compatible (Ollama, LM Studio, OpenRouter, Groq, vLLM…)

One entry covers anything that speaks the OpenAI chat-completions API.

| Server | Base URL | Key |
|---|---|---|
| Ollama | `http://localhost:11434/v1` | leave empty |
| LM Studio | `http://localhost:1234/v1` | leave empty |
| OpenRouter | `https://openrouter.ai/api/v1` | required |
| Groq | `https://api.groq.com/openai/v1` | required |

Set **Model** to whatever the server has loaded (`ollama list` will tell you). With a
local server this is as private as the Apple provider — nothing leaves the machine.

> **Keys are per provider.** Pasting a Gemini key while the picker says
> "OpenAI-compatible" stores it against the wrong provider. The caption under the field
> always names the provider it saved to — read it once and you will never chase this.

Press **Test** to send one short sentence and see what comes back. It is the fastest way
to confirm a key, a base URL, and a model name all at once.

## 7. Everything else in Settings

| Setting | Notes |
|---|---|
| **Output language** | "Same as input" leaves your language alone. Anything else also translates. |
| **Hotkey** | Click, then press a combination. ⌃⌥Space by default. |
| **Clipboard fallback** | On by default. Needed for Chromium, Electron and Word. Only used on the hotkey path. |
| **Ignore selections under N characters** | 3 by default. Stops the bar on a stray double-click; the hotkey still works on anything. |
| **Ignored apps** | SayRight reads nothing at all in these. Password managers, Keychain Access, terminals and launchers are there by default; "Add App…" adds any other. |
| **Launch at login** | Registers SayRight as a login item via `SMAppService`. |

## Updating

```sh
git pull
make install
```

Because the signature stays the same, your Accessibility grant and your keys survive the
update.

## Uninstalling

```sh
rm -rf /Applications/SayRight.app
defaults delete com.sayright.SayRight
```

Then remove SayRight from **System Settings ▸ Privacy & Security ▸ Accessibility**, and
delete the `com.sayright.SayRight` entries from **Keychain Access** if you stored API
keys. Optionally `security delete-certificate -c "SayRight Self Signed"` to remove the
signing certificate.

## Installing a prebuilt download

Every CI run produces an **unsigned** `SayRight.app` zip. macOS will refuse to open it
normally, because it is neither signed by a known developer nor notarized:

```sh
xattr -d com.apple.quarantine /Applications/SayRight.app   # or right-click ▸ Open
```

Understand the trade-off before doing this: you are choosing to run a binary that Apple
has not checked, from a build you did not make. Building from source with `make install`
is the recommended path, and takes about a minute.
