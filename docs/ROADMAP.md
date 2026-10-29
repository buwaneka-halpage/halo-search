# Roadmap

Each item has an issue on GitHub; this page is the overview. Milestones are ordered by what makes Halo Search most
useful to the most people soonest.

## ✅ 0.1 — First release

- Global shortcut, frozen-screen overlay with edge glow, stroke and selection animations
- Circle → image search in Google AI Mode (image attached) and Google Lens
- Scribble or tap → text search, with on-device OCR
- Follow-up questions in AI Mode, resizable selection, links open in the default browser
- Persistent Google sign-in, launch at login, configurable shortcut and default tab
- Unit tests for the core library, live self-test, CI and release workflows

## 0.2 — Ready for everyone

Removing the friction a new user meets in the first five minutes.

- **Signed and notarised releases.** Developer ID signing and notarisation in the release workflow, so the app opens
  without a Gatekeeper warning and keeps its Screen Recording permission across updates.
- **Homebrew cask.** `brew install --cask halo-search`.
- **Automatic updates.** Sparkle, with an appcast published from GitHub releases.
- **Onboarding window.** Walk through the permission with live status instead of alerts, and show the shortcut.
- **Settings window.** A proper SwiftUI settings window with a shortcut recorder (any key combination), replacing
  the preset menu.
- **Sign out of Google.** Clear the embedded browser's cookies and data from the menu.
- **All displays.** Freeze and overlay every display, not only the one under the pointer.

## 0.3 — Closer to the phone

The features that make the Android version feel effortless.

- **Tap to select an object.** Use Vision's subject lifting (`VNGenerateForegroundInstanceMaskRequest`) so a tap
  selects the thing under it, as on Pixel.
- **Copy text from the selection.** Offer the recognised text of a circled region with one click.
- **QR codes and barcodes.** Detect them with Vision and show a chip to open or copy the link.
- **Translate.** Translate selected text, or the whole circled region through Lens' translate mode.
- **Pin the results.** Keep the panel open after the overlay closes, to read while you work.
- **Trigger options.** Hold a modifier and draw, a mouse button, or a trackpad gesture, as alternatives to the
  shortcut.

## 0.4 — Beyond Google

- **Search providers.** A small provider protocol with Bing Visual Search, Yandex Images and DuckDuckGo for text.
- **Ask another AI.** Send the selection to a chat assistant of the user's choice, with their own API key.
- **History.** A searchable list of recent selections and their results, stored locally.

## Ongoing — Quality

- **Nightly live check.** Run `--selftest` on a schedule and open an issue automatically when Google's pages
  change.
- **Overlay snapshot tests.** Use the `--render-overlay` harness to catch visual regressions in CI.
- **Accessibility.** VoiceOver labels in the panel; a keyboard-only way to make a selection.
- **Localisation.** Translate the app's own interface.
- **Performance.** Pre-warm the web views and cache `SCShareableContent` so the overlay appears faster.

## Not planned

- **Windows or Linux versions.** [CircleFlow](https://github.com/keekyslusus/CircleFlow) already serves Windows well.
- **An unofficial Google API client.** Halo Search drives Google's normal web pages in a real browser on purpose:
  it respects the user's account, consent and Google's checks.
