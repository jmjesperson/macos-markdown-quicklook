import Cocoa
import Quartz
import UniformTypeIdentifiers
import MarkdownRenderer

/// Data-based Quick Look preview: reads the markdown file, renders it with `MarkdownRenderer`, and
/// returns the page as HTML with any relative images attached as `cid:` data.
class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let markdown = try Self.readText(url)
        let page = MarkdownRenderer.renderPage(markdown, options: .init(baseDirectory: url.deletingLastPathComponent()))

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 980, height: 800)) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            var attachments: [String: QLPreviewReplyAttachment] = [:]
            for attachment in page.attachments {
                let type = UTType(attachment.contentType) ?? .data
                attachments[attachment.id] = QLPreviewReplyAttachment(data: attachment.data, contentType: type)
            }
            replyToUpdate.attachments = attachments
            return Data(page.html.utf8)
        }
        reply.title = url.lastPathComponent
        return reply
    }

    /// Reads the file once and decodes it with `MarkdownRenderer.decodeText` (UTF-8, UTF-16 with a
    /// byte-order mark, then ISO Latin-1).
    static func readText(_ url: URL) throws -> String {
        MarkdownRenderer.decodeText(try Data(contentsOf: url))
    }
}
