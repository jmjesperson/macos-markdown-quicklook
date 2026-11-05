import Foundation

/// Passes over sanitized tokens that add what GitHub adds on top of cmark-gfm. Each pass mirrors the
/// markup GitHub's `/markdown` API returned on 2026-11-05 (recorded in `docs/markdown-support.md`).
/// These passes run after the sanitizer, so the classes and SVG they add are trusted.
enum GitHubFilters {

    // MARK: Heading anchors

    /// GitHub's slug: lower-cased; letters, numbers, marks, `-` and `_` kept; spaces become `-`;
    /// everything else (punctuation, symbols, emoji) dropped.
    static func slug(_ text: String) -> String {
        var out = ""
        for scalar in text.lowercased().unicodeScalars {
            let p = scalar.properties
            if scalar == "-" || scalar == "_" {
                out.unicodeScalars.append(scalar)
            } else if scalar == " " || scalar == "\t" || scalar == "\n" {
                out += "-"
            } else if p.isAlphabetic || p.numericType != nil || p.generalCategory == .nonspacingMark
                        || p.generalCategory == .spacingMark || p.generalCategory == .enclosingMark {
                if !p.isEmojiPresentation { out.unicodeScalars.append(scalar) }
            }
        }
        return out
    }

    static func headingAnchors(_ tokens: [HTMLToken]) -> [HTMLToken] {
        let headings: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
        var used: [String: Int] = [:]
        var out: [HTMLToken] = []
        out.reserveCapacity(tokens.count + 8)
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            out.append(token)
            guard let name = token.startName, headings.contains(name) else { i += 1; continue }
            var text = ""
            var j = i + 1
            while j < tokens.count, tokens[j].endName != name {
                if case let .text(t) = tokens[j] { text += HTMLTokenizer.decodeEntities(t) }
                j += 1
            }
            let base = slug(text.trimmingCharacters(in: .whitespacesAndNewlines))
            // Duplicates get -1, -2, ... skipping any suffix already taken.
            var id = base
            if let next = used[base] {
                var k = next
                repeat { id = "\(base)-\(k)"; k += 1 } while used[id] != nil
                used[base] = k
                used[id] = 1
            } else {
                used[base] = 1
            }
            // `user-content-` as on GitHub; in-page links to `#slug` were given the same prefix by the sanitizer.
            let anchorID = Sanitizer.userContentPrefix + id
            out.append(.start(name: "a", attributes: [
                HTMLAttribute(name: "id", value: anchorID), HTMLAttribute(name: "class", value: "anchor"),
                HTMLAttribute(name: "aria-hidden", value: "true"), HTMLAttribute(name: "href", value: "#" + anchorID),
            ], selfClosing: false))
            out.append(.start(name: "span", attributes: [HTMLAttribute(name: "class", value: "octicon octicon-link")], selfClosing: false))
            out.append(.end(name: "span"))
            out.append(.end(name: "a"))
            i += 1
        }
        return out
    }

    // MARK: Alerts

    struct AlertType {
        let title: String
        let octicon: String
        let path: String
    }

    /// Titles, icons and SVG paths as GitHub returned them on 2026-11-05.
    static let alertTypes: [String: AlertType] = [
        "note": AlertType(title: "Note", octicon: "info", path: "M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8Zm8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13ZM6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25a.75.75 0 0 1-.75-.75ZM8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"),
        "tip": AlertType(title: "Tip", octicon: "light-bulb", path: "M8 1.5c-2.363 0-4 1.69-4 3.75 0 .984.424 1.625.984 2.304l.214.253c.223.264.47.556.673.848.284.411.537.896.621 1.49a.75.75 0 0 1-1.484.211c-.04-.282-.163-.547-.37-.847a8.456 8.456 0 0 0-.542-.68c-.084-.1-.173-.205-.268-.32C3.201 7.75 2.5 6.766 2.5 5.25 2.5 2.31 4.863 0 8 0s5.5 2.31 5.5 5.25c0 1.516-.701 2.5-1.328 3.259-.095.115-.184.22-.268.319-.207.245-.383.453-.541.681-.208.3-.33.565-.37.847a.751.751 0 0 1-1.485-.212c.084-.593.337-1.078.621-1.489.203-.292.45-.584.673-.848.075-.088.147-.173.213-.253.561-.679.985-1.32.985-2.304 0-2.06-1.637-3.75-4-3.75ZM5.75 12h4.5a.75.75 0 0 1 0 1.5h-4.5a.75.75 0 0 1 0-1.5ZM6 15.25a.75.75 0 0 1 .75-.75h2.5a.75.75 0 0 1 0 1.5h-2.5a.75.75 0 0 1-.75-.75Z"),
        "important": AlertType(title: "Important", octicon: "report", path: "M0 1.75C0 .784.784 0 1.75 0h12.5C15.216 0 16 .784 16 1.75v9.5A1.75 1.75 0 0 1 14.25 13H8.06l-2.573 2.573A1.458 1.458 0 0 1 3 14.543V13H1.75A1.75 1.75 0 0 1 0 11.25Zm1.75-.25a.25.25 0 0 0-.25.25v9.5c0 .138.112.25.25.25h2a.75.75 0 0 1 .75.75v2.19l2.72-2.72a.749.749 0 0 1 .53-.22h6.5a.25.25 0 0 0 .25-.25v-9.5a.25.25 0 0 0-.25-.25Zm7 2.25v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"),
        "warning": AlertType(title: "Warning", octicon: "alert", path: "M6.457 1.047c.659-1.234 2.427-1.234 3.086 0l6.082 11.378A1.75 1.75 0 0 1 14.082 15H1.918a1.75 1.75 0 0 1-1.543-2.575Zm1.763.707a.25.25 0 0 0-.44 0L1.698 13.132a.25.25 0 0 0 .22.368h12.164a.25.25 0 0 0 .22-.368Zm.53 3.996v2.5a.75.75 0 0 1-1.5 0v-2.5a.75.75 0 0 1 1.5 0ZM9 11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"),
        "caution": AlertType(title: "Caution", octicon: "stop", path: "M4.47.22A.749.749 0 0 1 5 0h6c.199 0 .389.079.53.22l4.25 4.25c.141.14.22.331.22.53v6a.749.749 0 0 1-.22.53l-4.25 4.25A.749.749 0 0 1 11 16H5a.749.749 0 0 1-.53-.22L.22 11.53A.749.749 0 0 1 0 11V5c0-.199.079-.389.22-.53Zm.84 1.28L1.5 5.31v5.38l3.81 3.81h5.38l3.81-3.81V5.31L10.69 1.5ZM8 4a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5A.75.75 0 0 1 8 4Zm0 8a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"),
    ]

    /// Block quotes at the top level of the document (not inside a list, table, `<details>` or another
    /// quote) whose first line is exactly `[!TYPE]` (any case) become alerts, as on GitHub.
    static func alerts(_ tokens: [HTMLToken]) -> [HTMLToken] {
        // Open-element depth before each token, so an alert is only recognised at depth 0.
        var openDepth: [Int] = []
        openDepth.reserveCapacity(tokens.count)
        var open = 0
        for token in tokens {
            openDepth.append(open)
            switch token {
            case let .start(name, _, selfClosing) where !selfClosing && !Sanitizer.voidElements.contains(name): open += 1
            case let .end(name) where !Sanitizer.voidElements.contains(name): open = max(0, open - 1)
            default: break
            }
        }
        var out: [HTMLToken] = []
        out.reserveCapacity(tokens.count + 8)
        var depth = 0
        var alertDepths: [Int] = []
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            if token.startName == "blockquote" {
                depth += 1
                if depth == 1, openDepth[i] == 0, let (type, consumed, remainder) = alertMarker(tokens, after: i) {
                    let info = alertTypes[type]!
                    out.append(.text("<div class=\"markdown-alert markdown-alert-\(type)\"><p class=\"markdown-alert-title\"><svg class=\"octicon octicon-\(info.octicon) mr-2\" viewBox=\"0 0 16 16\" version=\"1.1\" width=\"16\" height=\"16\" aria-hidden=\"true\"><path d=\"\(info.path)\"></path></svg>\(info.title)</p>"))
                    out.append(contentsOf: remainder)
                    alertDepths.append(depth)
                    i = consumed
                    continue
                }
            } else if token.endName == "blockquote" {
                if alertDepths.last == depth {
                    alertDepths.removeLast()
                    out.append(.end(name: "div"))
                    depth -= 1
                    i += 1
                    continue
                }
                depth -= 1
            }
            out.append(token)
            i += 1
        }
        return out
    }

    /// If the block quote starting at `index` opens with an alert marker, returns its type, the index
    /// to continue from, and the tokens that replace the marker paragraph's opening.
    private static func alertMarker(_ tokens: [HTMLToken], after index: Int) -> (String, Int, [HTMLToken])? {
        var j = index + 1
        while j < tokens.count, case let .text(t) = tokens[j], t.allSatisfy(\.isWhitespace) { j += 1 }
        guard j + 1 < tokens.count, tokens[j].startName == "p", case let .text(first) = tokens[j + 1] else { return nil }
        guard first.hasPrefix("[!"), let close = first.firstIndex(of: "]") else { return nil }
        let type = first[first.index(first.startIndex, offsetBy: 2)..<close].lowercased()
        guard alertTypes[type] != nil else { return nil }
        let rest = first[first.index(after: close)...]
        if rest.isEmpty {
            // Marker alone in its paragraph: drop the paragraph, keep what follows.
            guard j + 2 < tokens.count, tokens[j + 2].endName == "p" else { return nil }
            return (type, j + 3, [])
        }
        guard rest.first == "\n" else { return nil }
        return (type, j + 2, [tokens[j], .text(String(rest.dropFirst()))])
    }

    // MARK: Emoji, mentions, issue references and commit SHAs

    /// Emoji shortcodes stay literal inside these (GitHub converts them inside links and `<kbd>`).
    static let emojiLiteralElements: Set<String> = ["code", "pre", "tt"]
    /// Mentions, issue references and SHAs stay literal inside these.
    static let referenceLiteralElements: Set<String> = ["code", "pre", "tt", "a"]

    static let emojiPattern = try! NSRegularExpression(pattern: ":([a-z0-9_+\\-]+):")
    static let referencePattern = try! NSRegularExpression(pattern: [
        // @user or @org/team, not inside an email address or path.
        "(?<![\\w@./`])@(?<mention>[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}(?:/[A-Za-z0-9][A-Za-z0-9_.\\-]*[A-Za-z0-9_])?)(?![\\w@])",
        // #123
        "(?<![\\w&#/])#(?<issue>[0-9]+)(?![\\w])",
        // a 7 to 40 character hex word with at least one digit and one letter
        "(?<![\\w@/#.\\-])(?<sha>(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])[0-9a-f]{7,40})(?![\\w\\-])",
    ].joined(separator: "|"))

    static func textReferences(_ tokens: [HTMLToken], emoji: [String: String]) -> [HTMLToken] {
        var emojiDepth = 0
        var referenceDepth = 0
        return tokens.map { token in
            switch token {
            case let .start(name, _, selfClosing) where !selfClosing:
                if emojiLiteralElements.contains(name) { emojiDepth += 1 }
                if referenceLiteralElements.contains(name) { referenceDepth += 1 }
            case let .end(name):
                if emojiLiteralElements.contains(name) { emojiDepth = max(0, emojiDepth - 1) }
                if referenceLiteralElements.contains(name) { referenceDepth = max(0, referenceDepth - 1) }
            case let .text(text):
                var t = text
                if emojiDepth == 0 { t = replaceEmoji(t, emoji: emoji) }
                if referenceDepth == 0 { t = replaceReferences(t) }
                return .text(t)
            default:
                break
            }
            return token
        }
    }

    static func replaceEmoji(_ text: String, emoji: [String: String]) -> String {
        guard text.contains(":") else { return text }
        let ns = text as NSString
        var out = ""
        var last = 0
        for match in emojiPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let alias = ns.substring(with: match.range(at: 1))
            guard let char = emoji[alias] else { continue }
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last)) + char
            last = match.range.location + match.range.length
        }
        guard last > 0 else { return text }
        return out + ns.substring(from: last)
    }

    static func replaceReferences(_ text: String) -> String {
        let ns = text as NSString
        let matches = referencePattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return text }
        var out = ""
        var last = 0
        for match in matches {
            out += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let whole = ns.substring(with: match.range)
            if match.range(withName: "mention").location != NSNotFound {
                let cls = whole.contains("/") ? "team-mention" : "user-mention"
                out += "<span class=\"\(cls)\">\(whole)</span>"
            } else if match.range(withName: "issue").location != NSNotFound {
                out += "<span class=\"issue-link\">\(whole)</span>"
            } else {
                out += "<span class=\"commit-link\" title=\"\(whole)\"><tt>\(whole.prefix(7))</tt></span>"
            }
            last = match.range.location + match.range.length
        }
        return out + ns.substring(from: last)
    }

    // MARK: Task lists

    /// Adds GitHub's task-list classes and label to cmark-gfm's checkbox items.
    static func taskLists(_ tokens: [HTMLToken]) -> [HTMLToken] {
        var out = tokens
        var listStack: [Int] = []
        var itemStack: [Int] = []
        for i in tokens.indices {
            switch tokens[i] {
            case let .start(name, _, _) where name == "ul" || name == "ol":
                listStack.append(i)
            case let .end(name) where name == "ul" || name == "ol":
                _ = listStack.popLast()
            case .start(name: "li", _, _):
                itemStack.append(i)
            case .end(name: "li"):
                _ = itemStack.popLast()
            case let .start(name: "input", attributes, selfClosing):
                guard let li = itemStack.last, firstContent(tokens, after: li) == i else { continue }
                let checked = attributes.contains { $0.name == "checked" }
                var attrs = attributes.filter { $0.name != "class" && $0.name != "aria-label" }
                attrs.append(HTMLAttribute(name: "class", value: "task-list-item-checkbox"))
                attrs.append(HTMLAttribute(name: "aria-label", value: checked ? "Completed task" : "Incomplete task"))
                out[i] = .start(name: "input", attributes: attrs, selfClosing: selfClosing)
                out[li] = addClass(out[li], "task-list-item")
                if let list = listStack.last { out[list] = addClass(out[list], "contains-task-list") }
            default:
                break
            }
        }
        return out
    }

    /// Index of the first non-whitespace token inside the element at `index`, looking through one `<p>`.
    private static func firstContent(_ tokens: [HTMLToken], after index: Int) -> Int? {
        var j = index + 1
        while j < tokens.count {
            if case let .text(t) = tokens[j], t.allSatisfy(\.isWhitespace) { j += 1; continue }
            if tokens[j].startName == "p" { j += 1; continue }
            return j
        }
        return nil
    }

    static func addClass(_ token: HTMLToken, _ cls: String) -> HTMLToken {
        guard case .start(let name, var attributes, let selfClosing) = token else { return token }
        if let k = attributes.firstIndex(where: { $0.name == "class" }) {
            let existing = attributes[k].value ?? ""
            if !existing.split(separator: " ").contains(Substring(cls)) {
                attributes[k].value = existing.isEmpty ? cls : existing + " " + cls
            }
        } else {
            attributes.append(HTMLAttribute(name: "class", value: cls))
        }
        return .start(name: name, attributes: attributes, selfClosing: selfClosing)
    }

    // MARK: Code blocks and diagrams

    /// Fence languages that render as plain source until a later change adds them.
    static let deferredLanguages: Set<String> = ["math", "geojson", "topojson", "stl"]

    /// Fence languages that mean "no highlighting", so they don't load highlight.js.
    static let plainLanguages: Set<String> = ["text", "plaintext", "txt", "plain", "none"]

    struct CodeBlockResult {
        var tokens: [HTMLToken]
        var mermaidCount = 0
        var highlightedCount = 0
    }

    /// cmark-gfm writes `<pre lang="x"><code>`. Mermaid blocks become diagram placeholders, deferred
    /// languages become plain code, and others get highlight.js's `language-x` class.
    static func codeBlocks(_ tokens: [HTMLToken]) -> CodeBlockResult {
        var result = CodeBlockResult(tokens: [])
        result.tokens.reserveCapacity(tokens.count)
        var i = 0
        var inMermaid = false
        while i < tokens.count {
            let token = tokens[i]
            if case .start(name: "pre", let attributes, _) = token {
                let lang = (attributes.first { $0.name == "lang" }?.value ?? "").lowercased()
                let rest = attributes.filter { $0.name != "lang" }
                let codeFollows = i + 1 < tokens.count && tokens[i + 1].startName == "code"
                if lang == "mermaid", codeFollows {
                    result.mermaidCount += 1
                    result.tokens.append(.start(name: "div", attributes: [
                        HTMLAttribute(name: "class", value: "mermaid-diagram"), HTMLAttribute(name: "data-state", value: "pending"),
                    ], selfClosing: false))
                    result.tokens.append(.start(name: "pre", attributes: [HTMLAttribute(name: "class", value: "mermaid-source")], selfClosing: false))
                    inMermaid = true
                    i += 1
                    continue
                }
                result.tokens.append(.start(name: "pre", attributes: rest, selfClosing: false))
                if codeFollows, !lang.isEmpty, !deferredLanguages.contains(lang), !plainLanguages.contains(lang) {
                    let safe = String(lang.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || "+#_.-".unicodeScalars.contains($0) })
                    if !safe.isEmpty {
                        result.highlightedCount += 1
                        result.tokens.append(.start(name: "code", attributes: [HTMLAttribute(name: "class", value: "language-" + safe)], selfClosing: false))
                        i += 2
                        continue
                    }
                }
                i += 1
                continue
            }
            if inMermaid, token.endName == "pre" {
                result.tokens.append(token)
                result.tokens.append(.end(name: "div"))
                inMermaid = false
                i += 1
                continue
            }
            result.tokens.append(token)
            i += 1
        }
        return result
    }
}
