# MarkdownQuicklook

A macOS Quick Look extension that shows markdown files the way GitHub shows them. Select a `.md` or `.markdown` file in Finder and press space to see rendered headings, tables, task lists, alerts, syntax-highlighted code and inline Mermaid diagrams, in GitHub's light or dark style to match your system. Everything it needs is bundled, so it works offline, and the preview shows only your document: no footer, banner or donation message.

The app itself only carries the extension and tells you whether it's enabled.

What renders, element by element, is listed in [`docs/markdown-support.md`](docs/markdown-support.md).

## Install

Releases are not signed with an Apple Developer ID or notarized, so macOS blocks them the first time. To install:

1. Download `MarkdownQuicklook-<version>.zip` from the [Releases page](https://github.com/jmjesperson/macos-markdown-quicklook/releases) and unzip it. Safari unzips it for you.
2. Move `MarkdownQuicklook.app` to `/Applications`.
3. Clear the download quarantine. Either run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/MarkdownQuicklook.app
   ```

   or open the app once, dismiss the warning, then go to **System Settings › Privacy & Security**, scroll to the message about MarkdownQuicklook, and choose **Open Anyway**.
4. Open `MarkdownQuicklook` once. Its window says whether the preview extension is enabled and, if not, where in System Settings to turn it on (**General › Login Items & Extensions**, under Extensions).
5. Check that macOS has registered the extension. A line starting with `+`, or with no symbol, means it is in use; `-` means it is turned off:

   ```sh
   pluginkit -m -v -i io.github.jmjesperson.MarkdownQuicklook.PreviewExtension
   ```

6. Select a markdown file in Finder and press space. If an older preview still appears, run `qlmanage -r` to reset Quick Look.

If another markdown previewer, such as QLMarkdown, keeps winning, list every installed preview extension and turn the others off under **General › Login Items & Extensions**:

```sh
pluginkit -mAvvv -p com.apple.quicklook.preview
```

To uninstall, quit the app and delete `/Applications/MarkdownQuicklook.app`.

## Build a release

```sh
scripts/build-release.sh
```

This archives the app, signs it ad hoc, checks that the extension is sandboxed and that no debug entitlement shipped, and writes `build/release/MarkdownQuicklook-<version>.zip`.

To release a new version:

1. Set `version` in `scripts/xcodeproj-config.json` and regenerate the project with `scripts/generate-xcodeproj.py MarkdownQuicklook.xcodeproj "$(cat scripts/xcodeproj-config.json)"`.
2. Move the `[Unreleased]` notes in `CHANGELOG.md` under a new version heading with the date.
3. Run `scripts/build-release.sh`, commit, tag `v<version>`, and attach the zip to a GitHub release with the changelog notes.

## Contributor prerequisites

- **macOS 15 or later.**
- **Full Xcode**, selected as the active developer directory. Command Line Tools alone can't build the app:

  ```sh
  sudo xcode-select -s /Applications/Xcode.app
  xcodebuild -version
  ```

- **OpenSpec**, for the change proposals under `openspec/`. Install it with Homebrew; it runs on Homebrew's own Node, so the project needs no Node version pin:

  ```sh
  brew install openspec
  openspec list
  ```

## Build

```sh
xcodebuild -scheme MarkdownQuicklook build
```

Or open `MarkdownQuicklook.xcodeproj` in Xcode and run the `MarkdownQuicklook` scheme.

## Test

All markdown logic lives in the `Packages/MarkdownRenderer` Swift package, so it can be tested without Quick Look:

```sh
swift test --package-path Packages/MarkdownRenderer
```

Each `Tests/MarkdownRendererTests/Fixtures/<group>/<name>.md` must render to the `<name>.html` beside it. After a deliberate change, rewrite the expected files with `UPDATE_FIXTURES=1 swift test --package-path Packages/MarkdownRenderer`, then review the diff.

To see the full page for one file:

```sh
swift run --package-path Packages/MarkdownRenderer markdown-render qa/conformance.md build/conformance.html
```

## Layout

```text
MarkdownQuicklook.xcodeproj
App/                        host app (status window)
PreviewExtension/           Quick Look preview extension (data-based HTML reply)
Packages/MarkdownRenderer/  markdown → HTML page, with bundled CSS and JS, and its tests
docs/                       support table, spike notes, third-party notices
qa/                         files for checking previews by hand in Quick Look
scripts/                    build-release.sh; make-app-icon.sh (redraws the app icon from make-icon.swift);
                            generate-xcodeproj.py and xcodeproj-config.json (write the Xcode project)
openspec/                   change proposals and specs
```

## License

MIT. See [`LICENSE`](LICENSE). Bundled third-party code keeps its own licence; see [`docs/third-party.md`](docs/third-party.md).
