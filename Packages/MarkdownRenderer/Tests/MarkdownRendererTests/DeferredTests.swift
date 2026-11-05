import Testing
@testable import MarkdownRenderer

@Test(arguments: ["math", "geojson", "topojson", "stl"])
func deferredFencesAreNotHighlightedOrDiagrams(_ lang: String) {
    let body = MarkdownRenderer.renderBody("```\(lang)\nsource\n```\n")
    #expect(body.html == "<pre><code>source\n</code></pre>\n")
    #expect(body.highlightedCount == 0)
    #expect(body.mermaidCount == 0)
}
