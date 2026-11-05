import Foundation
import Testing
@testable import MarkdownRenderer

// Regression tests for the code review of 2026-11-05. Each test reproduces one finding.

private func render(_ md: String) -> String { MarkdownRenderer.renderBody(md).html }

// MARK: Sanitizer

@Test func unparseableTagIsEscapedNotPassedThrough() {
    let html = render("<div>\n<img src=\"https://e.example/x.png\" data-x=\"1\" title='oops\n</div>\n")
    #expect(!html.contains("<img"))
    #expect(html.contains("&lt;img"))
    // Every '<' left in the body starts a tag the sanitizer emitted.
    for token in HTMLTokenizer.tokenize(html) {
        if case let .text(t) = token { #expect(!t.contains("<"), "unescaped < in text: \(t)") }
    }
}

@Test func userIdAndNameArePrefixedLikeGitHub() {
    let html = render("<img name=\"querySelectorAll\" src=\"https://e.example/a.png\">\n\n<a name=\"here\"></a> <a id=\"x\" href=\"#here\">jump</a>\n")
    #expect(html.contains("name=\"user-content-querySelectorAll\""))
    #expect(html.contains("name=\"user-content-here\""))
    #expect(html.contains("id=\"user-content-x\""))
    #expect(html.contains("href=\"#user-content-here\""), "in-page links follow the prefixed target")
    #expect(!html.contains("name=\"querySelectorAll\""))
}

@Test func headingLinksAndFootnotesResolveWithPrefixedIds() {
    let html = render("# Setup\n\nSee [setup](#setup) and a note[^1].\n\n[^1]: The note.\n")
    #expect(html.contains("id=\"user-content-setup\""))
    #expect(html.contains("href=\"#user-content-setup\""))
    #expect(!html.contains("href=\"#setup\""))
    // Every in-page link points at an id that exists.
    let tokens = HTMLTokenizer.tokenize(html)
    let ids = Set(tokens.compactMap { $0.attribute("id") } + tokens.compactMap { $0.attribute("name") })
    for href in tokens.compactMap({ $0.attribute("href") }) where href.hasPrefix("#") {
        #expect(ids.contains(String(href.dropFirst())), "dangling \(href)")
    }
}

@Test func unclosedDroppedElementDoesNotSwallowTheDocument() {
    for tag in ["svg", "video", "math", "select", "canvas"] {
        let html = render("Text <\(tag)> inline\n\n# Later heading\n\nMore text\n")
        #expect(html.contains("Later heading"), "<\(tag)> swallowed the heading")
        #expect(html.contains("More text"), "<\(tag)> swallowed the text")
        #expect(html.contains("</p>"))
    }
    // A closed one is still removed with its content.
    #expect(!render("A <svg><text>hidden</text></svg> B\n").contains("hidden"))
}

@Test func selfClosingNonVoidElementsAreClosed() {
    #expect(render("<span/>after span\n") == "<p><span></span>after span</p>\n")
    let html = render("<a href=\"https://x.example\"/>\n\nNext paragraph\n")
    #expect(html.contains("<a href=\"https://x.example\"></a>"))
    #expect(html.contains("<p>Next paragraph</p>"))
    #expect(render("a<br/>b\n").contains("<br />"))
}

// MARK: Front matter

@Test func multiLinePlainScalarStopsAtTheNextKey() {
    #expect(FrontMatter.parse("key:\n  some text\n  more text\nother: x") == .mapping([("key", .scalar("some text more text")), ("other", .scalar("x"))]))
}

@Test func invalidFrontMatterFallsBackToMarkdown() {
    #expect(FrontMatter.parse("title: x\nSome prose here\nmore: y") == nil)
    let html = render("---\ntitle: x\nSome prose here\nmore: y\n---\n\nbody\n")
    #expect(html.contains("Some prose here"))
    #expect(html.contains("more: y"))
    #expect(html.contains("body"))
    // Valid front matter still renders as a table.
    #expect(render("---\ntitle: x\nmore: y\n---\n\nbody\n").hasPrefix("<table>"))
}

// MARK: Alerts

@Test func alertsOnlyAtTopLevel() {
    #expect(render("> [!NOTE]\n> text\n").contains("markdown-alert-note"))
    for md in ["- item\n\n  > [!NOTE]\n  > text\n", "<details>\n\n> [!NOTE]\n> text\n\n</details>\n", "> outer\n>\n> > [!NOTE]\n> > text\n"] {
        let html = render(md)
        #expect(!html.contains("markdown-alert"), "alert rendered in: \(md)")
        #expect(html.contains("[!NOTE]"))
    }
}

// MARK: Text decoding

@Test func latin1FileDecodesAsLatin1() {
    let latin1 = Data([0x43, 0x61, 0x66, 0xE9, 0x20, 0x6E, 0x61, 0xEF, 0x76, 0x65]) // "Café naïve" in ISO-8859-1
    #expect(MarkdownRenderer.decodeText(latin1) == "Café naïve")
    #expect(MarkdownRenderer.decodeText(Data("\u{FEFF}# Hi".utf8)) == "# Hi")
    #expect(MarkdownRenderer.decodeText(Data("Café".utf8)) == "Café")
}

// MARK: Images

private struct ImageDir {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("md-review-\(UUID().uuidString)")
    init() throws { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    func write(_ name: String, bytes: Int) throws { try Data(repeating: 1, count: bytes).write(to: root.appendingPathComponent(name)) }
    func remove() { try? FileManager.default.removeItem(at: root) }
}

@Test func totalImageBytesAreCapped() throws {
    let dir = try ImageDir(); defer { dir.remove() }
    for k in 1...5 { try dir.write("p\(k).png", bytes: 1000) }
    let md = (1...5).map { "![alt\($0)](p\($0).png)" }.joined(separator: "\n") + "\n"
    let page = MarkdownRenderer.renderPage(md, options: .init(baseDirectory: dir.root, maxImageBytes: 2000, maxTotalImageBytes: 3000, nonce: "N"))
    #expect(page.attachments.count == 3)
    #expect(page.attachments.reduce(0) { $0 + $1.data.count } <= 3000)
    #expect(page.html.contains("alt4") && page.html.contains("alt5"), "images over the total show as alt text")
    #expect(MarkdownRenderer.PageOptions().maxTotalImageBytes == 50 * 1024 * 1024)
}

@Test func symlinkedImageIsAttached() throws {
    let dir = try ImageDir(); defer { dir.remove() }
    try dir.write("real.png", bytes: 10)
    try FileManager.default.createSymbolicLink(at: dir.root.appendingPathComponent("link.png"), withDestinationURL: dir.root.appendingPathComponent("real.png"))
    try Data("secret".utf8).write(to: dir.root.appendingPathComponent("notes.txt"))
    try FileManager.default.createSymbolicLink(at: dir.root.appendingPathComponent("sneaky.png"), withDestinationURL: dir.root.appendingPathComponent("notes.txt"))
    let page = MarkdownRenderer.renderPage("![a](link.png) ![b](sneaky.png)\n", options: .init(baseDirectory: dir.root, nonce: "N"))
    #expect(page.attachments.count == 1, "a symlink to an image attaches; a symlink to a non-image does not")
    #expect(page.attachments.first?.data.count == 10)
}

// MARK: Highlighting

@Test func plainTextFencesDoNotLoadTheHighlighter() {
    for lang in ["text", "plaintext", "txt", "plain"] {
        let body = MarkdownRenderer.renderBody("```\(lang)\nhello\n```\n")
        #expect(body.highlightedCount == 0, "```\(lang) loaded highlight.js")
        #expect(!body.html.contains("language-"))
    }
    #expect(MarkdownRenderer.renderBody("```swift\nlet x = 1\n```\n").highlightedCount == 1)
}
