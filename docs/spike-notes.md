# Spike notes

Results of task group 1 of the `add-markdown-quicklook-preview` change, run on 2026-11-05 on this Mac (macOS 26.5.1, build 25F80; Xcode 26.6, build 17F113; Apple Swift 6.3.3). The spike project was throwaway and lived outside the repository.

## How the spike was checked

- The scratch project reproduced Xcode's "macOS SwiftUI App" and "Quick Look Preview Extension" templates (files and build settings copied from the templates in `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Xcode/Templates/Project Templates/macOS/`). The project file was written by a script because Xcode's template engine only runs from the Xcode GUI.
- Sandbox entitlements came from the build settings `ENABLE_APP_SANDBOX`, `ENABLE_USER_SELECTED_FILES = readonly` (both set by the template) and `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES`. `codesign -d --entitlements -` on the built extension showed `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-only` and `com.apple.security.network.client`.
- The extension was registered with `pluginkit -a <path>/SpikePreview.appex` and checked with `pluginkit -m -v -i <bundle id>`.
- The page's own script reported what it saw (script ran, `prefers-color-scheme`, image sizes, timings) by requesting an image from a listener on `127.0.0.1:8765`. That beacon existed only in the spike. Screenshots of the Quick Look window confirmed each result.

## Results

| Question | Answer | Evidence |
|---|---|---|
| Does a data-based HTML reply show instead of plain text? | Yes. | `qlmanage -p sample.md` showed the extension's HTML heading (screenshot). |
| Does a bundled script run in a data-based reply? | Yes. | The script replaced "JS DID NOT RUN" with "JS RAN" and its beacon arrived (screenshot and listener log). No view-based `WKWebView` fallback is needed. |
| Does `prefers-color-scheme` follow the system? | Yes, both ways. | Dark: beacon `dark=true`, body `rgb(13, 17, 23)`. Light: beacon `dark=false`, body `rgb(255, 255, 255)`. Screenshots in both appearances. |
| Do `cid:` image attachments load? | Yes. | A 40×40 PNG attached as `red.png` rendered and reported `naturalWidth` 40 in both appearances. |
| Does `<script src="cid:…">` load an attached script? | Yes. | Mermaid attached as `cid:mermaid.js` rendered the flowchart (screenshot). |
| Can the extension read a sibling image with the template's entitlements? | No. | `Data(contentsOf:)` on `img/sibling.png` failed with `NSCocoaErrorDomain` 257 (permission denied). |
| Does `<img src="img/sibling.png">` (a relative path, no attachment) load? | No, with any entitlement tried. | `naturalWidth` 0 in every run. Relative images must be read in Swift and attached. |
| Does a web link open the browser when clicked? | Yes, under `qlmanage -p`. | A synthetic click on `https://example.com/` made the default browser (Brave) frontmost. `[UNVERIFIED — same click in a Finder space-bar preview; Jonny to try once]` |

## Mermaid: inlined versus attached (task 1.4)

Mermaid 12.3.0 from npm (`mermaid-12.3.0.tgz`, integrity `sha512-4113TdXeLAsMruJ79OpFL5O8+LTFXhQqZ260rF3tgUmiNAtRm4Uume04I+65PRN6yZ69J4f8rVYWW8zRk65UYw==`, matching `npm view mermaid@12.3.0 dist.integrity`), `dist/mermaid.min.js`, 5,537,838 bytes. 12.3.0 was the `latest` tag on 2026-11-05, so it replaces the 12.0.0 named in the design.

One flowchart (`flowchart LR; A --> B`), Release build, `startOnLoad: false`, `mermaid.render` called once. "Launch to diagram" is wall-clock milliseconds from starting `qlmanage -p` to the beacon sent after the SVG was inserted. "Page clock" is `performance.now()` at that moment.

| Method | Run 1 (cold) | Run 2 | Run 3 | Run 4 | Page clock, runs 2 to 4 |
|---|---|---|---|---|---|
| Inlined `<script>` | 875 ms | 587 ms | 588 ms | 588 ms | 182 to 189 ms |
| `cid:` attachment | 619 ms | 648 ms | 649 ms | 653 ms | 258 to 263 ms |

Inlined was about 60 ms faster per warm preview. **Decision: inline Mermaid** (and the other bundled scripts) into the page.

## Sibling images and the read entitlement (task 1.5)

QLMarkdown's extension (https://github.com/sbarex/QLMarkdown/blob/main/QLExtension/QLExtension.entitlements, read 2026-11-05) holds `com.apple.security.temporary-exception.files.absolute-path.read-only` set to `/` (read access to the whole disk), alongside `network.client`, `files.user-selected.read-only`, an app group and two `mach-lookup` exceptions.

| Entitlement tried | Image beside a file under `~` | Image beside a file in `/private/tmp` |
|---|---|---|
| Template only (`files.user-selected.read-only`) | not tried | failed (257) |
| `temporary-exception.files.home-relative-path.read-only` = `/` | rendered (`naturalWidth` 60) | failed |
| `temporary-exception.files.absolute-path.read-only` = `/` | not tried | rendered (`naturalWidth` 60) |

**Decision: `temporary-exception.files.home-relative-path.read-only` set to `/`.** It is the narrowest exception that worked, and it covers repositories under the home folder. Images beside a file outside the home folder (another volume, `/tmp`) render as alt text, which the missing-image requirement already allows. Widening to QLMarkdown's `absolute-path` `/` is a one-line change if that turns out to matter.

## Not covered by the spike

- Remote `https:` images (the `Images` row in `docs/markdown-support.md`) were not tested here. They are checked in task 5.3.

## Preview speed and stress (tasks 9.2 and 9.3, 2026-11-05)

Fixtures come from `qa/make-perf-fixtures.py`. **Method:** the shipped page's Content Security Policy blocks any beacon, so timing used the spike extension as a harness, with the real extension turned off for the run (`pluginkit -e ignore`). For `X.md` the harness served the page `markdown-render` had written for it, unchanged except for `http://127.0.0.1:8765` added to `img-src` and one nonce-bearing probe script. The probe reported `paint` (two animation frames after start, page clock) and `done` (`load`, or every `.mermaid-diagram` finished). "Launch to done" is wall-clock from starting `qlmanage -p` to the `done` beacon, so it includes `qlmanage` starting up. The extension's own Swift render time (from `markdown-render`, Release build) runs before the page and is added in the last column.

| File | Launch to done, 4 runs (3 for stress files) | Page clock: paint / done | Swift render | Target | Result |
|---|---|---|---|---|---|
| `readme-300.md` (300 lines, no diagrams) | 495, 431, 438, 387 ms | paint 177 to 201 ms after done 32 to 36 ms; fully painted by about 640 ms | 7 to 10 ms | 1 s | Met |
| `diagrams-14.md` (14 diagrams) | 1,097, 1,151, 1,129, 1,099 ms | paint 114 to 232 ms, done 605 to 705 ms, 14 of 14 rendered | 30 to 35 ms | 2.9 s | Met (about 1.2 s) |
| `lines-5000.md` (5,000 lines) | 439, 439, 426 ms | done 75 to 77 ms, paint 226 ms | 19 to 20 ms | no timeout, not blank | Met |
| `diagrams-30.md` (30 diagrams) | 1,739, 1,637, 1,661 ms | paint 241 to 254 ms, done 1,210 to 1,228 ms, 30 of 30 rendered, 0 errors | 31 to 34 ms | no timeout, not blank | Met |

Text painted before the diagrams finished in every diagram run (paint about 0.1 to 0.25 s, done 0.6 to 1.2 s), which is the "text appears without waiting for diagrams" requirement. The real extension then previewed `lines-5000.md` and `diagrams-30.md` in Quick Look; screenshots showed rendered text and diagrams, with no blank preview and no timeout. Mermaid met the 2.9 s target, so no follow-up change to evaluate Pele is needed.
