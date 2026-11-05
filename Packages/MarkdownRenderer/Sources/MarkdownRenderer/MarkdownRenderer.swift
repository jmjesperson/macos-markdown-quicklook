import Foundation

/// Turns markdown source into HTML the way GitHub renders a markdown file view.
public enum MarkdownRenderer {

    /// The rendered document body, plus what the page needs to load for it.
    public struct Body: Sendable {
        /// HTML for inside `<article class="markdown-body">`.
        public var html: String
        /// Number of fenced `mermaid` blocks.
        public var mermaidCount: Int
        /// Number of fenced blocks naming a language to highlight.
        public var highlightedCount: Int
    }

    /// Renders `markdown` to a sanitized HTML body. Relative images are left unresolved; `renderPage`
    /// attaches them.
    public static func renderBody(_ markdown: String) -> Body {
        let stage = bodyTokens(markdown)
        return Body(html: stage.frontMatterHTML + HTMLTokenizer.serialize(stage.tokens),
                    mermaidCount: stage.mermaidCount, highlightedCount: stage.highlightedCount)
    }

    /// Decodes a markdown file's bytes: UTF-8 (a byte-order mark is dropped), then UTF-16 when the file
    /// starts with a UTF-16 byte-order mark, then ISO Latin-1, which accepts any byte sequence.
    public static func decodeText(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]), let text = String(data: data, encoding: .utf16) {
            return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        }
        return String(data: data, encoding: .isoLatin1) ?? String(decoding: data, as: UTF8.self)
    }

    struct BodyTokens {
        var frontMatterHTML: String
        var tokens: [HTMLToken]
        var mermaidCount: Int
        var highlightedCount: Int
    }

    static func bodyTokens(_ markdown: String) -> BodyTokens {
        var frontMatterHTML = ""
        var source = markdown
        if let (yaml, rest) = FrontMatter.split(markdown), let value = FrontMatter.parse(yaml) {
            frontMatterHTML = FrontMatter.renderHTML(value)
            source = rest
        }

        var tokens = Sanitizer.sanitize(HTMLTokenizer.tokenize(CMark.renderHTML(source)))
        let code = GitHubFilters.codeBlocks(tokens)
        tokens = GitHubFilters.headingAnchors(code.tokens)
        tokens = GitHubFilters.textReferences(tokens, emoji: Emoji.table)
        tokens = GitHubFilters.taskLists(tokens)
        tokens = GitHubFilters.alerts(tokens)
        return BodyTokens(frontMatterHTML: frontMatterHTML, tokens: tokens,
                          mermaidCount: code.mermaidCount, highlightedCount: code.highlightedCount)
    }
}

/// GitHub's emoji shortcodes, from gemoji (see docs/third-party.md).
enum Emoji {
    static let table: [String: String] = {
        guard let url = Bundle.module.url(forResource: "emoji", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return table
    }()
}
