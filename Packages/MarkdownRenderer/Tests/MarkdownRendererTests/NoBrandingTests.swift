import Foundation
import Testing
@testable import MarkdownRenderer

/// The page holds only the document: the 101st render matches the first, and the article contains
/// nothing beyond what the markdown produced.
@Test func hundredAndFirstRenderHoldsOnlyTheDocument() {
    let md = "# Doc\n\nOnly this text.\n"
    let first = MarkdownRenderer.renderPage(md, options: .init(nonce: "N")).html
    var last = ""
    for _ in 0..<101 { last = MarkdownRenderer.renderPage(md, options: .init(nonce: "N")).html }
    #expect(first == last)
    let article = last.components(separatedBy: "<article class=\"markdown-body\">\n")[1].components(separatedBy: "</article>")[0]
    #expect(article == MarkdownRenderer.renderBody(md).html)
    let afterArticle = last.components(separatedBy: "</article>\n")[1]
    #expect(afterArticle == "</body>\n</html>\n")
    for word in ["coffee", "donat", "sponsor", "version", "powered by", "footer"] {
        #expect(!(article + afterArticle).lowercased().contains(word), "\(word)")
    }
}
