import Foundation
import Testing
@testable import MarkdownRenderer

@Test func everyCheckboxIsDisabled() throws {
    let html = MarkdownRenderer.renderBody(try Fixtures.markdown("tasks/task-list")).html
    let inputs = HTMLTokenizer.tokenize(html).filter { $0.startName == "input" }
    #expect(inputs.count == 6)
    for input in inputs {
        #expect(input.hasAttribute("disabled"), "\(input)")
        #expect(input.attribute("type") == "checkbox")
    }
    #expect(inputs.filter { $0.hasAttribute("checked") }.count == 4)
}
