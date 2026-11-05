# Quick Look checks

Files for checking the preview by hand: select one in Finder and press space, or run `qlmanage -p <file>`. Each check below was last run on 2026-11-05, and the results are in `docs/spike-notes.md`.

- `conformance.md`: one example of every v1 and Partial row in `docs/markdown-support.md`. Compare it with the same file on github.com (task 9.1).
- `diagrams/`: one file per Mermaid diagram type; `three-diagrams.md` (valid, invalid, valid); `wide.md` (scales to a narrow window).
- `security/`: the spec's `<script>` and `onerror` scenarios. Neither may change the page.
- `images/docs/guide.md`: a relative image, a light and dark `<picture>`, a missing image and a remote image.
- `highlight.md`, `dot-md.md`, `dot-markdown.markdown`: syntax highlighting, and both file extensions.
- `make-perf-fixtures.py`: writes the speed and stress files (300 lines, 14 diagrams, 5,000 lines, 30 diagrams) to `build/qa/perf`.
