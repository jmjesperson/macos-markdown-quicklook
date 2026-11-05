# Design

## Context

See `proposal.md` for why. This is a new, empty repository. The behaviour is defined in `specs/quicklook-preview`, `specs/markdown-rendering` and `specs/diagram-rendering`, with `docs/markdown-support.md` as the element-by-element conformance list.

Facts that shape the approach, each checked on 2026-11-05:

- Apple's current model for Quick Look previews is an app extension inside a host app. Quick Look generators (`.qlgenerator`) are the pre-10.15 mechanism (https://developer.apple.com/documentation/quicklook/previews-or-thumbnail-images-for-macos-10-14-or-earlier), and macOS 15 no longer loads them (https://eclecticlight.co/2024/10/31/how-sequoia-has-changed-quicklook-and-its-thumbnails/).
- Apple offers two kinds of preview extension: view-based, where a view controller implements `QLPreviewingController`, and data-based, where a `QLPreviewProvider` subclass returns a `QLPreviewReply` carrying image, PDF or HTML data. Both are available from macOS 12.0 (https://developer.apple.com/documentation/quicklookui/qlpreviewingcontroller, https://developer.apple.com/documentation/quicklookui/qlpreviewprovider, https://developer.apple.com/documentation/quicklookui/qlpreviewreply).
- A data-based extension sets `QLIsDataBasedPreview` to true, lists its types in `QLSupportedContentTypes`, and sets `NSExtensionPrincipalClass` to its provider subclass (https://developer.apple.com/documentation/quicklookui/qlpreviewprovider). HTML replies can carry attachments referenced as `cid:<id>` (https://developer.apple.com/documentation/quicklook/qlpreviewreply/attachments).
- macOS assigns `.md` files the type `net.daringfireball.markdown`, which conforms to `public.plain-text` (verified with `mdls` on this Mac, macOS 26.5.1).
- Apple's docs do not say whether JavaScript runs in a data-based HTML reply. QLMarkdown is data-based and runs Mermaid in its HTML reply (https://github.com/sbarex/QLMarkdown/blob/main/QLExtension/PreviewProvider.swift). Extensions that render HTML need `com.apple.security.network.client` or the preview renders blank (https://github.com/sbarex/QLMarkdown/blob/main/QLExtension/QLExtension.entitlements, https://github.com/zoharbabin/fen/issues/49).
- Full Xcode is installed at `/Applications/Xcode.app`, but `xcode-select` points at Command Line Tools, so `xcodebuild` fails until `sudo xcode-select -s /Applications/Xcode.app` is run.

## Goals / Non-Goals

**Goals:**

- Follow Apple's recommended structure: a host app built from Xcode's macOS App template, with an embedded extension built from Xcode's Quick Look Preview Extension template. The extension, which reads the user's files, is sandboxed; the host app is not (decision 12).
- Keep all markdown logic in a plain Swift package that unit tests can exercise without Quick Look, Finder or a GUI.
- Make a preview cost only what the file uses: no Mermaid or highlighter code in a page that doesn't need it.

**Non-Goals:**

- Finder thumbnails (a separate Quick Look Thumbnail extension).
- Any preference UI beyond the enabled/disabled status the spec requires.
- Developer ID signing, notarization and a Homebrew cask. These are later changes, and nothing here should need restructuring for them.

## Decisions

### 1. Repository layout: one Xcode project plus a local Swift package

```text
MarkdownQuicklook.xcodeproj
App/                       host app target (SwiftUI): status window only
PreviewExtension/          Quick Look Preview Extension target (data-based)
Packages/MarkdownRenderer/ Swift package: markdown → HTML page, plus tests
  Sources/MarkdownRenderer/
  Resources/               bundled CSS and JS (github-markdown-css, Mermaid, highlighter)
  Tests/MarkdownRendererTests/Fixtures/   one fixture per docs/markdown-support.md row
docs/                      markdown-support.md, release and install notes
scripts/                   build-release.sh
```

The extension target is a thin adapter: it reads the file, calls `MarkdownRenderer`, and wraps the result in a `QLPreviewReply`. **Alternative considered:** all code in the extension target. Rejected because extension code can only be tested inside Quick Look. The product is named `MarkdownQuicklook`, with bundle identifier `io.github.jmjesperson.MarkdownQuicklook`, in the GitHub repo `macos-markdown-quicklook` (decided 2026-11-05).

### 2. Data-based preview first, view-based as the fallback

Start with a data-based `QLPreviewProvider` returning HTML. This is Apple's simplest HTML route and needs no web-view lifecycle code. Because Apple doesn't document JavaScript in these replies, task group 1 is a spike that proves, on this Mac, that a bundled script runs, that `prefers-color-scheme` follows the system, and that `cid:` image attachments load. **If any of those fails,** switch to a view-based extension hosting a `WKWebView` (MarkEdit's pattern, https://github.com/MarkEdit-app/MarkEdit/blob/main/QuickLookMac/QuickLookWebView.swift); the renderer package doesn't change. **Alternative considered:** view-based from the start. It gives more control, but adds web-view code that may not be needed.

**Spike result (2026-11-05, `docs/spike-notes.md`):** data-based works. A bundled script ran, `prefers-color-scheme` followed both Light and Dark appearance, and `cid:` image and script attachments loaded. The view-based fallback is not needed.

### 3. Markdown parsing in Swift with `swift-markdown`

Use Apple's `swift-markdown` (Apache-2.0, built on GitHub's `cmark-gfm`, https://github.com/swiftlang/swift-markdown) to parse into a syntax tree, then walk the tree to produce HTML. GitHub-specific features not in cmark-gfm (alerts, emoji, heading IDs, mention styling, front matter) are passes over that tree. Text appears without JavaScript, which is what makes the spec's "text before diagrams" requirement cheap. **Alternatives considered:** `markdown-it` or `marked` in the page, which have richer plugins but make all content depend on JavaScript; calling `cmark-gfm`'s C API directly, which is more work for the same parser. **Builder check:** confirm `swift-markdown` exposes footnotes and every GFM extension the support table needs; if not, call `cmark-gfm`'s HTML renderer with its extensions and post-process.

**Builder check result (2026-11-05):** `swift-markdown` 0.9.0 has no footnote support (its `ParseOptions` offer none) and turns on smart punctuation, which GitHub doesn't use. So the renderer uses the fallback: it depends on `swift-cmark` 0.9.0 (https://github.com/swiftlang/swift-cmark, the cmark-gfm that `swift-markdown` wraps) and calls `cmark_render_html` with the `table`, `strikethrough`, `autolink`, `tagfilter` and `tasklist` extensions and the `UNSAFE`, `FOOTNOTES`, `GITHUB_PRE_LANG` and `VALIDATE_UTF8` options. The GitHub-specific steps are passes over a token stream of that HTML, which is also how GitHub's own pipeline works. The sanitizer from decision 4 uses the same tokenizer. Fixture output was compared with GitHub's `/markdown` API on 2026-11-05: 13 of the 16 GFM-core fixtures matched exactly, and the other three differ only by GitHub's `rel="nofollow"` and cmark's footnote classes.

### 4. Safety: an allowlist sanitizer plus a strict Content Security Policy

Raw HTML from the file passes through an allowlist in Swift, admitting only the elements and attributes in the support table (`sub`, `sup`, `ins`, `br`, `a[name|href]`, `details`, `summary`, `picture`, `source[media|srcset]`, `img[src|alt|width|height]` and similar). It drops event-handler attributes and `javascript:` URLs. The page also carries a CSP of the form `default-src 'none'; script-src 'nonce-<random>'; style-src 'nonce-<random>'; img-src cid: data: https:`, so only the app's own scripts run even if the sanitizer misses something. QLMarkdown also uses a nonce-based CSP. The two layers back each other up: the sanitizer keeps the page tidy, and the CSP is the security boundary.

### 5. Bundled assets, loaded only when the file needs them

The renderer inspects the parsed document and includes Mermaid only when there is a `mermaid` block, and the highlighter only when a fenced block names a language. The GitHub CSS is always included. Scripts are **inlined** into the HTML. The spike measured both methods with one flowchart: inlined Mermaid reached the rendered diagram in about 588 ms from launching `qlmanage -p`, and a `cid:` attachment in about 650 ms (`docs/spike-notes.md`). Mermaid 12.3.0's minified build is 5,537,838 bytes.

### 6. Mermaid: the official bundle, pinned

Bundle a pinned `mermaid.min.js` (MIT; 12.3.0, the npm `latest` tag on 2026-11-05), initialise it with `startOnLoad: false`, and render each block in place, choosing `default` or `dark` theme from `prefers-color-scheme`. A per-block `try/catch` produces the error-and-source fallback the spec requires. **Alternative considered:** Pele (https://github.com/obsidianmd/pele), measured at 1.08 s against Mermaid's 2.93 s for a 14-diagram file (https://github.com/sbarex/QLMarkdown/issues/255). It's newer and reimplements Mermaid, so start with the official renderer and treat Pele as the fix if the speed requirement fails.

### 7. Syntax highlighting: highlight.js with GitHub themes

Bundle highlight.js with its `github` and `github-dark` themes, switched by `prefers-color-scheme`, and run it only on blocks that name a language. **Alternatives considered:** Prism (similar weight, fewer bundled GitHub themes); Shiki (closest to GitHub's grammars but much heavier); Splash (Swift-only, highlights only Swift). `[UNVERIFIED — highlight.js licence (believed BSD-3-Clause) and the exact names of its GitHub theme files; confirm when adding the dependency]`

### 8. Styling: `github-markdown-css`

Use `github-markdown-css` (MIT), whose default file switches light and dark through `prefers-color-scheme` (https://github.com/sindresorhus/github-markdown-css). The repository shows no tagged releases, so pin a specific commit.

### 9. Relative images read in Swift and attached

The extension reads each relative image itself and attaches it to the reply as `cid:` data, rewriting the `src`. The extension is granted the previewed file, not its neighbours, so this needs a read entitlement wide enough to reach sibling folders. The spike confirmed that the template's entitlements can't read a sibling (error 257) and that a relative `<img src>` never loads without an attachment. QLMarkdown uses `com.apple.security.temporary-exception.files.absolute-path.read-only` set to `/` (https://github.com/sbarex/QLMarkdown/blob/main/QLExtension/QLExtension.entitlements). The narrower `com.apple.security.temporary-exception.files.home-relative-path.read-only` set to `/` worked for files under the home folder, so that is the one used. Images beside files outside home render as alt text (`docs/spike-notes.md`). Images over a size cap (builder's call, for example 10 MB) render as alt text, to stay inside Quick Look's memory budget.

### 10. Minimum macOS 15

Apple's APIs go back to macOS 12, but testing happens on macOS 26 and the audience is current Macs. macOS 15 is the first release without `.qlgenerator` support, so it's a clean floor. This is the builder's call and can be lowered if a user asks.

### 11. Distribution: unsigned zip on GitHub Releases

`scripts/build-release.sh` runs `xcodebuild archive` and exports the app with ad-hoc signing (`CODE_SIGN_IDENTITY="-"`), then zips it. The README tells users to move the app to `/Applications`, clear quarantine with `xattr -dr com.apple.quarantine /Applications/<App>.app` or approve it under System Settings > Privacy & Security, and launch it once.

### 12. The host app is not sandboxed

The spec requires the host app to say whether the extension is enabled. macOS has no public API for that, and the only source, `pluginkit -m -i <id>`, refuses the query from inside App Sandbox with `match: unauthorized discovery flag (PKDiscoverAll)` (tested 2026-11-05 on macOS 26.5.1). Unsandboxed, the same call returns the election tag (`+`, `-`, `=` or none). @jmjesperson chose on 2026-11-05 to drop the sandbox from the host app only. The host app reads no user files and makes no network calls; the extension, which renders files, keeps App Sandbox. Distribution outside the Mac App Store doesn't need a sandboxed host. **Alternative considered:** keep both sandboxed and have the window always show where to enable the extension, which would mean narrowing the spec.

## Risks / Trade-offs

- [JavaScript doesn't run in a data-based reply on macOS 26] → Retired: the spike showed it runs (decision 2).
- [A downloaded, ad-hoc-signed extension isn't registered by macOS even after quarantine is cleared] `[UNVERIFIED]` → Test a release zip downloaded through a browser onto a second user account before publishing. If it fails, notarization (a paid Apple Developer account) becomes a requirement for sharing.
- [Mermaid's 5.5 MB bundle is slow to parse in each preview] → Load it only when needed (decision 5). Measure against the speed requirement. Swap to Pele if it fails.
- [Quick Look's time and memory limits are undocumented] (a 2018 report suggests about 30 s and 120 MB, https://blog.timac.org/2018/1119-constraints-on-quicklook-plugins/) → Cap image sizes. Test a 5,000-line file and a file with 30 diagrams.
- [Links don't open from the preview] (reported for MarkEdit, https://github.com/MarkEdit-app/MarkEdit/issues/1718) → The spec leaves click behaviour unspecified. In the spike, clicking a web link under `qlmanage -p` opened the default browser; the Finder space-bar preview is `[UNVERIFIED]`.
- [Another installed markdown extension (QLMarkdown) wins over this one] → Document checking the active extension with `pluginkit -mAvvv -p com.apple.quicklook.preview` and disabling others.
- [The sanitizer allowlist drifts from what GitHub allows] → The fixtures in decision 1 pin the expected output for each allowed element.

## Migration Plan

Not applicable; there is no existing version. Rollback for a user is deleting the app.

## Open Questions

- None on naming: the product name (`MarkdownQuicklook`), bundle identifier prefix (`io.github.jmjesperson`) and GitHub repo name (`macos-markdown-quicklook`) were settled on 2026-11-05.
- None on licensing: the repository is MIT-licensed (`LICENSE`, decided 2026-11-05). Bundled dependencies are MIT and Apache-2.0, and their notices are in `docs/third-party.md`.
