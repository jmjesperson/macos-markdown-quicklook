# Spec Delta

## Purpose

Defines which markdown elements the preview renders and how, using GitHub's documented markdown behaviour as the baseline so developer documentation looks the way it does on github.com.

## ADDED Requirements

### Requirement: GitHub baseline
Every element marked **v1** in `docs/markdown-support.md` SHALL render as GitHub renders it in a markdown file view. Every element marked **Partial** SHALL render as that row's Notes describe. That table is the conformance list for this capability.

#### Scenario: Conformance fixture
- **WHEN** the user previews a fixture file containing one example of every v1 and Partial row in `docs/markdown-support.md`
- **THEN** each example renders as its row describes

### Requirement: GitHub Flavored Markdown core
Headings, emphasis, strikethrough, block quotes, ordered, unordered and nested lists, task lists, pipe tables with column alignment, footnotes, autolinked URLs, fenced and inline code, line breaks and backslash escapes SHALL render as GitHub Flavored Markdown.

#### Scenario: Table with alignment
- **WHEN** a file contains a pipe table whose delimiter row is `|:--|:-:|--:|`
- **THEN** the table renders with left, centre and right aligned columns

#### Scenario: Footnote
- **WHEN** a file contains `text[^1]` and `[^1]: the note`
- **THEN** a superscript reference links to the note, which renders at the end of the document with a link back

### Requirement: Task lists are read-only
Task list items SHALL render as checkboxes reflecting `[ ]` or `[x]`, and the checkboxes SHALL NOT be toggleable.

#### Scenario: Checked item
- **WHEN** a file contains `- [x] done` and `- [ ] todo`
- **THEN** the first renders with a checked box, the second with an empty box, and clicking either changes nothing

### Requirement: Alerts
Block quotes whose first line is `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` or `[!CAUTION]` SHALL render as GitHub alerts, each with GitHub's title, icon and colour for that type.

#### Scenario: Warning alert
- **WHEN** a file contains `> [!WARNING]` followed by `> Back up first.`
- **THEN** a warning alert titled "Warning" renders containing "Back up first."

### Requirement: Emoji shortcodes
Shortcodes in GitHub's emoji set, such as `:rocket:`, SHALL render as the emoji. A shortcode not in the set SHALL render as its literal text. Shortcodes inside code SHALL NOT be converted.

#### Scenario: Known and unknown shortcodes
- **WHEN** a file contains `:rocket: :not-a-real-emoji:` and `` `:rocket:` ``
- **THEN** the first renders as 🚀, the second as the literal text, and the code span keeps `:rocket:` as text

### Requirement: Heading anchors
Each heading SHALL get an ID generated the way GitHub generates it, so in-page links such as `[setup](#setup)` scroll to that heading. Duplicate headings SHALL get GitHub's numbered suffixes (`-1`, `-2`).

#### Scenario: In-page link
- **WHEN** a file contains `## Getting Started` and a link `[go](#getting-started)`
- **THEN** activating the link scrolls the preview to that heading

### Requirement: Syntax highlighting
Fenced code blocks that name a language SHALL render with syntax highlighting in GitHub-like colours for the current appearance. A block with no language, or a language the highlighter does not know, SHALL render as plain monospaced text.

#### Scenario: Swift block
- **WHEN** a file contains a fenced block tagged `swift`
- **THEN** keywords, strings and comments render in distinct colours

#### Scenario: Unknown language
- **WHEN** a fenced block is tagged `notalanguage`
- **THEN** it renders as plain monospaced text with no error

### Requirement: Allowed inline HTML
The HTML elements GitHub documents for markdown files, including `<sub>`, `<sup>`, `<ins>`, `<br>`, `<a name>`, `<details>`/`<summary>` and `<picture>`/`<source>`, SHALL render. HTML comments SHALL NOT be shown.

#### Scenario: Collapsed section
- **WHEN** a file contains `<details><summary>More</summary>Hidden text</details>`
- **THEN** a collapsed "More" section renders and expands to show "Hidden text" when clicked

#### Scenario: Picture for dark mode
- **WHEN** a file contains a `<picture>` with a `<source media="(prefers-color-scheme: dark)">` and macOS is in Dark appearance
- **THEN** the dark source's image is shown

### Requirement: Relative images
Images referenced by a path relative to the markdown file, such as `./img/a.png` or `../assets/logo.svg`, SHALL render when the image exists. A missing image SHALL render as its alt text without breaking the rest of the document.

#### Scenario: Image beside the file
- **WHEN** `docs/guide.md` contains `![diagram](img/flow.png)` and `docs/img/flow.png` exists
- **THEN** the image renders in the preview

#### Scenario: Missing image
- **WHEN** the referenced image file does not exist
- **THEN** the alt text renders in its place and the rest of the document renders normally

### Requirement: Links render as links
Inline links, autolinked URLs and relative links to other files SHALL render as links styled as GitHub styles them. What happens when a link is clicked in Quick Look is not specified by this change.

#### Scenario: Relative file link
- **WHEN** a file contains `[guide](docs/guide.md)`
- **THEN** "guide" renders styled as a link

### Requirement: GitHub-only references are styled, not linked
`@user` and `@org/team` mentions, `#123` issue and pull request references, and commit SHAs SHALL render in GitHub's styling for that reference type, without a link, because a local file has no repository behind it.

#### Scenario: Mention
- **WHEN** a file contains `Thanks @octocat`
- **THEN** "@octocat" renders bold, as GitHub styles mentions, and is not a link

### Requirement: YAML front matter
A YAML front-matter block at the very top of a file SHALL render as a table of its keys and values above the document, not as body text. `[UNVERIFIED — that GitHub renders front matter as a table; confirm before building and update this requirement if not]`

#### Scenario: README with front matter
- **WHEN** a file begins with `---`, `title: Guide`, `---`
- **THEN** a table with the row `title | Guide` renders above the document body

### Requirement: Deferred blocks render as code
Fenced blocks tagged `math`, `geojson`, `topojson` or `stl`, and `$…$` or `$$…$$` math, SHALL render as their source text, the fenced ones as plain code blocks, until a later change adds them.

#### Scenario: Math block
- **WHEN** a file contains a fenced block tagged `math`
- **THEN** its source renders as a plain code block
