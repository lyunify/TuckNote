# TuckNotes

![TuckNotes: Quick notes. Right in your notch.](Assets/ReadmeHero.png)

A native macOS notebook for the thoughts you want to keep close. Open it from your MacBook's notch to write Markdown, make a checklist, or drop in a screenshot, then tuck it away and get back to your day.

[Visit the website and try the demo](https://lyunify.github.io/TuckNote/)

## Download and Install

Supports **Apple Silicon and Intel Macs** running **macOS 14 or later**. One download works on both.

[Download TuckNotes for Mac](https://github.com/lyunify/TuckNote/releases/latest/download/TuckNotes-macOS.zip)

1. Extract `TuckNotes-macOS.zip`.
2. Move `TuckNotes.app` to Applications, then open it.

This release is not Developer ID signed or notarized by Apple. If macOS blocks the first launch and you trust this download, go to **System Settings > Privacy & Security > Open Anyway** after attempting to open the app. See [Apple's instructions](https://support.apple.com/en-us/102445).

Release notes and a SHA-256 checksum are available on the [latest release](https://github.com/lyunify/TuckNote/releases/latest).

## Use TuckNotes

- Hover over or click the top-center of your screen to open your notes.
- Write Markdown, check off tasks, and paste or drag in images.
- Use multiple pages to keep notes separate, switch between light and dark themes, or pin the panel open.

Notes and images save automatically on your Mac in `~/Library/Application Support/TuckNote/`. No account or cloud sync is required. Replacing the app does not remove this data.

The website demo is a separate, temporary playground: refreshing it clears its contents.

## Development

With a Swift 6 toolchain installed:

```sh
swift run TuckNote
swift test
```

To create a local app bundle and ZIP:

```sh
./Scripts/package-app.sh
open dist/TuckNotes.app
```

The output is `dist/TuckNotes.app`, `dist/TuckNotes-macOS.zip`, and `dist/SHA256SUMS.txt`. The universal app includes both Apple Silicon and Intel versions; you only need one download. Move the app into Applications to keep it installed. Local builds are not Developer ID signed or notarized, so macOS may display a security warning.

On a Mac without a notch, use the same top-center screen area to open your notes.

## Built With

- **SwiftUI and AppKit** for the interface, floating panel, and notch interaction.
- **MarkdownEngine** for Markdown editing and inline images.
- **KeyboardShortcuts** for the global shortcut.
- **Local JSON files and UserDefaults** for notes and preferences.

GitHub Actions runs tests on Apple Silicon and Intel and verifies the universal package. The [product website](https://lyunify.github.io/TuckNote/) is served from `docs/` through GitHub Pages.

## License

[MIT](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md) for dependency licenses and website asset credits.
