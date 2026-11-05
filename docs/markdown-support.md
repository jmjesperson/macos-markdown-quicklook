# Markdown support

What GitHub renders in a `.md` file, element by element, and what this Quick Look extension renders. v1 must render everything GitHub documents for markdown files, except the items Jonny moved to Later on 2026-11-05 (math, GeoJSON, TopoJSON, STL).

**Status values:** **v1** (rendered as GitHub does), **Partial** (shown, but one part can't work in a local preview; the reason is in Notes), **Later** (not in v1), **No** (does not apply to a local markdown file).

**Sources** (all read 2026-11-05):

- [B] GitHub Docs, Basic writing and formatting syntax: https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax
- [A] GitHub Docs, Working with advanced formatting: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting
- [C] GitHub Docs, Creating and highlighting code blocks: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-and-highlighting-code-blocks
- [D] GitHub Docs, Creating diagrams: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams
- [M] GitHub Docs, Writing mathematical expressions: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/writing-mathematical-expressions

## Text and structure

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| Headings | `# Title` to `###### Title` | Yes [B] | v1 | |
| Section anchors | `[see setup](#setup)` | Yes [B] | v1 | Generate heading IDs the way GitHub does so in-page links resolve. As on GitHub, every `id` and `name` gets a `user-content-` prefix; `#` links get the same prefix, so they resolve without GitHub's page script. |
| Custom anchors | `<a name="here"></a>` | Yes [B] | v1 | Written as `name="user-content-here"`, as on GitHub. |
| Bold, italic, bold and italic | `**b**`, `*i*`, `***bi***` | Yes [B] | v1 | |
| Strikethrough | `~~old~~` | Yes [B] | v1 | GFM extension in cmark-gfm. |
| Subscript, superscript, underline | `<sub>`, `<sup>`, `<ins>` | Yes [B] | v1 | Inline HTML. |
| Block quotes | `> quoted` | Yes [B] | v1 | |
| Alerts | `> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]` | Yes [B] | v1 | Not part of cmark-gfm; added in the Swift step. |
| Line breaks | two trailing spaces, `\`, `<br/>` | Yes [B] | v1 | |
| Paragraphs | blank line between blocks | Yes [B] | v1 | |
| Backslash escapes | `\*not italic\*` | Yes [B] | v1 | |
| Hidden comments | `<!-- note -->` | Yes [B] | v1 | Not shown. |
| Collapsed sections | `<details><summary>` | Yes [A] | v1 | |
| Emoji shortcodes | `:rocket:` | Yes [B] | v1 | Bundled table from gemoji v4.1.0. GitHub's image-only custom emoji (`:octocat:`, `:shipit:`) stay as text, because GitHub serves them as images from its CDN. |
| Footnotes | `text[^1]` and `[^1]: note` | Yes [B] | v1 | cmark-gfm parser option. |

## Lists and tables

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| Unordered lists | `-`, `*`, `+` | Yes [B] | v1 | |
| Ordered lists | `1.` | Yes [B] | v1 | |
| Nested lists | indented items | Yes [B] | v1 | |
| Task lists | `- [ ]`, `- [x]` | Yes [B] | v1 | Checkboxes are read-only, as in a GitHub file view. |
| Tables | pipe tables with alignment | Yes [A] | v1 | GFM extension in cmark-gfm. |

## Code

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| Inline code | `` `code` `` | Yes [B] | v1 | |
| Fenced code blocks | ```` ``` ```` | Yes [B] | v1 | |
| Syntax highlighting | ```` ```swift ```` | Yes [C] | v1 | GitHub uses Linguist to pick grammars [C]. The bundled highlighter must work offline and load only when a fenced block names a language. |

## Links and images

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| Inline links | `[text](https://…)` | Yes [B] | Partial | Rendered as links. In the 2026-11-05 spike a click under `qlmanage -p` opened the default browser (`docs/spike-notes.md`); the Finder space-bar preview is `[UNVERIFIED — Jonny to click a link once]`. MarkEdit reports links do not open from its web-view preview (https://github.com/MarkEdit-app/MarkEdit/issues/1718). |
| Autolinked URLs | `https://example.com` | Yes [B] | v1 | GFM extension in cmark-gfm. Same click caveat as inline links. |
| Relative links to files | `[guide](docs/guide.md)` | Yes [B] | Partial | Shown as links. Opening another file from a preview is not expected to work. |
| Images | `![alt](https://…)` | Yes [B] | Partial | Remote `https:` images load: the extension holds the network-client entitlement and the page's policy admits `https:` images (checked in Quick Look on 2026-11-05). `http:` images are blocked by that policy. They are fetched from the image's host directly, where GitHub proxies them through its own image cache. |
| Relative images | `![alt](./img/a.png)` | Yes [B] | v1 | Read in Swift and attached to the preview reply as `cid:` data (Apple: https://developer.apple.com/documentation/quicklook/qlpreviewreply/attachments). A leading `/` resolves against the nearest folder holding `.git`. Symlinks are followed if the target is also an image file. Files outside the home folder, files over 10 MB, non-image files, and images past a 50 MB total for the page render as alt text (`docs/spike-notes.md`). |
| Picture element | `<picture><source media="(prefers-color-scheme: dark)">` | Yes [B] | v1 | Common in READMEs for light and dark logos. |

## GitHub-only references

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| Mentions | `@octocat`, `@org/team` | Yes [B] | Partial | Styled as GitHub styles them, not linked: a local file has no repo or server behind it. |
| Issue and PR references | `#123` | Yes [B] | Partial | Same as mentions. |
| Autolinked commit and URL references | a commit SHA | Yes [A] | Partial | Same as mentions. |
| Custom autolink references | `JIRA-123` linked by a repo setting | Yes [B] | No | Configured per repository on GitHub; there is no repo setting to read. |
| Permanent code snippet links | link to a line range | Yes [A] | Partial | Shown as an ordinary link. |
| Color model previews | `` `#0969DA` `` | Issues, PRs and discussions only [B] | No | GitHub does not render these in markdown files. |
| Asset uploads | drag and drop | Yes [B] | No | An editing feature, not rendering. |
| Outline menu | file view table of contents | Yes [B] | Later | Part of GitHub's file-view chrome rather than the markdown. |

## Diagrams and math

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| Mermaid | ```` ```mermaid ```` | Yes [D] | v1 | Bundled, offline, loaded only when a mermaid block is present. |
| GeoJSON maps | ```` ```geojson ```` | Yes [D] | Later | Jonny, 2026-11-05. |
| TopoJSON maps | ```` ```topojson ```` | Yes [D] | Later | Jonny, 2026-11-05. |
| STL 3D models | ```` ```stl ```` | Yes [D] | Later | Jonny, 2026-11-05. |
| Math | `$x$`, `$$…$$`, ```` ```math ```` | Yes, rendered with MathJax [M] | Later | Jonny, 2026-11-05. |

## Front matter

| Element | Example | GitHub | Status | Notes |
|---|---|---|---|---|
| YAML front matter | `---` block at the top | Yes, as a table (file view of https://github.com/github/docs/blob/main/content/index.md, checked 2026-11-05) | v1 | One row per top-level key (`<th>` key, `<td>` value); a nested mapping is a table with its keys as the header row; a list is a one-row table. Flow collections (`[a, b]`) show as text. |
