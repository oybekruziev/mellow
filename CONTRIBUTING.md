# Contributing to Mellow

Thanks for helping. Mellow is a small app with a calm, focused design, so the bar for new
features is "does this make focusing easier?" Bug fixes and polish are always welcome.

## Before you start

- **Bugs:** open an issue with your macOS version, Mellow version (Settings → About), what you
  did, what you expected, and a screenshot if it is visual.
- **Features:** open an issue first so we can agree on the idea before you spend time on it.
- **Small fixes** (typos, obvious bugs): a pull request is fine on its own.

## Working on the code

You need macOS 26 and Xcode 26. Open `Mellow.xcodeproj` and run the **Mellow** scheme, or:

```sh
zsh scripts/build.sh
zsh scripts/test.sh
```

- Keep timer logic in `Sources/MellowCore` and add a test in `Tests/MellowCoreTests` for any
  change in behavior. `zsh scripts/test.sh` must pass.
- For UI changes, check Light and Dark mode, over light and dark windows, with Reduce Motion
  and Reduce Transparency on. The Debug snapshot renderer (`MELLOW_SNAPSHOT_DIR`) helps.
- Match the surrounding code: SwiftUI, `@Observable`, no third-party dependencies.
- Interface text is in English, short and plain.

## Pull requests

- One change per pull request, with a clear description of what and why.
- Include screenshots (before and after) for anything visual.
- By opening a pull request you agree that your contribution is released under the
  [MIT License](LICENSE).
- Please do not add or change the Mellow name, logo, app icon or mascot artwork in a pull
  request without talking about it first. See [TRADEMARKS.md](TRADEMARKS.md).

## Releases

Releases are signed with the maintainer's Developer ID and notarized by Apple, so only the
maintainer publishes them (`zsh scripts/release.sh --publish`, then a GitHub Release with the
DMG attached). If you build Mellow yourself, `zsh scripts/build.sh` gives you an ad-hoc signed
copy for your own Mac.
