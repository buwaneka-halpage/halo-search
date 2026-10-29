# Development

## Requirements

- macOS 14 or later
- Swift 5.10 or later — either Xcode, or just the Command Line Tools (`xcode-select --install`)

There are no third-party dependencies.

## Everyday commands

```sh
scripts/build.sh             # build "Halo Search.app" into ./build
scripts/build.sh --install   # …and copy it to /Applications and launch it
scripts/test.sh              # unit tests (Swift Testing)
swift build                  # just compile
```

`scripts/test.sh` is `swift test` with extra framework paths when only the Command Line Tools are installed, since
SwiftPM doesn't find Swift Testing there on its own. With Xcode installed, plain `swift test` works.

### Screen Recording permission while developing

Builds are signed ad hoc, so macOS sees each rebuild as a new app and asks for Screen Recording again. To keep the
permission across builds, sign with a stable identity:

```sh
CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" scripts/build.sh --install
```

Any code-signing certificate in your keychain works, including a free Apple Development one created by Xcode.

## Diagnostics

### Live self-test

```sh
swift build -c release
.build/release/HaloSearch --selftest path/to/photo.jpg
```

Runs a real search offscreen through the same `SearchModel` the app uses: uploads the image to Lens, waits for
AI Mode to answer about it, asks a follow-up and waits for that answer. It prints each stage and exits non-zero on
failure. Use a photo of something well known (a landmark works well). Run it after touching `GoogleSearch` or
`PageScripts`, and whenever users report that searches stopped working. Running it many times in a row can trigger
Google's traffic check.

### Overlay render

```sh
.build/release/HaloSearch --render-overlay path/to/screenshot.png output-folder
```

Draws the overlay over a screenshot, replays a circle and a scribble with synthetic mouse events, and saves PNGs of
each state. It needs no Screen Recording permission, so it is handy for checking overlay changes from a terminal or
CI. The images in `docs/images` were made this way.

## Code style

- Match the surrounding code: small types, `// MARK:` sections, comments that explain *why* rather than *what*.
- Logic that doesn't need AppKit belongs in `HaloSearchCore`, with tests.
- Anything that depends on Google's markup goes in `PageScripts` or `GoogleSearch`, nowhere else.

## Releasing

1. Update `VERSION` and move the `Unreleased` notes in `CHANGELOG.md` under the new version.
2. Commit, then tag and push: `git tag v0.2.0 && git push origin main v0.2.0`.
3. The **Release** workflow builds the app, packages `HaloSearch-<version>.zip` and attaches it to a GitHub
   release with the changelog notes.

Release builds are currently signed ad hoc. Signing with a Developer ID and notarising them is tracked in the
roadmap.
