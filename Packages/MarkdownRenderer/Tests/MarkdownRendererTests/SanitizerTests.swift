import Foundation
import Testing
@testable import MarkdownRenderer

@Test func activeContentIsRemoved() throws {
    let html = MarkdownRenderer.renderBody(try Fixtures.markdown("html/removed")).html.lowercased()
    for banned in ["<script", "onerror", "onclick", "onload", "javascript", "<iframe", "style=", "<style",
                   "<svg", "<object", "<embed", "<meta", "<form", "data:", "class=\"evil\""] {
        #expect(!html.contains(banned), "found \(banned)")
    }
    #expect(html.contains("text after the dropped elements still renders."))
    // As on GitHub, a script tag shows as text rather than disappearing.
    #expect(html.contains("&lt;script>document.body.innerhtml='pwned'&lt;/script>"))
}

@Test func allowedElementsSurvive() throws {
    let tokens = HTMLTokenizer.tokenize(MarkdownRenderer.renderBody(try Fixtures.markdown("html/allowed")).html)
    let names = Set(tokens.compactMap(\.startName))
    for element in ["sub", "sup", "ins", "br", "a", "details", "summary", "picture", "source", "img", "kbd", "s",
                    "mark", "div", "td", "dl", "dt", "dd"] {
        #expect(names.contains(element), "missing <\(element)>")
    }
    let anchor = tokens.first { $0.startName == "a" && $0.hasAttribute("name") }
    #expect(anchor?.attribute("name") == "user-content-here")
    let source = tokens.first { $0.startName == "source" }
    #expect(source?.attribute("media") == "(prefers-color-scheme: dark)")
    #expect(source?.attribute("srcset") == "https://example.com/dark.png")
    let img = tokens.first { $0.startName == "img" }
    #expect(img?.attribute("width") == "100" && img?.attribute("height") == "50" && img?.attribute("alt") == "Logo")
    #expect(tokens.first { $0.startName == "details" }?.hasAttribute("open") == true)
    #expect(!tokens.contains { if case .comment = $0 { return true } else { return false } })
}

@Test(arguments: [
    ("https://example.com", true), ("http://x", true), ("mailto:a@b.c", true), ("docs/a.md", true), ("#top", true),
    ("../a/b:c", true), ("javascript:alert(1)", false), (" JAVASCRIPT:x", false), ("java\tscript:x", false),
    ("vbscript:x", false), ("data:text/html,x", false), ("file:///etc/passwd", false),
])
func urlSchemes(_ url: String, _ safe: Bool) {
    #expect(Sanitizer.urlIsSafe(url, schemes: Sanitizer.urlAttributes["href"]!) == safe)
}
