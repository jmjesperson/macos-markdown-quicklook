# quicklook-preview Specification

## Purpose
Lets a macOS user press space on a markdown file in Finder and see a rendered, unbranded, offline preview instead of plain text.

## Requirements

### Requirement: Previews markdown files in Quick Look
The extension SHALL provide the Quick Look preview for files whose type conforms to `net.daringfireball.markdown`, which is the type macOS assigns to `.md` files.

#### Scenario: Space bar on a README
- **WHEN** the user selects `README.md` in Finder and presses space
- **THEN** Quick Look shows the rendered markdown, not the file's plain text

#### Scenario: Other markdown extension
- **WHEN** the user presses space on a file with the `.markdown` extension
- **THEN** Quick Look shows the rendered markdown

### Requirement: Enabled by launching the host app once
Installing the app in `/Applications` and launching it once SHALL make the extension available to Quick Look, and the host app SHALL tell the user whether the extension is enabled and how to enable it if it is not.

#### Scenario: First launch
- **WHEN** the user launches the app for the first time after copying it to `/Applications`
- **THEN** the app window states whether the preview extension is enabled and, if it is not, where in System Settings to enable it

### Requirement: No branding in the preview
The preview SHALL contain only the rendered document. It SHALL NOT show a footer, watermark, donation request, render count, version banner or any other content that is not in the file.

#### Scenario: Hundredth preview
- **WHEN** the user has previewed 100 or more files
- **THEN** the next preview contains only the rendered document

### Requirement: Renders without a network connection
Everything the preview needs to render the file's text, code highlighting and diagrams SHALL be bundled in the app. Rendering SHALL NOT depend on reaching any network host.

#### Scenario: Offline diagram
- **WHEN** the Mac has no network connection and the user previews a file containing a Mermaid block
- **THEN** the text and the diagram both render

### Requirement: Sends no data
The app and extension SHALL NOT send telemetry, analytics or file content to any host.

#### Scenario: Network monitor during preview
- **WHEN** a network monitor watches the extension while it previews a file that has no remote images
- **THEN** no outbound connection is made

### Requirement: Follows system appearance
The preview SHALL use GitHub's light style when macOS is in Light appearance and GitHub's dark style when macOS is in Dark appearance.

#### Scenario: Dark mode
- **WHEN** macOS is set to Dark appearance and the user previews a file
- **THEN** the preview uses a dark background with light text in GitHub's dark style

### Requirement: Active content in a file does not run
Script in a previewed file, from a `<script>` tag, an event-handler attribute such as `onerror`, or a `javascript:` URL, SHALL NOT execute. Only scripts bundled with the app SHALL run.

#### Scenario: Script tag in a file
- **WHEN** the user previews a file containing `<script>document.body.innerHTML='pwned'</script>`
- **THEN** the script does not run and the rest of the document renders normally

#### Scenario: Event handler on an image
- **WHEN** the user previews a file containing `<img src="x" onerror="alert(1)">`
- **THEN** no handler runs

### Requirement: Text appears without waiting for diagrams
The rendered text of a document SHALL be visible before, and independently of, any diagram finishing rendering.

#### Scenario: Large diagram
- **WHEN** the user previews a file whose first block is a large Mermaid diagram followed by text
- **THEN** the text is visible while the diagram is still rendering

### Requirement: Preview speed
On the development Mac, a preview of a markdown file with no diagrams SHALL be fully rendered within 1 second, and a preview of a file with 14 Mermaid diagrams SHALL be fully rendered within 2.9 seconds. These thresholds are the builder's call, set from a QLMarkdown measurement of 2.93 seconds median for 14 diagrams (https://github.com/sbarex/QLMarkdown/issues/255).

#### Scenario: Plain README
- **WHEN** the user previews a 300-line README with no diagrams
- **THEN** the preview is fully rendered within 1 second of pressing space

#### Scenario: Diagram-heavy document
- **WHEN** the user previews a file with 14 Mermaid diagrams
- **THEN** all diagrams are rendered within 2.9 seconds of pressing space
