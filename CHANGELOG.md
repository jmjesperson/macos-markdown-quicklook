# Changelog

All notable changes to MarkdownQuicklook are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-05

First release.

### Added

- Quick Look preview for `.md` and `.markdown` files, rendered the way GitHub renders markdown: GitHub Flavored Markdown (tables, task lists, strikethrough, autolinks, footnotes), heading anchors, alerts, emoji shortcodes, front matter as a table, and the HTML GitHub allows.
- Mermaid diagrams drawn inline, with an error message and the diagram source shown in place of any diagram that fails to parse.
- Syntax highlighting for fenced code blocks that name a language.
- GitHub's light and dark styles, following the system appearance.
- Images next to the file, shown in the preview.
- Works offline. Every stylesheet and script is bundled, and the preview shows no branding, banner or donation message.
- A host app that carries the extension and reports whether it is enabled, with its own icon.
- A release script that builds an ad-hoc signed zip for GitHub Releases.

### Known limitations

- Math, GeoJSON maps, TopoJSON maps and STL models are not rendered yet.
- Mentions, issue references and commit references are styled but not linked, because a local file has no repository context.
- Images outside your home folder, images over 10 MB, and images past a 50 MB total for one file show as alt text.
- Releases are not signed with an Apple Developer ID or notarized. See the README for how to install them.

[Unreleased]: https://github.com/jmjesperson/macos-markdown-quicklook/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jmjesperson/macos-markdown-quicklook/releases/tag/v0.1.0
