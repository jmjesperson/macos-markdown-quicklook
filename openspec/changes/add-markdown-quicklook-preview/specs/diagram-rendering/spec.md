# Spec Delta

## Purpose

Renders Mermaid diagrams written in fenced `mermaid` code blocks inline in the preview, the way GitHub does, so architecture and flow documentation can be read in Quick Look.

## ADDED Requirements

### Requirement: Mermaid blocks render as diagrams
Each fenced code block tagged `mermaid` SHALL render as the diagram it describes, in place, in document order.

#### Scenario: Flowchart
- **WHEN** a file contains a fenced `mermaid` block with `flowchart LR` and `A --> B`
- **THEN** a diagram with nodes A and B joined by an arrow renders where the block was

#### Scenario: Several diagrams
- **WHEN** a file contains three `mermaid` blocks separated by text
- **THEN** three diagrams render, each in its own position between the text

### Requirement: Mermaid diagram types
Every diagram type supported by the bundled Mermaid version SHALL render, including at least flowchart, sequence, class, state, entity relationship, Gantt, pie and mindmap.

#### Scenario: Sequence diagram
- **WHEN** a file contains a `mermaid` block starting `sequenceDiagram`
- **THEN** a sequence diagram renders

### Requirement: Diagrams follow appearance
Diagrams SHALL use a light theme in Light appearance and a dark theme in Dark appearance, so they stay legible against the page.

#### Scenario: Dark mode diagram
- **WHEN** macOS is in Dark appearance and a file contains a flowchart
- **THEN** the diagram's text and lines are light on the dark page

### Requirement: Wide diagrams stay readable
A diagram wider than the preview SHALL scale down to fit the preview's width rather than being clipped.

#### Scenario: Wide flowchart
- **WHEN** a flowchart is wider than the Quick Look window
- **THEN** the whole diagram is visible within the window's width

### Requirement: A broken diagram does not break the document
When a `mermaid` block cannot be rendered, the preview SHALL show an error message and the block's source in its place, and every other diagram and all text SHALL still render.

#### Scenario: Syntax error
- **WHEN** a file contains a valid diagram, then a `mermaid` block with invalid syntax, then text
- **THEN** the valid diagram renders, the invalid block shows an error with its source, and the text renders

### Requirement: No diagram code for files without diagrams
Previewing a file with no `mermaid` blocks SHALL NOT load the diagram library.

#### Scenario: Plain README
- **WHEN** the user previews a file with no `mermaid` blocks
- **THEN** the page that Quick Look renders does not include the Mermaid library
