## What this changes

<!-- And why. The diff already says what; explain the reason. -->

## How it was verified

<!-- `make test` covers the pure logic. Anything touching Capture/ or Overlay/ needs
     manual testing, so name the apps: TextEdit, Chrome, Slack, Word, … -->

- [ ] `make test` passes
- [ ] Tested by hand in: <!-- apps -->

## Checklist

- [ ] Builds with the Command Line Tools alone — no `@State`, `@Environment`, `@Binding`
      or anything else needing the Xcode-only SwiftUI macro plugin
- [ ] No new third-party dependencies
- [ ] No telemetry, analytics or crash reporting added
- [ ] API keys stay in the Keychain, and out of URLs and logs
- [ ] Tests added or updated for anything testable without a screen
- [ ] `CHANGELOG.md` updated under `[Unreleased]` if user-visible
