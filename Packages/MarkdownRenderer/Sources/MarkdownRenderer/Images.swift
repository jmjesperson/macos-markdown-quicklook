import Foundation
import UniformTypeIdentifiers

/// Relative images, read from disk and attached to the Quick Look reply as `cid:` data. The sandboxed
/// extension can't let the page load neighbouring files itself (see docs/spike-notes.md).
struct ImageAttacher {
    enum Outcome: Equatable {
        case attached(id: String)
        case missing
        case tooLarge
        /// Remote (`https:`) or a fragment: leave the URL as written.
        case notLocal
    }

    /// Only these are read, so a crafted `src` can't attach arbitrary files.
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tif", "tiff", "ico", "heic", "heif", "avif"]

    let baseDirectory: URL?
    let maxBytes: Int
    let maxTotalBytes: Int
    private(set) var attachments: [MarkdownRenderer.Attachment] = []
    private var totalBytes = 0
    private var cache: [String: Outcome] = [:]

    init(baseDirectory: URL?, maxBytes: Int, maxTotalBytes: Int = .max) {
        self.baseDirectory = baseDirectory
        self.maxBytes = maxBytes
        self.maxTotalBytes = maxTotalBytes
    }

    mutating func resolve(_ src: String) -> Outcome {
        let trimmed = src.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .missing }
        if trimmed.hasPrefix("#") || trimmed.hasPrefix("//") || trimmed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil {
            return .notLocal
        }
        guard let base = baseDirectory, let url = Self.fileURL(for: trimmed, base: base) else { return .missing }
        // Keyed by resolved path, so one file reached by two spellings is attached once.
        if let known = cache[url.path] { return known }
        let outcome = load(url)
        cache[url.path] = outcome
        return outcome
    }

    private mutating func load(_ url: URL) -> Outcome {
        let ext = url.pathExtension.lowercased()
        // A symlink is followed, but its target must also be an image file.
        let target = url.resolvingSymlinksInPath()
        guard Self.imageExtensions.contains(ext), Self.imageExtensions.contains(target.pathExtension.lowercased()) else { return .missing }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: target.path),
              (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = attributes[.size] as? NSNumber else { return .missing }
        guard size.intValue <= maxBytes, totalBytes + size.intValue <= maxTotalBytes else { return .tooLarge }
        guard let data = try? Data(contentsOf: target) else { return .missing }
        totalBytes += data.count
        let id = "image-\(attachments.count + 1).\(ext)"
        let type = UTType(filenameExtension: ext)?.identifier ?? UTType.image.identifier
        attachments.append(MarkdownRenderer.Attachment(id: id, data: data, contentType: type))
        return .attached(id: id)
    }

    /// Resolves `src` against the markdown file's folder. A leading `/` means the repository root, as on
    /// GitHub: the nearest enclosing folder holding `.git`, or the file's folder if there is none.
    static func fileURL(for src: String, base: URL) -> URL? {
        var path = src
        if let cut = path.firstIndex(where: { $0 == "?" || $0 == "#" }) { path = String(path[..<cut]) }
        path = path.removingPercentEncoding ?? path
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("/") {
            return repositoryRoot(from: base).appendingPathComponent(String(path.drop(while: { $0 == "/" }))).standardizedFileURL
        }
        return base.appendingPathComponent(path).standardizedFileURL
    }

    static func repositoryRoot(from directory: URL) -> URL {
        var current = directory.standardizedFileURL
        for _ in 0..<32 {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent(".git").path) { return current }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return directory
    }
}

extension GitHubFilters {
    /// Rewrites local `<img src>` and `<source srcset>` to attachments. An image that can't be attached
    /// is replaced by its alt text; a `<source>` that can't be attached is dropped so the `<img>` shows.
    static func images(_ tokens: [HTMLToken], attacher: inout ImageAttacher) -> [HTMLToken] {
        var out: [HTMLToken] = []
        out.reserveCapacity(tokens.count)
        for token in tokens {
            guard case .start(let name, var attributes, let selfClosing) = token, name == "img" || name == "source" else {
                out.append(token)
                continue
            }
            if name == "img" {
                let src = attributes.first { $0.name == "src" }?.value ?? ""
                switch attacher.resolve(src) {
                case .notLocal:
                    out.append(token)
                case let .attached(id):
                    if let k = attributes.firstIndex(where: { $0.name == "src" }) { attributes[k].value = "cid:" + id }
                    out.append(.start(name: name, attributes: attributes, selfClosing: selfClosing))
                case .missing, .tooLarge:
                    let alt = attributes.first { $0.name == "alt" }?.value ?? ""
                    if !alt.isEmpty { out.append(.text(HTMLTokenizer.escapeText(alt))) }
                }
            } else {
                guard let k = attributes.firstIndex(where: { $0.name == "srcset" }), let srcset = attributes[k].value else {
                    out.append(token)
                    continue
                }
                var rewritten: [String] = []
                var ok = true
                for candidate in srcset.split(separator: ",") {
                    let parts = candidate.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).map(String.init)
                    guard let url = parts.first else { continue }
                    switch attacher.resolve(url) {
                    case .notLocal: rewritten.append(parts.joined(separator: " "))
                    case let .attached(id): rewritten.append((["cid:" + id] + parts.dropFirst()).joined(separator: " "))
                    case .missing, .tooLarge: ok = false
                    }
                }
                guard ok else { continue }
                attributes[k].value = rewritten.joined(separator: ", ")
                out.append(.start(name: name, attributes: attributes, selfClosing: selfClosing))
            }
        }
        return out
    }
}
