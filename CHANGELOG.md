# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Demo video, with a reproducible recording and editing workflow in `demo/` and a `--demo` mode that drives the app.

## [0.1.0] - 2026-10-29

### Added

- Global shortcut (default ⌃⇧Space) that freezes the display under the pointer in a full-screen overlay.
- Circle a region to search it as an image: Google AI Mode answers about it with the image attached, and Google
  Lens shows visual matches.
- Scribble over text or tap a word to search that text, using on-device OCR.
- Follow-up questions about a circled image, sent through AI Mode.
- Resizable selection, redraw to search again, links opening in the default browser.
- Persistent Google sign-in, launch at login, choice of shortcut, first tab and image question.
- `--selftest` live end-to-end check and `--render-overlay` visual harness.

[Unreleased]: https://github.com/buwaneka-halpage/halo-search/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/buwaneka-halpage/halo-search/releases/tag/v0.1.0
