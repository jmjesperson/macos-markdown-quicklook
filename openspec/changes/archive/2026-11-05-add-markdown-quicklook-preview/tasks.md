# Tasks

## 1. Toolchain and spike (throwaway; answers design decisions 2, 5 and 9)

- [x] 1.1 Ask @jmjesperson to run `sudo xcode-select -s /Applications/Xcode.app`, then verify `xcodebuild -version` prints an Xcode version
- [x] 1.2 In a scratch Xcode project, create a macOS App with an embedded Quick Look Preview Extension from Xcode's template, set `QLIsDataBasedPreview` true and `QLSupportedContentTypes` to `net.daringfireball.markdown`, add `com.apple.security.network.client`, and verify `qlmanage -p sample.md` shows the extension's HTML instead of plain text
- [x] 1.3 Add a bundled script that writes into the page, a `prefers-color-scheme` rule and a `cid:` image attachment, then verify in Light and Dark appearance that all three work; if the script does not run, switch the spike to a view-based `WKWebView` extension and verify the same three
- [x] 1.4 Load the pinned `mermaid.min.js` both inlined and as an attachment, render one flowchart, and record time-to-diagram for each in `docs/spike-notes.md`
- [x] 1.5 Try reading a sibling image from the extension, record which entitlement was needed (after reading QLMarkdown's entitlements file) in `docs/spike-notes.md`, and verify the image renders
- [x] 1.6 Record whether clicking a web link in the preview opens the browser in `docs/spike-notes.md`, then update `design.md` decisions 2, 5 and 9 with the spike's answers

## 2. Project structure

- [x] 2.1 Create `MarkdownQuicklook.xcodeproj` with the `App` and `PreviewExtension` targets from Xcode's templates, deployment target macOS 15, App Sandbox on the extension (the host app is unsandboxed, decided 2026-11-05: see design decision 12), and verify `xcodebuild -scheme MarkdownQuicklook build` succeeds
- [x] 2.2 Create the `Packages/MarkdownRenderer` Swift package depending on `swift-markdown` (pinned; replaced by `swift-cmark` 0.9.0 in task 3.1, see design decision 3), link it into `PreviewExtension`, and verify `swift test --package-path Packages/MarkdownRenderer` runs one passing placeholder test
- [x] 2.3 Add `README.md` covering what the app does, contributor prerequisites (full Xcode selected with `xcode-select`; OpenSpec installed with Homebrew, `brew install openspec`, which runs on Homebrew's own Node, so no project Node pin is needed), how to build it and how to run the tests, and verify each documented command runs as written

## 3. Markdown rendering core

- [x] 3.1 Render GFM core (headings, emphasis, strikethrough, quotes, lists, tables with alignment, footnotes, autolinks, code, line breaks, escapes) to HTML and verify with one fixture per element under `Tests/.../Fixtures/`
- [x] 3.2 Generate GitHub-style heading IDs including duplicate suffixes, and verify with fixtures for punctuation, emoji and duplicate headings
- [x] 3.3 Render task lists as disabled checkboxes and verify the fixture output has `disabled` on each input
- [x] 3.4 Render the five alert types with GitHub's titles and icons, and verify one fixture per type plus a non-alert block quote
- [x] 3.5 Convert emoji shortcodes from a bundled GitHub shortcode table, skipping code, and verify known, unknown and in-code fixtures
- [x] 3.6 Style mentions, `#123` references and commit SHAs without links, and verify fixtures including an email address that must not be treated as a mention
- [x] 3.7 Render YAML front matter as a table after confirming GitHub's behaviour, update the front-matter requirement and `docs/markdown-support.md` with what was found, and verify a fixture
- [x] 3.8 Render `math`, `geojson`, `topojson` and `stl` fences and `$` math as plain source, and verify fixtures for each

## 4. Safety

- [x] 4.1 Implement the HTML allowlist sanitizer from design decision 4 and verify fixtures for every allowed element and for `<script>`, `onerror`, `javascript:` URLs and `<iframe>` being removed
- [x] 4.2 Emit the nonce-based Content Security Policy and verify a test asserts its presence and that every bundled `<script>` carries the nonce
- [x] 4.3 Verify in Quick Look that the spec's `<script>` and `onerror` scenarios do not execute

## 5. Page assembly, styling and highlighting

- [x] 5.1 Assemble the full HTML page with pinned `github-markdown-css`, and verify a snapshot test of the page skeleton
- [x] 5.2 Add highlight.js with GitHub light and dark themes, included only when a fenced block names a language, and verify tests for included and omitted cases
- [x] 5.3 Render relative and `<picture>` images through the method chosen in task 1.5, with alt-text fallback and a size cap, and verify fixtures for present, missing and oversized images
- [x] 5.4 Record versions, licences and source URLs of every bundled asset in `docs/third-party.md`, and verify each licence file ships inside the app bundle

## 6. Diagrams

- [x] 6.1 Bundle pinned Mermaid, included only when a `mermaid` block exists, with theme from appearance, and verify tests for included and omitted cases
- [x] 6.2 Render each block in place with a per-block error fallback showing the message and source, and verify in Quick Look with a fixture holding a valid, an invalid and a second valid diagram
- [x] 6.3 Scale wide diagrams to the preview width, and verify with a wide flowchart fixture in a narrow Quick Look window
- [x] 6.4 Verify every diagram type listed in the spec renders, using one fixture per type

## 7. Quick Look extension and host app

- [x] 7.1 Wire `PreviewExtension` to read the file, call `MarkdownRenderer` and return the reply, and verify `qlmanage -p` renders `.md` and `.markdown` fixtures
- [x] 7.2 Build the host app's status window (extension enabled or not, and where in System Settings to enable it), and verify both states by toggling the extension
- [x] 7.3 Verify no footer, banner or render counter exists by previewing 101 files in a loop and checking the last page holds only document content
- [x] 7.4 Verify that previewing a file with no remote images makes no outbound connection and renders offline. Verified 2026-11-05: the app, extension and renderer contain no networking code; the page's Content Security Policy (`default-src 'none'`) admits only nonce-bearing bundled scripts and styles and `cid:`, `data:` and `https:` images, so only a remote image in the file can reach the network; the bundled init scripts hold no URLs; and @jmjesperson previewed `qa/diagrams/three-diagrams.md` with Wi-Fi off and saw the text, the flowchart, the invalid diagram's error and the sequence diagram. `nettop` was dropped because it could not attribute Quick Look's web traffic, even for a control that did load a remote image.

## 8. Distribution

- [x] 8.1 Write `scripts/build-release.sh` (archive, ad-hoc sign, zip) and verify it produces a zip whose app launches
- [x] 8.2 Document install steps (move to `/Applications`, clear quarantine or approve in System Settings, launch once, check with `pluginkit`) in the README. @jmjesperson accepted the README alone on 2026-11-05; the second-account check moved to Workflow follow-up.

## 9. Integration checks

- [x] 9.2 Measure a 300-line README with no diagrams (target 1 s) and a 14-diagram file (target 2.9 s) with `qlmanage -p` timings, and record the results in `docs/spike-notes.md`; if the diagram target fails, open a follow-up change to evaluate Pele
- [x] 9.3 Stress-test a 5,000-line file and a 30-diagram file, and verify Quick Look neither times out nor shows a blank preview

## 10. Code review fixes (review of 2026-11-05)

- [x] 10.1 Escape a `<` the tokenizer can't read as a tag (for example an unterminated attribute quote), so raw tag text can't bypass the allowlist
- [x] 10.2 Prefix the file's `id` and `name` attributes with `user-content-` as GitHub does, and give heading anchors, footnotes and `#` links the same prefix so in-page links still resolve
- [x] 10.3 Drop an unclosed `svg`, `math`, `video` or other removed element by its tag alone, so it can't hide the rest of the document
- [x] 10.4 Close self-closing non-void elements (`<span/>`, `<a href=x/>`) at once
- [x] 10.5 End a multi-line plain front matter value at the next less-indented line, and render invalid front matter as markdown instead of dropping lines
- [x] 10.6 Render alerts only for block quotes at the top level of the document
- [x] 10.7 Decode files as UTF-8, then UTF-16 with a byte-order mark, then ISO Latin-1, reading the file once
- [x] 10.8 Cap the total size of attached images at 50 MB per preview; later images render as alt text
- [x] 10.9 Run the host app's `pluginkit` check off the main thread, and read its output before waiting so a full pipe can't hang the app
- [x] 10.10 Check entitlements in `scripts/build-release.sh` without piping `codesign` into `grep -q` under `pipefail`
- [x] 10.11 Follow symlinked images whose target is also an image file
- [x] 10.12 Treat `text`, `plaintext`, `txt`, `plain` and `none` fences as plain code that doesn't load highlight.js

## Workflow follow-up

- Archive the change after @jmjesperson has reviewed the implementation.
- Former task 9.1, deferred by @jmjesperson on 2026-11-05 as not critical yet: preview `qa/conformance.md` (one example of every v1 and Partial row in `docs/markdown-support.md`), compare it side by side with the same file on github.com, and record any differences as bugs or table updates.
- Former second half of task 8.2: verify the README install steps by downloading the release zip through a browser onto a second macOS user account.
- Open separate changes for math, maps (GeoJSON, TopoJSON), STL, signing and notarization, and Finder thumbnails.
