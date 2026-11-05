import Foundation

extension MarkdownRenderer {

    /// A file attached to the Quick Look reply and referenced from the page as `cid:<id>`.
    public struct Attachment: Sendable, Equatable {
        public var id: String
        public var data: Data
        /// Uniform Type Identifier, for example `public.png`.
        public var contentType: String
    }

    /// A complete HTML page and the attachments it references.
    public struct Page: Sendable {
        public var html: String
        public var attachments: [Attachment]
        public var nonce: String
    }

    public struct PageOptions: Sendable {
        /// The folder holding the markdown file; relative images resolve against it. `nil` leaves them missing.
        public var baseDirectory: URL?
        /// Images larger than this render as their alt text.
        public var maxImageBytes: Int
        /// Once the attached images reach this total, further images render as their alt text, which
        /// keeps the extension inside Quick Look's memory budget.
        public var maxTotalImageBytes: Int
        /// The nonce for the page's own scripts and styles. Fixed only in tests.
        public var nonce: String

        public init(baseDirectory: URL? = nil, maxImageBytes: Int = 10 * 1024 * 1024, maxTotalImageBytes: Int = 50 * 1024 * 1024,
                    nonce: String = PageOptions.randomNonce()) {
            self.baseDirectory = baseDirectory
            self.maxImageBytes = maxImageBytes
            self.maxTotalImageBytes = maxTotalImageBytes
            self.nonce = nonce
        }

        public static func randomNonce() -> String {
            var bytes = [UInt8](repeating: 0, count: 18)
            for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
            return Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        }
    }

    /// The Content Security Policy every page carries. Only the page's own nonce-bearing scripts and
    /// styles run or apply; images may come from attachments, data URLs (the CSS's icons) or HTTPS.
    public static func contentSecurityPolicy(nonce: String) -> String {
        "default-src 'none'; script-src 'nonce-\(nonce)'; style-src 'nonce-\(nonce)'; img-src cid: data: https:; base-uri 'none'; form-action 'none'"
    }

    /// Renders `markdown` into a full page: GitHub's CSS always, highlight.js only when a fenced block
    /// names a language, Mermaid only when there is a `mermaid` block.
    public static func renderPage(_ markdown: String, options: PageOptions = PageOptions()) -> Page {
        let stage = bodyTokens(markdown)
        var attacher = ImageAttacher(baseDirectory: options.baseDirectory, maxBytes: options.maxImageBytes, maxTotalBytes: options.maxTotalImageBytes)
        let tokens = GitHubFilters.images(stage.tokens, attacher: &attacher)
        let body = Body(html: stage.frontMatterHTML + HTMLTokenizer.serialize(tokens),
                        mermaidCount: stage.mermaidCount, highlightedCount: stage.highlightedCount)
        let nonce = options.nonce
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy(nonce: nonce))">
        <meta name="color-scheme" content="light dark">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style nonce="\(nonce)">\(Assets.text("github-markdown.css"))
        \(Assets.text("page.css"))</style>

        """
        if body.highlightedCount > 0 {
            html += "<style nonce=\"\(nonce)\">@media (prefers-color-scheme: light) {\(Assets.text("highlight-github.min.css"))}\n"
                + "@media (prefers-color-scheme: dark) {\(Assets.text("highlight-github-dark.min.css"))}</style>\n"
        }
        html += "</head>\n<body>\n<article class=\"markdown-body\">\n" + body.html + "</article>\n"
        if body.highlightedCount > 0 {
            html += script(Assets.text("highlight.min.js"), nonce) + script(Assets.text("highlight-init.js"), nonce)
        }
        if body.mermaidCount > 0 {
            html += script(Assets.text("mermaid.min.js"), nonce) + script(Assets.text("mermaid-init.js"), nonce)
        }
        html += "</body>\n</html>\n"
        return Page(html: html, attachments: attacher.attachments, nonce: nonce)
    }

    private static func script(_ source: String, _ nonce: String) -> String {
        // A bundled script never contains "</script", but guard so it can't end its own element early.
        "<script nonce=\"\(nonce)\">" + source.replacingOccurrences(of: "</script", with: "<\\/script") + "</script>\n"
    }
}

/// Bundled CSS and JavaScript (see docs/third-party.md).
enum Assets {
    private static let cache = Cache()

    static func text(_ name: String) -> String { cache.text(name) }

    private final class Cache: @unchecked Sendable {
        private var texts: [String: String] = [:]
        private let lock = NSLock()

        func text(_ name: String) -> String {
            lock.lock(); defer { lock.unlock() }
            if let cached = texts[name] { return cached }
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            guard let url = Bundle.module.url(forResource: base, withExtension: ext, subdirectory: "Resources"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else {
                preconditionFailure("missing bundled asset \(name)")
            }
            texts[name] = text
            return text
        }
    }
}
