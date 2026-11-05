import Foundation

/// YAML front matter at the very top of a file, rendered as GitHub renders it in a file view
/// (checked against https://github.com/github/docs/blob/main/content/index.md on 2026-11-05):
/// the top level is a table with one `<th>key</th><td>value</td>` row per key; a nested mapping is a
/// table whose header row holds its keys; a sequence is a one-row table of its items.
///
/// The YAML reader covers what front matter uses in practice: nested block mappings, block
/// sequences, plain and quoted scalars, and `|` / `>` block scalars. Flow collections stay as text.
enum FrontMatter {
    indirect enum Value: Equatable {
        case scalar(String)
        case sequence([Value])
        case mapping([(String, Value)])

        static func == (a: Value, b: Value) -> Bool {
            switch (a, b) {
            case let (.scalar(x), .scalar(y)): return x == y
            case let (.sequence(x), .sequence(y)): return x == y
            case let (.mapping(x), .mapping(y)): return x.map(\.0) == y.map(\.0) && x.map(\.1) == y.map(\.1)
            default: return false
            }
        }
    }

    /// Splits `markdown` into its front matter block (without the `---` lines) and the body.
    static func split(_ markdown: String) -> (yaml: String, body: String)? {
        var lines = markdown.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" || first == "---\r" else { return nil }
        lines.removeFirst()
        guard let close = lines.firstIndex(where: {
            let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return t == "---" || t == "..."
        }) else { return nil }
        let yaml = lines[..<close].joined(separator: "\n")
        let body = lines[(close + 1)...].joined(separator: "\n")
        return (yaml, body)
    }

    // MARK: Parsing

    private struct Line {
        let indent: Int
        let text: String
    }

    static func parse(_ yaml: String) -> Value? {
        let lines = yaml.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n").compactMap { raw -> Line? in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return Line(indent: -1, text: raw) }
            let indent = raw.prefix(while: { $0 == " " }).count
            return Line(indent: indent, text: String(raw.dropFirst(indent)))
        }
        var index = 0
        skipBlank(lines, &index)
        guard index < lines.count else { return nil }
        let value = parseBlock(lines, &index, indent: lines[index].indent)
        // Lines the reader couldn't place mean the YAML is invalid (or beyond this reader): render the
        // file as plain markdown rather than silently dropping them.
        skipBlank(lines, &index)
        return index < lines.count ? nil : value
    }

    private static func skipBlank(_ lines: [Line], _ i: inout Int) {
        while i < lines.count, lines[i].indent < 0 { i += 1 }
    }

    private static func parseBlock(_ lines: [Line], _ i: inout Int, indent: Int) -> Value {
        skipBlank(lines, &i)
        guard i < lines.count else { return .scalar("") }
        if lines[i].text.hasPrefix("- ") || lines[i].text == "-" {
            var items: [Value] = []
            while i < lines.count {
                skipBlank(lines, &i)
                guard i < lines.count, lines[i].indent == indent, lines[i].text.hasPrefix("-") else { break }
                let rest = String(lines[i].text.dropFirst()).trimmingCharacters(in: .whitespaces)
                i += 1
                if rest.isEmpty {
                    skipBlank(lines, &i)
                    if i < lines.count, lines[i].indent > indent {
                        items.append(parseBlock(lines, &i, indent: lines[i].indent))
                    } else {
                        items.append(.scalar(""))
                    }
                } else if let (key, value) = keyValue(rest) {
                    // "- key: value" starts a mapping inside the sequence.
                    var pairs: [(String, Value)] = [(key, value.isEmpty ? nestedOrEmpty(lines, &i, parent: indent) : .scalar(unquote(value)))]
                    let childIndent = indent + 2
                    skipBlank(lines, &i)
                    if i < lines.count, lines[i].indent == childIndent, case let .mapping(more) = parseBlock(lines, &i, indent: childIndent) {
                        pairs += more
                    }
                    items.append(.mapping(pairs))
                } else {
                    items.append(.scalar(unquote(rest)))
                }
            }
            return .sequence(items)
        }
        var pairs: [(String, Value)] = []
        while i < lines.count {
            skipBlank(lines, &i)
            guard i < lines.count, lines[i].indent == indent, let (key, value) = keyValue(lines[i].text) else { break }
            i += 1
            if value == "|" || value == ">" || value.hasPrefix("|") || value.hasPrefix(">") {
                pairs.append((key, .scalar(blockScalar(lines, &i, parent: indent, folded: value.hasPrefix(">")))))
            } else if value.isEmpty {
                pairs.append((key, nestedOrEmpty(lines, &i, parent: indent)))
            } else {
                pairs.append((key, .scalar(unquote(value))))
            }
        }
        if pairs.isEmpty, i < lines.count {
            // A plain scalar, possibly over several lines. It ends at the first line indented less than
            // it, which belongs to the parent mapping.
            var parts: [String] = []
            while i < lines.count, lines[i].indent < 0 || lines[i].indent >= indent {
                if lines[i].indent >= 0 { parts.append(lines[i].text) }
                i += 1
            }
            return .scalar(unquote(parts.joined(separator: " ")))
        }
        return .mapping(pairs)
    }

    private static func nestedOrEmpty(_ lines: [Line], _ i: inout Int, parent: Int) -> Value {
        skipBlank(lines, &i)
        guard i < lines.count else { return .scalar("") }
        let next = lines[i]
        // YAML allows a sequence at the same indent as its parent key.
        if next.indent > parent || (next.indent == parent && next.text.hasPrefix("-")) {
            return parseBlock(lines, &i, indent: next.indent)
        }
        return .scalar("")
    }

    private static func blockScalar(_ lines: [Line], _ i: inout Int, parent: Int, folded: Bool) -> String {
        var parts: [String] = []
        while i < lines.count, lines[i].indent < 0 || lines[i].indent > parent {
            parts.append(lines[i].indent < 0 ? "" : lines[i].text)
            i += 1
        }
        while parts.last == "" { parts.removeLast() }
        return parts.joined(separator: folded ? " " : "\n")
    }

    /// `key: value` with the key possibly quoted. Returns nil if the line is not a mapping entry.
    private static func keyValue(_ text: String) -> (String, String)? {
        var key: String
        var rest: Substring
        if let q = text.first, q == "\"" || q == "'" {
            guard let end = text.dropFirst().firstIndex(of: q) else { return nil }
            key = String(text[text.index(after: text.startIndex)..<end])
            rest = text[text.index(after: end)...]
            guard rest.hasPrefix(":") else { return nil }
            rest = rest.dropFirst()
        } else {
            guard let colon = text.range(of: ": ")?.lowerBound ?? (text.hasSuffix(":") ? text.index(before: text.endIndex) : nil) else { return nil }
            key = String(text[..<colon])
            rest = text[text.index(after: colon)...]
            if key.contains(" #") { return nil }
        }
        key = key.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return (key, stripComment(String(rest)).trimmingCharacters(in: .whitespaces))
    }

    private static func stripComment(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let q = t.first, q == "\"" || q == "'" {
            // A quoted scalar ends at its closing quote; anything after it is a comment or junk.
            if let close = t.dropFirst().firstIndex(of: q) { return String(t[...close]) }
            return t
        }
        if let r = s.range(of: " #") { return String(s[..<r.lowerBound]) }
        return s
    }

    private static func unquote(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.count >= 2, let f = t.first, let l = t.last, (f == "\"" && l == "\"") || (f == "'" && l == "'") {
            let inner = String(t.dropFirst().dropLast())
            return f == "'" ? inner.replacingOccurrences(of: "''", with: "'") : inner.replacingOccurrences(of: "\\\"", with: "\"")
        }
        return t
    }

    // MARK: Rendering

    static func renderHTML(_ value: Value) -> String {
        switch value {
        case let .mapping(pairs):
            var out = "<table>\n<tbody>\n"
            for (key, v) in pairs {
                out += "<tr>\n<th>\(HTMLTokenizer.escapeText(key))</th>\n<td>\(renderNested(v, wrap: false))</td>\n</tr>\n"
            }
            return out + "</tbody>\n</table>\n"
        default:
            return renderNested(value, wrap: false) + "\n"
        }
    }

    private static func renderNested(_ value: Value, wrap: Bool) -> String {
        let html: String
        switch value {
        case let .scalar(text):
            html = HTMLTokenizer.escapeText(text)
        case let .sequence(items):
            html = "<table>\n<tbody>\n<tr>\n" + items.map { "<td>\(renderNested($0, wrap: true))</td>\n" }.joined() + "</tr>\n</tbody>\n</table>\n"
        case let .mapping(pairs):
            html = "<table>\n<thead>\n<tr>\n" + pairs.map { "<th>\(HTMLTokenizer.escapeText($0.0))</th>\n" }.joined()
                + "</tr>\n</thead>\n<tbody>\n<tr>\n" + pairs.map { "<td>\(renderNested($0.1, wrap: true))</td>\n" }.joined()
                + "</tr>\n</tbody>\n</table>\n"
        }
        return wrap ? "<div>\(html)</div>" : html
    }
}
