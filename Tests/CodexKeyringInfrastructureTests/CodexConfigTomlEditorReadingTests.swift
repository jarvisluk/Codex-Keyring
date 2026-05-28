import XCTest
@testable import CodexKeyringInfrastructure

final class CodexConfigTomlEditorReadingTests: XCTestCase {
    private let editor = CodexConfigTomlEditor()

    func testReadsRootTableStringsAndIgnoresSectionKeys() {
        let source = """
        model = "gpt-5.5"
        model_reasoning_effort = "xhigh"
        approval_policy = "on-request"

        [tui]
        model = "this-should-not-be-returned"
        """
        XCTAssertEqual(editor.readString("model", in: source), "gpt-5.5")
        XCTAssertEqual(editor.readString("model_reasoning_effort", in: source), "xhigh")
        XCTAssertEqual(editor.readString("approval_policy", in: source), "on-request")
        XCTAssertNil(editor.readString("does_not_exist", in: source))
    }

    func testReadsBoolValues() {
        let source = """
        skip_x = true
        do_y = false # toggle off
        """
        XCTAssertEqual(editor.readBool("skip_x", in: source), true)
        XCTAssertEqual(editor.readBool("do_y", in: source), false)
        XCTAssertNil(editor.readBool("missing", in: source))
    }
}
