# Proposal

## Why

Pressing space on a README or other developer-documentation markdown file in Finder should show it the way GitHub shows it, including inline Mermaid diagrams. The best-known free option, QLMarkdown (https://github.com/sbarex/QLMarkdown), shows an "about" footer by default and a hardcoded "buy me a coffee" message on every 100th preview that no setting removes (https://github.com/sbarex/QLMarkdown/issues/192), and its Mermaid support loads the library from a CDN by default. @jmjesperson wants his own previewer with no branding, offline diagrams, and GitHub's rendering as the baseline; he is also using this project to evaluate OpenSpec for AI-driven feature development.

## What Changes

- New macOS app whose only job is to carry and register a Quick Look preview extension for markdown files (Apple's data-based preview extension model, macOS 12+: https://developer.apple.com/documentation/quicklookui/qlpreviewprovider).
- The extension renders every markdown element GitHub documents for markdown files, as listed element by element in `docs/markdown-support.md`, except math, GeoJSON, TopoJSON and STL, which @jmjesperson deferred on 2026-11-05.
- Mermaid diagrams in fenced `mermaid` blocks render inline, offline, from a library bundled in the app.
- GitHub's visual style, following the system light or dark appearance.
- No footer, watermark, nag, telemetry or network dependency for rendering.
- Distribution as unsigned builds on GitHub Releases, with README instructions for getting past Gatekeeper. Developer ID signing and notarization are out of scope for this change.

## Capabilities

### New Capabilities

- `quicklook-preview`: How the extension is installed, enabled and invoked from Finder; which files it previews; appearance, offline and no-branding guarantees; safety when a file contains active content; and preview speed.
- `markdown-rendering`: Which markdown elements render and how, measured against GitHub's documented behaviour, including the elements that render only partially in a local preview.
- `diagram-rendering`: Rendering of fenced Mermaid blocks as diagrams, and what happens when a diagram fails to render.

### Modified Capabilities

None. This is the project's first change.

## Impact

- **New code:** an Xcode project with a macOS host app target and a Quick Look Preview Extension target, plus a Swift package holding the markdown-to-HTML step so it can be unit-tested without Quick Look.
- **New dependencies:** `swift-cmark`, GitHub's cmark-gfm (BSD-2-Clause, https://github.com/swiftlang/swift-cmark; replaces the `swift-markdown` named here originally, see design decision 3); Mermaid (bundled JavaScript); a syntax highlighter (bundled JavaScript, chosen in design); GitHub-style CSS (`github-markdown-css`, MIT, https://github.com/sindresorhus/github-markdown-css).
- **Machine prerequisites:** full Xcode selected as the active developer directory. On 2026-11-05 this Mac reported `xcode-select` pointing at Command Line Tools, and `xcodebuild` failed until that is switched.
- **Out of scope:** math, GeoJSON, TopoJSON and STL rendering; Finder thumbnails; editing; signing and notarization; Homebrew cask.
