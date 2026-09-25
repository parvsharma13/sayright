# SayRight

A free, open-source writing assistant for macOS. Improve selected text in the app
where you are already writing, then review the suggestion before replacing anything.

SayRight lives in the menu bar. Select a sentence in a supported text field and a
small action bar appears beside it. Choose a grammar fix, a rewrite, a different tone,
or a shorter or longer version. Your original text stays in place until you choose
**Replace**. You can also copy the suggestion and use it elsewhere.

The app requires no SayRight account or subscription. Use an on-device model where
supported, connect a local model server, or configure a supported cloud provider with
your own API key. Cloud providers may charge for usage.

## Features

- Six writing actions: fix grammar, rewrite, shorten, expand, professional tone and
  casual tone.
- A preview with Replace, Copy and Retry controls. Grammar corrections mark inserted
  or changed words in bold.
- A configurable keyboard shortcut, **Control + Option + Space** by default.
- An editable model selector and a choice of output languages.
- Settings for minimum selection length, ignored apps, clipboard fallback and launch
  at login.
- Keyboard navigation, screen-reader labels and spoken result announcements.

## How to use it

1. Launch SayRight and grant Accessibility access when prompted.
2. Select text in an editable field.
3. Choose an action from the floating bar, or press the keyboard shortcut.
4. Review the result, then choose Replace or Copy.

Support varies between apps. When an app does not expose its selection through
Accessibility, the keyboard shortcut can use a clipboard fallback. This temporarily
copies the selection and restores the previous clipboard contents afterwards.
Clipboard managers may retain that temporary copy.

## Privacy and credentials

SayRight has no telemetry, analytics or account service. A writing request starts
when you choose an action. The Settings test button also sends a short sample request.

| Processing option | Where the request runs |
|---|---|
| On-device model | On your Mac, when the system model is available |
| Local model server | On the machine hosting the server you configure |
| Cloud provider | At the provider you select, under its own data policies |

Provider API keys are stored in **macOS Keychain**, separately for each provider.
They are not bundled with the app or included in this repository. Add your own keys
through Settings, and never paste them into source files, issues or screenshots.

The app checks for secure fields, credential-like field labels and some common secret
formats. Its default ignore list includes password managers and command-line apps.
These checks have limits: avoid selecting sensitive information for a cloud request.

Diagnostics record app names, accessibility roles and character counts, rather than
selected text. Review logs before sharing them. See [Privacy](docs/PRIVACY.md) for
storage locations and further detail.

## Build and install

You need macOS 26 or newer and a compatible Swift toolchain with the macOS 26 SDK
or newer. The [setup guide](docs/SETUP.md) covers requirements and provider setup.

Clone this repository using its **Code** button, open a terminal in the downloaded
folder, then run:

```sh
make cert      # one-time local signing setup
make test      # run the unit tests
make install   # build and copy the app to /Applications
open /Applications/SayRight.app
```

`make cert` creates a local self-signed certificate to help keep the app's signature
consistent between builds. It does not notarise the app or provide a public developer
signature. The certificate and its private key stay in your local keychain.

Grant access in **System Settings > Privacy & Security > Accessibility**. This lets
SayRight read the selected text, place its controls and write back an accepted result.

For development, `make run` builds and launches the app. `make bundle CONFIG=release`
creates a release build without installing it.

## Choosing a model

The default is the system's on-device model, which requires compatible hardware and
the relevant system features to be enabled. If it is unavailable, configure another
provider in Settings.

For a cloud provider, enter your own API key and a model identifier supported by your
account. For a local or custom server, enter its base URL and model identifier. Use
HTTPS for remote services. Suggested model names may change over time; the model field
also accepts typed values.

Use **Test** in Settings to check the connection. The [setup guide](docs/SETUP.md#6-pick-a-provider)
lists the supported integrations and their configuration steps.

## Current limits

- macOS only.
- Works on selected text; it does not underline mistakes as you type.
- Selection and replacement support varies by app.
- Requests are limited to 12,000 characters.
- No streaming output, saved rewrite history or custom prompts.
- Generated text can change meaning or introduce errors. Review it before replacing
  the original, especially when expanding or translating.
- Prebuilt bundles are not notarised. Building from source is the documented install
  path.

## Documentation

- [Setup](docs/SETUP.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Privacy](docs/PRIVACY.md)
- [Contributing](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Contributing

Bug reports, compatibility reports and focused improvements are welcome. Read the
[contribution guide](CONTRIBUTING.md) for build instructions, tests and local secret
scanning. Report security problems through the private channel in [SECURITY.md](SECURITY.md).

## Licence

SayRight is available under the [MIT licence](LICENSE).
