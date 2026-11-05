import Foundation
import Testing
@testable import MarkdownRenderer

/// The page around the body, with each bundled asset's text replaced by `{{name}}`.
enum Snapshot {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Snapshots")
    static let assets = ["github-markdown.css", "page.css", "highlight-github.min.css", "highlight-github-dark.min.css",
                         "highlight.min.js", "highlight-init.js", "mermaid.min.js", "mermaid-init.js"]

    static func skeleton(_ markdown: String) -> String {
        var html = MarkdownRenderer.renderPage(markdown, options: .init(nonce: "NONCE")).html
        for name in assets { html = html.replacingOccurrences(of: Assets.text(name), with: "{{\(name)}}") }
        return html
    }

    static func check(_ name: String, _ actual: String) throws {
        let url = root.appendingPathComponent(name)
        if ProcessInfo.processInfo.environment["UPDATE_FIXTURES"] == "1" {
            try actual.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        #expect(actual == (try String(contentsOf: url, encoding: .utf8)), "\(name)")
    }
}

@Test func plainPageSkeleton() throws {
    try Snapshot.check("page-plain.html", Snapshot.skeleton("# Title\n\nText.\n"))
}

@Test func fullPageSkeleton() throws {
    try Snapshot.check("page-full.html", Snapshot.skeleton("# Title\n\n```swift\nlet x = 1\n```\n\n```mermaid\nflowchart LR\n  A --> B\n```\n"))
}

@Test func githubCSSIsTheEnforcedVersion() {
    // github-markdown-css 5.9.0, pinned in docs/third-party.md.
    let css = Assets.text("github-markdown.css")
    #expect(css.utf8.count == 31068)
    #expect(css.contains("@media (prefers-color-scheme: dark)") && css.contains("@media (prefers-color-scheme: light)"))
}
