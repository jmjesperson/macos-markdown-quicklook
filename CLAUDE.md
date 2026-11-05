# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MarkdownQuicklook is a macOS Quick Look extension that previews `.md` and `.markdown` files the way GitHub renders them, including inline Mermaid diagrams, offline and with no branding. The README covers install and release steps for users.

## Commands

```sh
# Tests (all markdown logic lives in the Swift package, so no Quick Look needed)
swift test --package-path Packages/MarkdownRenderer
swift test --package-path Packages/MarkdownRenderer --filter latin1FileDecodesAsLatin1   # one test
swift test --package-path Packages/MarkdownRenderer --filter SanitizerTests              # one file

# After a deliberate output change, rewrite fixture and page snapshots, then review the diff
UPDATE_FIXTURES=1 swift test --package-path Packages/MarkdownRenderer

# Render one file to a full HTML page (dev tool, not shipped)
swift run --package-path Packages/MarkdownRenderer markdown-render qa/conformance.md build/conformance.html

# Build the app (needs full Xcode, not just Command Line Tools)
xcodebuild -project MarkdownQuicklook.xcodeproj -scheme MarkdownQuicklook -configuration Release -derivedDataPath build/DerivedData build

# Release zip: archive, ad-hoc sign, verify sandbox and no get-task-allow → build/release/MarkdownQuicklook-<version>.zip
scripts/build-release.sh
```

There is no linter configured.

### Seeing a change in real Quick Look

```sh
APPEX=build/DerivedData/Build/Products/Release/MarkdownQuicklook.app/Contents/PlugIns/PreviewExtension.appex
pluginkit -a "$APPEX"                     # register this build
pluginkit -m -v -i io.github.jmjesperson.MarkdownQuicklook.PreviewExtension   # which copy is registered; '+' or blank = in use, '-' = off
qlmanage -r && qlmanage -p qa/diagrams/three-diagrams.md
```

Every build location registers its own copy, and Debug builds, archives and Xcode's intermediate copies can take over Quick Look from the one you meant to test. Before trusting a preview, check `pluginkit -m -v -i …` lists only the copy you expect, and remove strays with `pluginkit -r <path>`. Unregister before moving or deleting a build folder. The `qa/` folder holds files for checking previews by hand; `qa/README.md` says what each checks.

## Architecture

Three parts, deliberately thin at the edges:

- **`Packages/MarkdownRenderer/`**: Swift package doing all the work: markdown in, a complete HTML page plus image attachments out. It's tested here, never inside Quick Look.
- **`PreviewExtension/`**: a *data-based* Quick Look preview extension (`QLIsDataBasedPreview`). `PreviewProvider` reads the file, calls `MarkdownRenderer.renderPage`, and returns an HTML `QLPreviewReply` whose attachments are served to the page as `cid:` URLs. It is sandboxed.
- **`App/`**: the host app that carries the `.appex`. It only shows whether the extension is enabled by parsing `pluginkit -m` output, and it doesn't run during previews. It is **not sandboxed** because `pluginkit` refuses the query from inside the sandbox (design decision 12).

### Rendering pipeline (`MarkdownRenderer.bodyTokens` → `renderPage`)

1. `FrontMatter` splits off YAML front matter and renders it as GitHub's table. Invalid YAML returns nil, so the whole file renders as markdown.
2. `CMark` runs swift-cmark (cmark-gfm) with the GFM extensions and `UNSAFE`. Raw HTML passes through, so the sanitizer is the gate.
3. `HTMLTokenizer` (in `HTML.swift`) is a small forgiving tokenizer, not an HTML5 parser. Text tokens stay entity-encoded and serialise unchanged.
4. `Sanitizer` is an allowlist. Unknown tags lose their tags but keep their text. `droppedWithContent` elements are removed with their content, but only if closed. A `<` left in text is escaped. The file's `id` and `name` get GitHub's `user-content-` prefix, and `#` links get the same prefix.
5. `GitHubFilters` passes run **after** the sanitizer, so the markup they add is trusted:
   - code blocks: mermaid placeholders, `language-x` classes, deferred and plain languages
   - heading anchors: GitHub slugs, ids prefixed `user-content-`
   - emoji, mentions, issue references and SHAs: styled, not linked
   - task lists
   - alerts: top-level block quotes only
6. `renderPage` attaches local images with `ImageAttacher` (`Images.swift`), then builds the page. Images are image extensions only, symlinks must resolve to an image, and there's a 10 MB per-image and 50 MB total cap; anything that fails becomes alt text. A leading `/` resolves to the nearest `.git` folder.

### Page and security model (`Page.swift`)

- **The Content Security Policy is the real security boundary**; the sanitizer is a tidiness layer. The policy is `default-src 'none'` with a per-page random nonce for scripts and styles, and `img-src cid: data: https:`.
- **Every bundled script and style carries the nonce.** `mermaid-init.js` copies the nonce onto the `<style>` elements inside Mermaid's SVG.
- **Bundled scripts are inlined** rather than attached; the spike measured this as faster.
- **Each script loads only if the file needs it:** highlight.js when a fenced block names a non-plain language, Mermaid when there's a `mermaid` block.
- **No network:** the page must not need it, the extension has no networking code, and only `https:` images written in the file can reach the network.

### Bundled third-party assets

All live in `Sources/MarkdownRenderer/Resources/`: github-markdown-css, highlight.js (common bundle plus 16 appended language files), Mermaid with its bundled DOMPurify, gemoji's table as `emoji.json`, and Octicon paths inlined in `GitHubFilters`. Versions, npm integrity hashes and licences are in `docs/third-party.md`. To update one, follow that file, and `ThirdPartyTests` checks the licence files ship.

## Conventions and gotchas

- **The Xcode project is generated, not hand-edited.** Change `scripts/xcodeproj-config.json`, which holds the version, bundle ID and build settings, then regenerate with the command below. Object IDs derive from the output path, so regenerating from the repo root gives a stable diff.

  ```sh
  scripts/generate-xcodeproj.py MarkdownQuicklook.xcodeproj "$(cat scripts/xcodeproj-config.json)"
  ```

  It uses folder-synchronised groups, so new files under `App/` or `PreviewExtension/` need no project edit.
- **Test fixtures:** each `Tests/MarkdownRendererTests/Fixtures/<group>/<name>.md` must render to the `<name>.html` beside it. Fixture expectations came from GitHub's own `/markdown` API. Use synthetic content only.
- **What GitHub renders, and what this renders, is tracked row by row in `docs/markdown-support.md`.** Keep it in step with behaviour changes. Math, GeoJSON, TopoJSON and STL are deliberately deferred and render as plain code.
- **The extension's sandbox read exception** is `temporary-exception.files.home-relative-path.read-only` = `/`, the narrowest one that let sibling images load. The spike results behind this and the other design choices are in `docs/spike-notes.md`.
- **The app icon** is drawn by `scripts/make-icon.swift`. Run `scripts/make-app-icon.sh` to regenerate `App/Assets.xcassets/AppIcon.appiconset`.

## Workflow (read CONTRIBUTING.md)

The maintainer is GitHub user @jmjesperson. In this project, refer to them by that username, in files, commits and pull requests, never by first name. `LICENSE` keeps the copyright holder's legal name.

`CONTRIBUTING.md` is the source of truth for how changes reach `main` and how releases happen. The maintainer workflow there is the one to follow when working with @jmjesperson. In short:

- **Always work on a branch** (`<type>/<short-name>`) and open a pull request. `main` rejects direct pushes and force pushes for everyone, admins included.
- **CI must be green first.** Merge @jmjesperson's pull requests with `gh pr merge --admin --squash --delete-branch` only after "Test and build" has passed (`gh pr checks --watch`). `--admin` exists only because GitHub won't let an author approve their own pull request. It isn't a way around failing checks.
- **Ask @jmjesperson first** before merging, tagging a release, or changing repository settings or rulesets. Above all, ask before pausing the checks ruleset (the broken-CI procedure in `CONTRIBUTING.md`).
- **Keep things current:** add user-visible changes to `[Unreleased]` in `CHANGELOG.md`, and keep `docs/markdown-support.md` in step with rendering changes.
- **Releases come only from the Release workflow:** push a `vX.Y.Z` tag after the version-bump PR merges. `.github/workflows/release.yml` reruns CI, checks the tag matches `scripts/xcodeproj-config.json`, builds the zip, and publishes the release with notes from `scripts/release-notes.sh`, which combines the CHANGELOG section with `.github/release-install.md`. Releases are ad-hoc signed and not notarized, so the README covers clearing quarantine.

## Specs (OpenSpec)

Requirements live in `openspec/specs/` (`markdown-rendering`, `quicklook-preview`, `diagram-rendering`). Completed changes are in `openspec/changes/archive/`, whose `design.md` records the numbered design decisions referenced in code comments. New behaviour goes through an OpenSpec change (`openspec` CLI, installed with `brew install openspec`; the slash commands are in `.claude/commands/opsx/`).
