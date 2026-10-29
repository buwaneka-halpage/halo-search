# Privacy

Halo Search has no servers, accounts, analytics or crash reporting of its own.

## What stays on your Mac

- **Screen captures.** When you press the shortcut, the display under the pointer is captured into memory to show
  the overlay. It is never written to disk and is discarded when the overlay closes.
- **Text recognition.** Finding text on screen uses Apple's Vision framework on-device.
- **Settings.** Your shortcut and preferences are stored in the app's user defaults.

## What is sent to Google

Only after you make a selection:

- **A circled region** is sent as a JPEG to Google Lens, and AI Mode is then asked about it.
- **Selected text** is sent as a Google search and an AI Mode query.
- **Follow-up questions** you type are sent to AI Mode.

These requests are made by an embedded browser exactly as if you had used google.com, so
[Google's Privacy Policy](https://policies.google.com/privacy) applies. If you sign in to Google in Halo Search,
searches are associated with your account and may appear in your Google activity.

## Stored browser data

The embedded browser keeps cookies and site data (including a Google sign-in) in
`~/Library/WebKit/io.github.buwaneka-halpage.HaloSearch` and
`~/Library/HTTPStorages/io.github.buwaneka-halpage.HaloSearch.binarycookies`. Quit the app and delete them to sign
out and clear everything.

## Permissions

- **Screen & System Audio Recording** — to capture the screen when you press the shortcut. Halo Search does not
  record audio or video.
