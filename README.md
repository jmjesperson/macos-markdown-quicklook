# MarkdownQuicklook

[![CI](https://github.com/jmjesperson/macos-markdown-quicklook/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jmjesperson/macos-markdown-quicklook/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jmjesperson/macos-markdown-quicklook)](https://github.com/jmjesperson/macos-markdown-quicklook/releases/latest)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue?logo=apple)
[![License: MIT](https://img.shields.io/github/license/jmjesperson/macos-markdown-quicklook)](LICENSE)

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

## Workflow and releases

The project uses GitHub flow: `main` is always releasable, and every change lands through a pull request from a short-lived branch. The step-by-step workflow, for the maintainer and for outside contributors, is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

- **Pull requests and pushes to `main`** run [`ci.yml`](.github/workflows/ci.yml) on a GitHub macOS runner with Xcode 26.6. It checks the Xcode project matches its generator config, runs the renderer tests, and runs `scripts/build-release.sh`.
- **A `vMAJOR.MINOR.PATCH` tag** (for example `v0.2.0`, or `v0.2.0-beta.1` for a pre-release) runs [`release.yml`](.github/workflows/release.yml). It reruns CI on the tagged commit and checks the tag matches the app version. Then it builds the zip and publishes a GitHub release, with notes from that version's `CHANGELOG.md` section (`scripts/release-notes.sh`). If CI fails, nothing is built or uploaded.
- **`main` is protected by two rulesets.** Every change needs a pull request with a passing "Test and build" check. Force pushes and deleting `main` are blocked. Pull requests also need approval from the code owner (`.github/CODEOWNERS`, @jmjesperson). GitHub doesn't let an author approve their own pull request, so the owner merges their own with the admin bypass (`gh pr merge --admin`), which skips only the approval; the checks still apply.
- **A newer run for the same trigger cancels the one in progress:** another push to the same PR, another push to `main`, or the same tag pushed again. A published release is never replaced. A version that's already out fails the tag run, and a dry run warns about it. A release left unfinished by a cancelled run is completed when the run is re-run.

To release a new version:

1. On a branch, set `version` in `scripts/xcodeproj-config.json` and regenerate the project with `scripts/generate-xcodeproj.py MarkdownQuicklook.xcodeproj "$(cat scripts/xcodeproj-config.json)"`.
2. Move the `[Unreleased]` notes in `CHANGELOG.md` under a new version heading with the date.
3. Open a pull request, and merge it once CI passes.
4. Tag the merge commit on `main` and push the tag: `git tag -a v<version> -m "MarkdownQuicklook <version>" && git push origin v<version>`. The release workflow does the rest.

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
scripts/                    build-release.sh; release-notes.sh; make-app-icon.sh (redraws the app icon from make-icon.swift);
                            generate-xcodeproj.py and xcodeproj-config.json (write the Xcode project)
openspec/                   change proposals and specs
```

## License

MIT. See [`LICENSE`](LICENSE). Bundled third-party code keeps its own licence; see [`docs/third-party.md`](docs/third-party.md).
