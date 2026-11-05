import Foundation

/// One attribute of a start tag. `value` is entity-decoded; `nil` means the attribute had no value.
struct HTMLAttribute: Equatable {
    var name: String
    var value: String?
}

/// A token of an HTML fragment. Text is kept raw (still entity-encoded) so it serialises unchanged.
enum HTMLToken: Equatable {
    case text(String)
    case start(name: String, attributes: [HTMLAttribute], selfClosing: Bool)
    case end(name: String)
    case comment(String)
    /// Doctype, processing instruction or CDATA section.
    case other(String)
}

extension HTMLToken {
    func attribute(_ name: String) -> String? {
        guard case let .start(_, attributes, _) = self else { return nil }
        return attributes.first { $0.name == name }?.value
    }

    func hasAttribute(_ name: String) -> Bool {
        guard case let .start(_, attributes, _) = self else { return false }
        return attributes.contains { $0.name == name }
    }

    var startName: String? {
        if case let .start(name, _, _) = self { return name }
        return nil
    }

    var endName: String? {
        if case let .end(name) = self { return name }
        return nil
    }
}

/// A small, forgiving HTML tokenizer. It is not a full HTML5 parser: it splits markup into tags,
/// text and comments, which is all the sanitizer and the GitHub filters need.
enum HTMLTokenizer {
    /// Elements whose content is raw text up to the matching end tag.
    static let rawTextElements: Set<String> = [
        "script", "style", "textarea", "title", "xmp", "iframe", "noembed", "noframes", "noscript", "plaintext",
    ]

    static func tokenize(_ html: String) -> [HTMLToken] {
        let bytes = Array(html.utf8)
        var tokens: [HTMLToken] = []
        var index = 0
        var textStart = 0

        func flushText(upTo end: Int) {
            if end > textStart {
                tokens.append(.text(String(decoding: bytes[textStart..<end], as: UTF8.self)))
            }
        }

        while index < bytes.count {
            guard bytes[index] == UInt8(ascii: "<") else { index += 1; continue }
            let tagStart = index
            if let (token, next) = readMarkup(bytes, at: index) {
                flushText(upTo: tagStart)
                tokens.append(token)
                index = next
                textStart = index
                if case let .start(name, _, selfClosing) = token, !selfClosing, rawTextElements.contains(name) {
                    let contentEnd = findRawTextEnd(bytes, from: index, name: name)
                    if contentEnd > index {
                        tokens.append(.text(String(decoding: bytes[index..<contentEnd], as: UTF8.self)))
                    }
                    index = contentEnd
                    textStart = index
                }
            } else {
                index += 1
            }
        }
        flushText(upTo: bytes.count)
        return tokens
    }

    static func serialize(_ tokens: [HTMLToken]) -> String {
        var out = ""
        out.reserveCapacity(tokens.count * 16)
        for token in tokens {
            switch token {
            case let .text(text):
                out += text
            case let .start(name, attributes, selfClosing):
                out += "<" + name
                for attribute in attributes {
                    out += " " + attribute.name
                    if let value = attribute.value { out += "=\"" + escapeAttribute(value) + "\"" }
                }
                out += selfClosing ? " />" : ">"
            case let .end(name):
                out += "</" + name + ">"
            case let .comment(text):
                out += "<!--" + text + "-->"
            case let .other(text):
                out += text
            }
        }
        return out
    }

    // MARK: - Reading markup

    private static func isAlpha(_ b: UInt8) -> Bool { (b | 0x20) >= 0x61 && (b | 0x20) <= 0x7A }
    private static func isSpace(_ b: UInt8) -> Bool { b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D || b == 0x0C }

    private static func readMarkup(_ b: [UInt8], at start: Int) -> (HTMLToken, Int)? {
        let n = b.count
        guard start + 1 < n else { return nil }
        let c = b[start + 1]
        if c == UInt8(ascii: "!") {
            if start + 3 < n, b[start + 2] == UInt8(ascii: "-"), b[start + 3] == UInt8(ascii: "-") {
                var i = start + 4
                while i + 2 < n, !(b[i] == UInt8(ascii: "-") && b[i + 1] == UInt8(ascii: "-") && b[i + 2] == UInt8(ascii: ">")) { i += 1 }
                if i + 2 >= n { return (.comment(String(decoding: b[(start + 4)...], as: UTF8.self)), n) }
                return (.comment(String(decoding: b[(start + 4)..<i], as: UTF8.self)), i + 3)
            }
            return readUntilGreaterThan(b, start)
        }
        if c == UInt8(ascii: "?") { return readUntilGreaterThan(b, start) }
        if c == UInt8(ascii: "/") {
            guard start + 2 < n, isAlpha(b[start + 2]) else { return nil }
            var i = start + 2
            while i < n, !isSpace(b[i]), b[i] != UInt8(ascii: ">"), b[i] != UInt8(ascii: "/") { i += 1 }
            let name = String(decoding: b[(start + 2)..<i], as: UTF8.self).lowercased()
            while i < n, b[i] != UInt8(ascii: ">") { i += 1 }
            guard i < n else { return nil }
            return (.end(name: name), i + 1)
        }
        guard isAlpha(c) else { return nil }

        var i = start + 1
        while i < n, !isSpace(b[i]), b[i] != UInt8(ascii: ">"), b[i] != UInt8(ascii: "/") { i += 1 }
        let name = String(decoding: b[(start + 1)..<i], as: UTF8.self).lowercased()
        var attributes: [HTMLAttribute] = []
        var selfClosing = false
        while i < n {
            while i < n, isSpace(b[i]) { i += 1 }
            guard i < n else { return nil }
            if b[i] == UInt8(ascii: ">") { return (.start(name: name, attributes: attributes, selfClosing: selfClosing), i + 1) }
            if b[i] == UInt8(ascii: "/") { selfClosing = true; i += 1; continue }
            selfClosing = false
            let nameStart = i
            while i < n, !isSpace(b[i]), b[i] != UInt8(ascii: ">"), b[i] != UInt8(ascii: "="), !(b[i] == UInt8(ascii: "/") && i > nameStart) { i += 1 }
            if i == nameStart { i += 1; continue }
            let attrName = String(decoding: b[nameStart..<i], as: UTF8.self).lowercased()
            while i < n, isSpace(b[i]) { i += 1 }
            var value: String?
            if i < n, b[i] == UInt8(ascii: "=") {
                i += 1
                while i < n, isSpace(b[i]) { i += 1 }
                guard i < n else { return nil }
                if b[i] == UInt8(ascii: "\"") || b[i] == UInt8(ascii: "'") {
                    let quote = b[i]
                    let valueStart = i + 1
                    i = valueStart
                    while i < n, b[i] != quote { i += 1 }
                    guard i < n else { return nil }
                    value = decodeEntities(String(decoding: b[valueStart..<i], as: UTF8.self))
                    i += 1
                } else {
                    let valueStart = i
                    while i < n, !isSpace(b[i]), b[i] != UInt8(ascii: ">") { i += 1 }
                    value = decodeEntities(String(decoding: b[valueStart..<i], as: UTF8.self))
                }
            }
            if !attributes.contains(where: { $0.name == attrName }) {
                attributes.append(HTMLAttribute(name: attrName, value: value))
            }
        }
        return nil
    }

    private static func readUntilGreaterThan(_ b: [UInt8], _ start: Int) -> (HTMLToken, Int)? {
        var i = start + 2
        while i < b.count, b[i] != UInt8(ascii: ">") { i += 1 }
        guard i < b.count else { return nil }
        return (.other(String(decoding: b[start...i], as: UTF8.self)), i + 1)
    }

    private static func findRawTextEnd(_ b: [UInt8], from start: Int, name: String) -> Int {
        let needle = Array(("</" + name).utf8)
        var i = start
        while i + needle.count <= b.count {
            if b[i] == UInt8(ascii: "<") {
                var match = true
                for k in 0..<needle.count where (b[i + k] | (k >= 2 ? 0x20 : 0)) != needle[k] {
                    match = false
                    break
                }
                if match { return i }
            }
            i += 1
        }
        return b.count
    }

    // MARK: - Entities

    static func escapeText(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for ch in s.unicodeScalars {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.unicodeScalars.append(ch)
            }
        }
        return out
    }

    static func escapeAttribute(_ s: String) -> String {
        escapeText(s).replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "colon": ":", "tab": "\t", "newline": "\n", "sol": "/", "lpar": "(", "rpar": ")",
        "copy": "©", "reg": "®", "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–",
        "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "middot": "·", "times": "×",
    ]

    /// Decodes numeric entities and the common named ones. Unknown names are left as written.
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            guard ch == "&", let semi = s[i...].prefix(40).firstIndex(of: ";") else {
                out.append(ch)
                i = s.index(after: i)
                continue
            }
            let body = s[s.index(after: i)..<semi]
            var decoded: String?
            if body.hasPrefix("#x") || body.hasPrefix("#X") {
                if let v = UInt32(body.dropFirst(2), radix: 16) { decoded = scalarString(v) }
            } else if body.hasPrefix("#") {
                if let v = UInt32(body.dropFirst(), radix: 10) { decoded = scalarString(v) }
            } else {
                decoded = namedEntities[String(body)]
            }
            if let decoded {
                out += decoded
                i = s.index(after: semi)
            } else {
                out.append(ch)
                i = s.index(after: i)
            }
        }
        return out
    }

    private static func scalarString(_ v: UInt32) -> String {
        if v == 0 { return "\u{FFFD}" }
        return Unicode.Scalar(v).map { String(Character($0)) } ?? "\u{FFFD}"
    }
}
