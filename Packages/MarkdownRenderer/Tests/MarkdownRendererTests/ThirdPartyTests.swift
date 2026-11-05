import Foundation
import Testing
@testable import MarkdownRenderer

/// Every licence file named in docs/third-party.md ships in the resource bundle, and every bundled
/// licence file is named there.
@Test func licencesInDocsMatchTheBundle() throws {
    let doc = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../docs/third-party.md").standardizedFileURL
    let text = try String(contentsOf: doc, encoding: .utf8)
    let regex = try NSRegularExpression(pattern: "`([A-Za-z0-9.-]+-(?:LICENSE|COPYING)\\.txt)`")
    let named = Set(regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
        String(text[Range($0.range(at: 1), in: text)!])
    })
    let dir = try #require(Bundle.module.url(forResource: "licenses", withExtension: nil, subdirectory: "Resources"))
    let shipped = Set(try FileManager.default.contentsOfDirectory(atPath: dir.path))
    #expect(named.count == 6)
    #expect(named == shipped)
}
