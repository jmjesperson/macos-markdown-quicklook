import Testing
@testable import MarkdownRenderer

private func includesMermaid(_ md: String) -> Bool {
    let html = MarkdownRenderer.renderPage(md).html
    let library = html.contains(Assets.text("mermaid.min.js"))
    #expect(library == html.contains(Assets.text("mermaid-init.js")))
    return library
}

@Test(arguments: [
    "```mermaid\nflowchart LR\n  A --> B\n```\n",
    "Text\n\n~~~mermaid\nsequenceDiagram\n  A->>B: hi\n~~~\n",
    "```Mermaid\npie\n  \"a\": 1\n```\n",
])
func mermaidIncludedWhenABlockExists(_ md: String) {
    #expect(includesMermaid(md))
}

@Test(arguments: [
    "# Plain README\n\nNo diagrams here.\n",
    "```\nflowchart LR\n  A --> B\n```\n",          // no language
    "```js\nconst mermaid = 1\n```\n",             // the word, not the language
    "`mermaid` inline code\n",
])
func mermaidOmittedWithoutABlock(_ md: String) {
    #expect(!includesMermaid(md))
}

@Test func blockSourceIsKeptForTheRendererAndForErrors() {
    let body = MarkdownRenderer.renderBody("```mermaid\nflowchart LR\n  A --> B & C\n```\n")
    #expect(body.mermaidCount == 1)
    #expect(body.html == "<div class=\"mermaid-diagram\" data-state=\"pending\"><pre class=\"mermaid-source\"><code>flowchart LR\n  A --&gt; B &amp; C\n</code></pre></div>\n")
}

@Test func themeFollowsAppearance() {
    let script = Assets.text("mermaid-init.js")
    #expect(script.contains("matchMedia('(prefers-color-scheme: dark)')"))
    #expect(script.contains("theme: dark ? 'dark' : 'default'"))
    #expect(script.contains("startOnLoad: false"))
}
