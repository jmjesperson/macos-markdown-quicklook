import Foundation

/// Allowlist sanitizer for the HTML cmark-gfm produces from a file, including the file's raw HTML.
///
/// Elements not on the list lose their tags but keep their text, as on GitHub. Elements that carry
/// active or embedded content are removed with everything inside them. Comments are dropped. Event
/// handlers and `style` are never on an attribute list, and URL attributes must use an allowed scheme.
/// This is a tidiness layer: the Content Security Policy on the page is the security boundary.
enum Sanitizer {
    static let allowedElements: Set<String> = [
        "h1", "h2", "h3", "h4", "h5", "h6", "p", "br", "hr", "b", "i", "strong", "em", "a", "pre", "code",
        "img", "tt", "div", "span", "ins", "del", "sup", "sub", "ol", "ul", "li", "table", "thead", "tbody",
        "tfoot", "tr", "td", "th", "caption", "blockquote", "dl", "dt", "dd", "kbd", "q", "samp", "var",
        "ruby", "rt", "rp", "s", "strike", "summary", "details", "figure", "figcaption", "bdo",
        "cite", "dfn", "mark", "small", "time", "wbr", "input", "picture", "source", "section", "center",
    ]

    /// Removed together with their content.
    static let droppedWithContent: Set<String> = [
        "script", "style", "iframe", "object", "embed", "applet", "frame", "frameset", "noembed", "noframes",
        "noscript", "template", "textarea", "title", "xmp", "plaintext", "svg", "math", "select", "head",
        "audio", "video", "canvas", "link", "meta", "base", "param", "track", "keygen",
    ]

    /// Elements with no end tag. Dropping one of these must not skip what follows it.
    static let voidElements: Set<String> = [
        "br", "hr", "img", "input", "source", "wbr", "col", "area", "embed", "link", "meta", "base", "param",
        "track", "keygen", "frame",
    ]

    static let globalAttributes: Set<String> = [
        "align", "alt", "aria-describedby", "aria-hidden", "aria-label", "aria-labelledby", "border",
        "cellpadding", "cellspacing", "colspan", "dir", "headers", "height", "hspace", "id", "lang", "name",
        "nowrap", "role", "rowspan", "scope", "span", "start", "title", "valign", "vspace", "width", "open",
        "datetime", "reversed", "type", "value", "abbr", "summary", "itemprop",
        "data-footnotes", "data-footnote-ref", "data-footnote-backref", "data-footnote-backref-idx",
    ]

    /// Attributes that hold a URL, and the schemes each allows. `nil` scheme means a relative URL.
    static let urlAttributes: [String: Set<String>] = [
        "href": ["http", "https", "mailto"],
        "src": ["http", "https"],
        "srcset": ["http", "https"],
        "cite": ["http", "https"],
        "longdesc": ["http", "https"],
    ]

    static let perElementAttributes: [String: Set<String>] = [
        "a": ["href"],
        "img": ["src", "longdesc"],
        "source": ["srcset", "media", "sizes"],
        "blockquote": ["cite"], "del": ["cite"], "ins": ["cite"], "q": ["cite"],
        "input": ["checked", "disabled"],
        "pre": ["lang"],
        "td": [], "th": [],
    ]

    /// `class` survives only with these values: the ones cmark-gfm itself writes.
    static let allowedClasses: Set<String> = ["footnotes", "footnote-backref", "data-footnote-backref", "sr-only"]

    /// GitHub's prefix for `id` and `name` from the file, so the file can't shadow the page's own ids or
    /// DOM properties such as `document.querySelectorAll`. In-page `#` links get the same prefix.
    static let userContentPrefix = "user-content-"

    static func sanitize(_ tokens: [HTMLToken]) -> [HTMLToken] {
        var out: [HTMLToken] = []
        out.reserveCapacity(tokens.count)
        var skipName: String?
        var skipDepth = 0

        for (index, token) in tokens.enumerated() {
            if let name = skipName {
                switch token {
                case let .start(n, _, selfClosing) where n == name && !selfClosing: skipDepth += 1
                case let .end(n) where n == name:
                    skipDepth -= 1
                    if skipDepth == 0 { skipName = nil }
                default: break
                }
                continue
            }
            switch token {
            case let .text(text):
                // A '<' still in text is one the tokenizer couldn't read as a tag (for example an
                // unterminated attribute quote). Escape it so the browser can't build a tag from it.
                out.append(.text(text.replacingOccurrences(of: "<", with: "&lt;")))
            case .comment, .other:
                continue
            case let .start(name, attributes, selfClosing):
                if droppedWithContent.contains(name) {
                    // Skip the content only when the element is closed; an unclosed one loses just its tag.
                    if !selfClosing && !voidElements.contains(name) && hasMatchingEnd(tokens, after: index, name: name) {
                        skipName = name
                        skipDepth = 1
                    }
                    continue
                }
                guard allowedElements.contains(name) else { continue }
                if name == "input" {
                    // Only task-list checkboxes, and never editable.
                    guard attributes.first(where: { $0.name == "type" })?.value?.lowercased() == "checkbox" else { continue }
                }
                var kept = cleanAttributes(attributes, element: name)
                if name == "input", !kept.contains(where: { $0.name == "disabled" }) {
                    kept.append(HTMLAttribute(name: "disabled", value: ""))
                }
                if voidElements.contains(name) {
                    out.append(.start(name: name, attributes: kept, selfClosing: true))
                } else {
                    // `<span/>` opens a span in HTML; close it at once so it can't swallow what follows.
                    out.append(.start(name: name, attributes: kept, selfClosing: false))
                    if selfClosing { out.append(.end(name: name)) }
                }
            case let .end(name):
                guard allowedElements.contains(name), !voidElements.contains(name) else { continue }
                out.append(token)
            }
        }
        return out
    }

    private static func hasMatchingEnd(_ tokens: [HTMLToken], after index: Int, name: String) -> Bool {
        var depth = 1
        for token in tokens[(index + 1)...] {
            switch token {
            case let .start(n, _, selfClosing) where n == name && !selfClosing: depth += 1
            case let .end(n) where n == name:
                depth -= 1
                if depth == 0 { return true }
            default: break
            }
        }
        return false
    }

    static func cleanAttributes(_ attributes: [HTMLAttribute], element: String) -> [HTMLAttribute] {
        let extra = perElementAttributes[element] ?? []
        var kept: [HTMLAttribute] = []
        for attribute in attributes {
            let name = attribute.name
            if name == "class" {
                let classes = (attribute.value ?? "").split(separator: " ").map(String.init).filter(allowedClasses.contains)
                if !classes.isEmpty { kept.append(HTMLAttribute(name: "class", value: classes.joined(separator: " "))) }
                continue
            }
            guard globalAttributes.contains(name) || extra.contains(name) else { continue }
            if element == "input", name == "type" { kept.append(HTMLAttribute(name: "type", value: "checkbox")); continue }
            if name == "id" || name == "name", let value = attribute.value, !value.isEmpty {
                kept.append(HTMLAttribute(name: name, value: value.hasPrefix(userContentPrefix) ? value : userContentPrefix + value))
                continue
            }
            if name == "href", let value = attribute.value, value.count > 1, value.hasPrefix("#") {
                let target = String(value.dropFirst())
                kept.append(HTMLAttribute(name: name, value: "#" + (target.hasPrefix(userContentPrefix) ? target : userContentPrefix + target)))
                continue
            }
            if let schemes = urlAttributes[name] {
                guard let value = attribute.value else { continue }
                if name == "srcset" {
                    guard srcsetIsSafe(value, schemes: schemes) else { continue }
                } else {
                    guard urlIsSafe(value, schemes: schemes) else { continue }
                }
            }
            kept.append(attribute)
        }
        return kept
    }

    /// A URL is safe if it is relative, a fragment, or uses one of `schemes`.
    static func urlIsSafe(_ raw: String, schemes: Set<String>) -> Bool {
        // Browsers ignore leading spaces and control characters, and tabs or newlines anywhere in a scheme.
        let cleaned = String(String.UnicodeScalarView(raw.unicodeScalars.filter { $0.value > 0x20 && $0.value != 0x7F }))
        guard let colon = cleaned.firstIndex(of: ":") else { return true }
        let beforeColon = cleaned[..<colon]
        if beforeColon.contains(where: { $0 == "/" || $0 == "?" || $0 == "#" }) { return true }
        return schemes.contains(beforeColon.lowercased())
    }

    static func srcsetIsSafe(_ value: String, schemes: Set<String>) -> Bool {
        srcsetURLs(value).allSatisfy { urlIsSafe($0, schemes: schemes) }
    }

    /// The URLs in a `srcset` value, without their width or density descriptors.
    static func srcsetURLs(_ value: String) -> [String] {
        value.split(separator: ",").compactMap { candidate in
            candidate.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).first.map(String.init)
        }
    }
}
