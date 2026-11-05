import cmark_gfm
import cmark_gfm_extensions

/// Markdown to HTML with GitHub's cmark-gfm, configured the way GitHub renders markdown files.
enum CMark {
    /// GFM extensions GitHub enables. `tagfilter` escapes `<script>`, `<iframe>`, `<style>` and similar
    /// so they show as text, which is what GitHub displays for them.
    static let extensionNames = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]

    /// Raw HTML is kept (`UNSAFE`) because the sanitizer, not cmark, decides what survives.
    /// Smart punctuation stays off, as on GitHub.
    static let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_GITHUB_PRE_LANG | CMARK_OPT_VALIDATE_UTF8

    static func renderHTML(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }
        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }
        var utf8 = Array(markdown.utf8)
        if !utf8.isEmpty { utf8.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                cmark_parser_feed(parser, $0, buffer.count)
            }
        } }
        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }
        guard let html = cmark_render_html(document, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(html) }
        return String(cString: html)
    }
}
