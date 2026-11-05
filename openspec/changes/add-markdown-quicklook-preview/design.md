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

- Follow Apple's recommended structure: a host app built from Xcode's macOS App template, with an embedded extension built from Xcode's Quick Look Preview Extension template, both sandboxed.
- Keep all markdown logic in a plain Swift package that unit tests can exercise without Quick Look, Finder or a GUI.
- Make a preview cost only what the file uses: no Mermaid or highlighter code in a page that doesn't need it.

**Non-Goals:**

- Finder thumbnails (a separate Quick Look Thumbnail extension).
- Any preference UI beyond the enabled/disabled status the spec requires.
- Developer ID signing, notarization and a Homebrew cask. These are later changes, and nothing here should need restructuring for them.

## Decisions

### 1. Repository layout: one Xcode project plus a local Swift package

```text
MarkdownPreview.xcodeproj
App/                       host app target (SwiftUI): status window only
PreviewExtension/          Quick Look Preview Extension target (data-based)
Packages/MarkdownRenderer/ Swift package: markdown → HTML page, plus tests
  Sources/MarkdownRenderer/
  Resources/               bundled CSS and JS (github-markdown-css, Mermaid, highlighter)
  Tests/MarkdownRendererTests/Fixtures/   one fixture per docs/markdown-support.md row
docs/                      markdown-support.md, release and install notes
scripts/                   build-release.sh
```

The extension target is a thin adapter: it reads the file, calls `MarkdownRenderer`, and wraps the result in a `QLPreviewReply`. **Alternative considered:** all code in the extension target. Rejected because extension code can only be tested inside Quick Look. `MarkdownPreview` is a working name; the final product and repo name is Jonny's call.

### 2. Data-based preview first, view-based as the fallback

Start with a data-based `QLPreviewProvider` returning HTML. This is Apple's simplest HTML route and needs no web-view lifecycle code. Because Apple doesn't document JavaScript in these replies, task group 1 is a spike that proves, on this Mac, that a bundled script runs, that `prefers-color-scheme` follows the system, and that `cid:` image attachments load. **If any of those fails,** switch to a view-based extension hosting a `WKWebView` (MarkEdit's pattern, https://github.com/MarkEdit-app/MarkEdit/blob/main/QuickLookMac/QuickLookWebView.swift); the renderer package doesn't change. **Alternative considered:** view-based from the start. It gives more control, but adds web-view code that may not be needed.

### 3. Markdown parsing in Swift with `swift-markdown`

Use Apple's `swift-markdown` (Apache-2.0, built on GitHub's `cmark-gfm`, https://github.com/swiftlang/swift-markdown) to parse into a syntax tree, then walk the tree to produce HTML. GitHub-specific features not in cmark-gfm (alerts, emoji, heading IDs, mention styling, front matter) are passes over that tree. Text appears without JavaScript, which is what makes the spec's "text before diagrams" requirement cheap. **Alternatives considered:** `markdown-it` or `marked` in the page, which have richer plugins but make all content depend on JavaScript; calling `cmark-gfm`'s C API directly, which is more work for the same parser. **Builder check:** confirm `swift-markdown` exposes footnotes and every GFM extension the support table needs; if not, call `cmark-gfm`'s HTML renderer with its extensions and post-process.

### 4. Safety: an allowlist sanitizer plus a strict Content Security Policy

Raw HTML from the file passes through an allowlist in Swift, admitting only the elements and attributes in the support table (`sub`, `sup`, `ins`, `br`, `a[name|href]`, `details`, `summary`, `picture`, `source[media|srcset]`, `img[src|alt|width|height]` and similar). It drops event-handler attributes and `javascript:` URLs. The page also carries a CSP of the form `default-src 'none'; script-src 'nonce-<random>'; style-src 'nonce-<random>'; img-src cid: data: https:`, so only the app's own scripts run even if the sanitizer misses something. QLMarkdown also uses a nonce-based CSP. The two layers back each other up: the sanitizer keeps the page tidy, and the CSP is the security boundary.

### 5. Bundled assets, loaded only when the file needs them

The renderer inspects the parsed document and includes Mermaid only when there is a `mermaid` block, and the highlighter only when a fenced block names a language. The GitHub CSS is always included. How the scripts reach the page, inlined into the HTML or as `cid:` attachments, is settled in the spike by measuring both. Mermaid 12.0.0's minified build is about 5.5 MB (https://cdn.jsdelivr.net/npm/mermaid@12.0.0/dist/mermaid.min.js, measured by a subagent on 2026-11-05).

### 6. Mermaid: the official bundle, pinned

Bundle a pinned `mermaid.min.js` (MIT), initialise it with `startOnLoad: false`, and render each block in place, choosing `default` or `dark` theme from `prefers-color-scheme`. A per-block `try/catch` produces the error-and-source fallback the spec requires. **Alternative considered:** Pele (https://github.com/obsidianmd/pele), measured at 1.08 s against Mermaid's 2.93 s for a 14-diagram file (https://github.com/sbarex/QLMarkdown/issues/255). It's newer and reimplements Mermaid, so start with the official renderer and treat Pele as the fix if the speed requirement fails.

### 7. Syntax highlighting: highlight.js with GitHub themes

Bundle highlight.js with its `github` and `github-dark` themes, switched by `prefers-color-scheme`, and run it only on blocks that name a language. **Alternatives considered:** Prism (similar weight, fewer bundled GitHub themes); Shiki (closest to GitHub's grammars but much heavier); Splash (Swift-only, highlights only Swift). `[UNVERIFIED — highlight.js licence (believed BSD-3-Clause) and the exact names of its GitHub theme files; confirm when adding the dependency]`

### 8. Styling: `github-markdown-css`

Use `github-markdown-css` (MIT), whose default file switches light and dark through `prefers-color-scheme` (https://github.com/sindresorhus/github-markdown-css). The repository shows no tagged releases, so pin a specific commit.

### 9. Relative images read in Swift and attached

The extension reads each relative image itself and attaches it to the reply as `cid:` data, rewriting the `src`. The extension is granted the previewed file, not its neighbours, so this needs a read entitlement wide enough to reach sibling folders. The narrowest one that works is chosen in the spike `[UNVERIFIED — which entitlement QLMarkdown uses; read its entitlements file before choosing]`. Images over a size cap (builder's call, for example 10 MB) render as alt text, to stay inside Quick Look's memory budget.

### 10. Minimum macOS 15

Apple's APIs go back to macOS 12, but testing happens on macOS 26 and the audience is current Macs. macOS 15 is the first release without `.qlgenerator` support, so it's a clean floor. This is the builder's call and can be lowered if a user asks.

### 11. Distribution: unsigned zip on GitHub Releases

`scripts/build-release.sh` runs `xcodebuild archive` and exports the app with ad-hoc signing (`CODE_SIGN_IDENTITY="-"`), then zips it. The README tells users to move the app to `/Applications`, clear quarantine with `xattr -dr com.apple.quarantine /Applications/<App>.app` or approve it under System Settings > Privacy & Security, and launch it once.

## Risks / Trade-offs

- [JavaScript doesn't run in a data-based reply on macOS 26] → The spike checks this first. Fallback: the view-based extension from decision 2.
- [A downloaded, ad-hoc-signed extension isn't registered by macOS even after quarantine is cleared] `[UNVERIFIED]` → Test a release zip downloaded through a browser onto a second user account before publishing. If it fails, notarization (a paid Apple Developer account) becomes a requirement for sharing.
- [Mermaid's 5.5 MB bundle is slow to parse in each preview] → Load it only when needed (decision 5). Measure against the speed requirement. Swap to Pele if it fails.
- [Quick Look's time and memory limits are undocumented] (a 2018 report suggests about 30 s and 120 MB, https://blog.timac.org/2018/1119-constraints-on-quicklook-plugins/) → Cap image sizes. Test a 5,000-line file and a file with 30 diagrams.
- [Links don't open from the preview] (reported for MarkEdit, https://github.com/MarkEdit-app/MarkEdit/issues/1718) → The spec leaves click behaviour unspecified. Record what happens in the spike.
- [Another installed markdown extension (QLMarkdown) wins over this one] → Document checking the active extension with `pluginkit -mAvvv -p com.apple.quicklook.preview` and disabling others.
- [The sanitizer allowlist drifts from what GitHub allows] → The fixtures in decision 1 pin the expected output for each allowed element.

## Migration Plan

Not applicable; there is no existing version. Rollback for a user is deleting the app.

## Open Questions

- Product name, bundle identifier prefix and GitHub repo name (affects only strings).
- The repository's licence. Bundled dependencies are MIT and Apache-2.0, so a permissive licence avoids conflicts.
