import Foundation
import Testing
@testable import MarkdownRenderer

/// Every `Fixtures/<group>/<name>.md` renders to the body in `<name>.html` beside it.
/// Run with `UPDATE_FIXTURES=1` to write the current output for review instead of comparing.
enum Fixtures {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")

    static func all() -> [String] {
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "md" } ?? []
        return files.map { String($0.path.dropFirst(root.path.count + 1).dropLast(3)) }.sorted()
    }

    static func markdown(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name + ".md"), encoding: .utf8)
    }

    static func expectedURL(_ name: String) -> URL { root.appendingPathComponent(name + ".html") }
}

@Test(arguments: Fixtures.all())
func fixtureRendersAsExpected(_ name: String) throws {
    let actual = MarkdownRenderer.renderBody(try Fixtures.markdown(name)).html
    let expectedURL = Fixtures.expectedURL(name)
    if ProcessInfo.processInfo.environment["UPDATE_FIXTURES"] == "1" {
        try actual.write(to: expectedURL, atomically: true, encoding: .utf8)
        return
    }
    let expected = try String(contentsOf: expectedURL, encoding: .utf8)
    #expect(actual == expected, "\(name)")
}

@Test func everyFixtureHasExpectedOutput() {
    let missing = Fixtures.all().filter { !FileManager.default.fileExists(atPath: Fixtures.expectedURL($0).path) }
    #expect(missing.isEmpty, "fixtures without .html: \(missing)")
}
