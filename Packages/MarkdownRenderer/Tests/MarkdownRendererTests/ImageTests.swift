import Foundation
import Testing
@testable import MarkdownRenderer

/// A throwaway repository: repo/.git, repo/assets/logo.svg, repo/docs/guide.md, repo/docs/img/flow.png …
private struct Repo {
    let root: URL
    var docs: URL { root.appendingPathComponent("docs") }
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4])

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("md-images-\(UUID().uuidString)")
        let fm = FileManager.default
        for dir in [".git", "assets", "docs/img"] {
            try fm.createDirectory(at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        try Repo.png.write(to: root.appendingPathComponent("docs/img/flow.png"))
        try Repo.png.write(to: root.appendingPathComponent("docs/img/dark mode.png"))
        try Data("<svg xmlns='http://www.w3.org/2000/svg'/>".utf8).write(to: root.appendingPathComponent("assets/logo.svg"))
        try Data(repeating: 7, count: 2048).write(to: root.appendingPathComponent("docs/img/big.png"))
        try Data("secret".utf8).write(to: root.appendingPathComponent("docs/notes.txt"))
    }

    func page(_ md: String, maxBytes: Int = 1024) -> MarkdownRenderer.Page {
        MarkdownRenderer.renderPage(md, options: .init(baseDirectory: docs, maxImageBytes: maxBytes, nonce: "N"))
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

private func body(_ page: MarkdownRenderer.Page) -> String {
    let html = page.html
    let start = html.range(of: "<article class=\"markdown-body\">\n")!.upperBound
    let end = html.range(of: "</article>")!.lowerBound
    return String(html[start..<end])
}

@Test func presentRelativeImagesAreAttached() throws {
    let repo = try Repo(); defer { repo.remove() }
    let page = repo.page("![diagram](img/flow.png) ![logo](../assets/logo.svg) ![root](/assets/logo.svg) ![spaced](img/dark%20mode.png)\n")
    #expect(body(page) == "<p><img src=\"cid:image-1.png\" alt=\"diagram\" /> <img src=\"cid:image-2.svg\" alt=\"logo\" /> <img src=\"cid:image-2.svg\" alt=\"root\" /> <img src=\"cid:image-3.png\" alt=\"spaced\" /></p>\n")
    #expect(page.attachments.map(\.id) == ["image-1.png", "image-2.svg", "image-3.png"])
    #expect(page.attachments[0].data == Repo.png)
    #expect(page.attachments[0].contentType == "public.png")
    #expect(page.attachments[1].contentType == "public.svg-image")
}

@Test func missingImageRendersAsAltText() throws {
    let repo = try Repo(); defer { repo.remove() }
    let page = repo.page("Before ![a missing <diagram>](img/nope.png) after.\n\nNext paragraph.\n")
    #expect(body(page) == "<p>Before a missing &lt;diagram&gt; after.</p>\n<p>Next paragraph.</p>\n")
    #expect(page.attachments.isEmpty)
}

@Test func oversizedImageRendersAsAltText() throws {
    let repo = try Repo(); defer { repo.remove() }
    let page = repo.page("![too big](img/big.png)\n", maxBytes: 1024)
    #expect(body(page) == "<p>too big</p>\n")
    #expect(page.attachments.isEmpty)
    #expect(repo.page("![fits](img/big.png)\n", maxBytes: 4096).attachments.count == 1)
}

@Test func nonImageFilesAreNeverRead() throws {
    let repo = try Repo(); defer { repo.remove() }
    let page = repo.page("![x](notes.txt) <img src=\"notes.txt\" alt=\"y\">\n")
    #expect(page.attachments.isEmpty)
    #expect(!page.html.contains("secret"))
}

@Test func remoteImagesAreLeftAlone() throws {
    let repo = try Repo(); defer { repo.remove() }
    let page = repo.page("![remote](https://example.com/a.png)\n")
    #expect(body(page) == "<p><img src=\"https://example.com/a.png\" alt=\"remote\" /></p>\n")
}

@Test func pictureSourcesAreAttachedOrDropped() throws {
    let repo = try Repo(); defer { repo.remove() }
    let md = """
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="img/dark%20mode.png 1x, img/flow.png 2x">
      <source media="(min-width: 900px)" srcset="img/missing.png">
      <img src="img/flow.png" alt="Flow">
    </picture>

    """
    let page = repo.page(md)
    #expect(body(page) == "<picture>\n  <source media=\"(prefers-color-scheme: dark)\" srcset=\"cid:image-1.png 1x, cid:image-2.png 2x\" />\n  \n  <img src=\"cid:image-2.png\" alt=\"Flow\" />\n</picture>\n")
}

@Test func renderBodyAloneLeavesImagesUntouched() {
    #expect(MarkdownRenderer.renderBody("![a](img/flow.png)").html == "<p><img src=\"img/flow.png\" alt=\"a\" /></p>\n")
}
