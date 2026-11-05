import Testing
@testable import MarkdownRenderer

private func page(_ md: String) -> String { MarkdownRenderer.renderPage(md).html }

private func includesHighlighter(_ md: String) -> Bool {
    let html = page(md)
    return html.contains(Assets.text("highlight.min.js")) && html.contains(Assets.text("highlight-github.min.css"))
}

@Test(arguments: [
    "```swift\nlet x = 1\n```\n",
    "~~~python\nprint(1)\n~~~\n",
    "```notalanguage\nplain\n```\n", // named, so loaded; the init script skips languages it doesn't know
])
func highlighterIncludedWhenAFenceNamesALanguage(_ md: String) {
    #expect(includesHighlighter(md))
}

@Test(arguments: [
    "# Plain README\n\nText and `inline code`.\n",
    "```\nno language\n```\n",
    "    indented code\n",
    "```mermaid\nflowchart LR\n  A --> B\n```\n",
    "```math\nx^2\n```\n",
])
func highlighterOmittedOtherwise(_ md: String) {
    #expect(!includesHighlighter(md))
    #expect(!page(md).contains(Assets.text("highlight-init.js")))
}

@Test func onlyNamedBlocksGetALanguageClass() {
    let body = MarkdownRenderer.renderBody("```swift\na\n```\n\n```\nb\n```\n").html
    #expect(body == "<pre><code class=\"language-swift\">a\n</code></pre>\n<pre><code>b\n</code></pre>\n")
}
