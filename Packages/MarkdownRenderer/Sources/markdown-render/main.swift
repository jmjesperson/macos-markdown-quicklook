import Foundation
import MarkdownRenderer

// Developer tool, not shipped in the app: renders a markdown file to a full HTML page.
// Usage: swift run markdown-render <file.md> [out.html]   (prints the render time to stderr)
let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: markdown-render <file.md> [out.html]\n".utf8))
    exit(2)
}
let url = URL(fileURLWithPath: args[1])
let markdown = try String(contentsOf: url, encoding: .utf8)
let start = Date()
let page = MarkdownRenderer.renderPage(markdown, options: .init(baseDirectory: url.deletingLastPathComponent()))
let ms = Date().timeIntervalSince(start) * 1000
if args.count >= 3 {
    try page.html.write(to: URL(fileURLWithPath: args[2]), atomically: true, encoding: .utf8)
} else {
    print(page.html)
}
FileHandle.standardError.write(Data(String(format: "rendered %@ in %.1f ms (%d attachments)\n", url.lastPathComponent, ms, page.attachments.count).utf8))
