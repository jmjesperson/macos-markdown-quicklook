import Foundation
import Testing
@testable import MarkdownRenderer

private let everything = "# T\n\n```swift\nlet x = 1\n```\n\n```mermaid\nflowchart LR\n  A --> B\n```\n<script>alert(1)</script>\n"

@Test func pageCarriesNonceContentSecurityPolicy() {
    let page = MarkdownRenderer.renderPage(everything)
    let tokens = HTMLTokenizer.tokenize(page.html)
    let csp = tokens.first { $0.startName == "meta" && $0.attribute("http-equiv") == "Content-Security-Policy" }
    #expect(csp?.attribute("content") == "default-src 'none'; script-src 'nonce-\(page.nonce)'; style-src 'nonce-\(page.nonce)'; img-src cid: data: https:; base-uri 'none'; form-action 'none'")
    // The policy comes before any style or script.
    let cspIndex = tokens.firstIndex { $0.attribute("http-equiv") == "Content-Security-Policy" }!
    let firstActive = tokens.firstIndex { $0.startName == "script" || $0.startName == "style" }!
    #expect(cspIndex < firstActive)
}

@Test func everyBundledScriptAndStyleCarriesTheNonce() {
    let page = MarkdownRenderer.renderPage(everything)
    let tokens = HTMLTokenizer.tokenize(page.html)
    let scripts = tokens.filter { $0.startName == "script" }
    let styles = tokens.filter { $0.startName == "style" }
    #expect(scripts.count == 4) // highlight.js, its init, Mermaid, its init
    #expect(styles.count == 2)  // GitHub CSS + page CSS, highlight themes
    for element in scripts + styles {
        #expect(element.attribute("nonce") == page.nonce, "\(element)")
    }
    // The file's own <script> is shown as text, never as an element.
    #expect(page.html.contains("&lt;script>alert(1)&lt;/script>"))
}

@Test func noncesAreRandomPerPage() {
    let a = MarkdownRenderer.renderPage("x").nonce
    let b = MarkdownRenderer.renderPage("x").nonce
    #expect(a != b)
    #expect(a.count >= 24)
}

@Test func bundledScriptsAreUnchangedByTheScriptCloseGuard() {
    for name in ["mermaid.min.js", "highlight.min.js", "highlight-init.js", "mermaid-init.js"] {
        #expect(!Assets.text(name).contains("</script"), "\(name) contains </script")
    }
}
