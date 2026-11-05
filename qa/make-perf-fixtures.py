#!/usr/bin/env python3
"""Writes the speed and stress fixtures for tasks 9.2 and 9.3 into the given folder (default build/qa/perf):
readme-300.md (300 lines, no diagrams), diagrams-14.md, lines-5000.md, diagrams-30.md."""
import os, sys

out = sys.argv[1] if len(sys.argv) > 1 else "build/qa/perf"
os.makedirs(out, exist_ok=True)

def readme(lines):
    parts, n, section = [], 0, 0
    while n < lines:
        section += 1
        block = [
            f"## Section {section}", "",
            f"This paragraph explains part {section} with **bold**, *italic*, `code` and a [link](https://example.com/{section}).",
            "", "- first point", "- second point with :rocket:", "- [x] a finished task", "",
            "| Key | Value |", "|:--|--:|", f"| item {section} | {section * 3} |", "",
            "```swift", f"let value{section} = {section} // comment", "print(value)", "```", "",
            "> [!NOTE]", f"> Note number {section}.", "",
        ]
        parts += block
        n += len(block)
    return "\n".join(["# Performance README", ""] + parts[: lines - 2]) + "\n"

DIAGRAMS = [
    "flowchart LR\n  A[Start] --> B{Check}\n  B -->|yes| C[Done]\n  B -->|no| D[Retry] --> B",
    "sequenceDiagram\n  Alice->>Bob: Hello\n  Bob-->>Alice: Hi\n  Alice->>Carol: Ping",
    "classDiagram\n  Animal <|-- Duck\n  Animal : +int age\n  class Duck{\n    +swim()\n  }",
    "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Busy\n  Busy --> [*]",
    "erDiagram\n  CUSTOMER ||--o{ ORDER : places\n  ORDER ||--|{ ITEM : contains",
    "gantt\n  dateFormat YYYY-MM-DD\n  section A\n  Task :a1, 2026-01-01, 10d\n  Next :after a1, 5d",
    "pie title Share\n  \"A\" : 40\n  \"B\" : 60",
]

def diagrams(count):
    parts = ["# Diagrams", ""]
    for i in range(count):
        parts += [f"Diagram {i + 1}:", "", "```mermaid", DIAGRAMS[i % len(DIAGRAMS)], "```", ""]
    return "\n".join(parts)

files = {"readme-300.md": readme(300), "diagrams-14.md": diagrams(14), "lines-5000.md": readme(5000), "diagrams-30.md": diagrams(30)}
for name, text in files.items():
    with open(os.path.join(out, name), "w") as f:
        f.write(text)
    print(name, text.count("\n"), "lines,", text.count("```mermaid"), "diagrams")
