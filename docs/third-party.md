# Third-party components

Everything below ships inside the app, in the preview extension's `MarkdownRenderer_MarkdownRenderer.bundle`. Licence texts are in `Packages/MarkdownRenderer/Sources/MarkdownRenderer/Resources/licenses/`, which the bundle carries as `Resources/licenses/`. All versions were pinned on 2026-11-05. For npm packages, the integrity hash of each downloaded tarball was checked against `npm view <package>@<version> dist.integrity`.

| Component | Version | Licence | Licence file | Source | What ships |
|---|---|---|---|---|---|
| cmark-gfm (`swift-cmark`) | 0.9.0, commit `08ddb528923cc1a6527e02b7a1aee9e516ca749a` | BSD-2-Clause and others, per its `COPYING` | `cmark-gfm-COPYING.txt` | https://github.com/swiftlang/swift-cmark | Compiled into the extension through Swift Package Manager (`Package.swift`, `exact: "0.9.0"`). |
| github-markdown-css | 5.9.0 (npm `sha512-tmT5sY+zvg2302XLYEfH2mtkViIM1SWf2nvYoF5N1ZsO0V6B2qZTiw3GOzw4vpjLygK/KG35qRlPFweHqfzz5w==`) | MIT | `github-markdown-css-LICENSE.txt` | https://github.com/sindresorhus/github-markdown-css | `github-markdown.css` (the light and dark file that follows `prefers-color-scheme`). |
| highlight.js | 11.12.0, from `@highlightjs/cdn-assets` (npm `sha512-KvOKXODaiFmId9xaq3xc5xCL66wVLUuOngDbO9B/kewbFTqdGbn2nJxNhN3H5R1cgDTVj6R8vH0zgiNDEGjpDw==`) | BSD-3-Clause | `highlight.js-LICENSE.txt` | https://github.com/highlightjs/highlight.js | `highlight.min.js` (the package's common bundle with `dockerfile`, `powershell`, `protobuf`, `scala`, `groovy`, `dart`, `elixir`, `haskell`, `nginx`, `cmake`, `clojure`, `erlang`, `fsharp`, `ocaml`, `julia` and `nix` appended from `languages/`), `styles/github.min.css` and `styles/github-dark.min.css` (shipped as `highlight-github.min.css` and `highlight-github-dark.min.css`). |
| Mermaid | 12.3.0 (npm `sha512-4113TdXeLAsMruJ79OpFL5O8+LTFXhQqZ260rF3tgUmiNAtRm4Uume04I+65PRN6yZ69J4f8rVYWW8zRk65UYw==`) | MIT | `mermaid-LICENSE.txt` | https://github.com/mermaid-js/mermaid | `dist/mermaid.min.js`, 5,537,838 bytes. |
| gemoji | v4.1.0, commit `5476a66d2794e0d1551b1f96e449afc72e9f7bec` | MIT | `gemoji-LICENSE.txt` | https://github.com/github/gemoji | `emoji.json`: the alias-to-emoji pairs from `db/emoji.json`, 1,913 aliases. |
| Octicons | 19.42.0, from `@primer/octicons` (npm `sha512-MEcHxVxNHu1I2Ndk5Mcwp7tfBiDk/EpytDJgKOfE2ldqIczWucVrZNeNU4wtEN5mnNudZ0YL5G0spax3bSMT4w==`) | MIT | `octicons-LICENSE.txt` | https://github.com/primer/octicons | The five alert icon paths (`info`, `light-bulb`, `report`, `alert`, `stop`) in `GitHubFilters.swift`, as GitHub's `/markdown` API returned them on 2026-11-05. |

## Updating a component

Replace the file in `Resources/`, update its row here (version, integrity, size), and run `swift test --package-path Packages/MarkdownRenderer`. `ThirdPartyTests` checks that every licence file named here ships in the bundle.
