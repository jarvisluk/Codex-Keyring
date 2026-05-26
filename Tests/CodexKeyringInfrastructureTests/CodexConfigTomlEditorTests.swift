import XCTest
@testable import CodexKeyringInfrastructure

final class CodexConfigTomlEditorTests: XCTestCase {
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

    func testInPlaceUpdatesPreserveCommentsBlankLinesAndSections() {
        let source = """
        # User config — do not delete
        model = "gpt-5"
        model_reasoning_effort = "medium"


        [projects."/Users/me/project"]
        trust_level = "trusted"
        """
        let updated = editor.applying(
            [
                "model": .string("gpt-5.5"),
                "model_reasoning_effort": .string("xhigh"),
            ],
            to: source
        )

        XCTAssertTrue(updated.contains("# User config — do not delete"))
        XCTAssertTrue(updated.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(updated.contains("model_reasoning_effort = \"xhigh\""))
        // Section + its contents must be byte-preserved.
        XCTAssertTrue(updated.contains("[projects.\"/Users/me/project\"]"))
        XCTAssertTrue(updated.contains("trust_level = \"trusted\""))
        // Old value must not survive anywhere.
        XCTAssertFalse(updated.contains("model = \"gpt-5\""))
    }

    func testAppendsMissingKeysBeforeFirstSection() {
        let source = """
        model = "gpt-5"

        [projects."/Users/me"]
        trust_level = "trusted"
        """
        let updated = editor.applying(
            [
                "approval_policy": .string("never"),
                "sandbox_mode": .string("workspace-write"),
            ],
            to: source
        )

        // Both keys appended in alphabetical order.
        guard let approvalIdx = updated.range(of: "approval_policy = \"never\""),
              let sandboxIdx = updated.range(of: "sandbox_mode = \"workspace-write\""),
              let sectionIdx = updated.range(of: "[projects.\"/Users/me\"]")
        else {
            XCTFail("missing inserted keys or section")
            return
        }
        XCTAssertLessThan(approvalIdx.lowerBound, sandboxIdx.lowerBound)
        XCTAssertLessThan(sandboxIdx.lowerBound, sectionIdx.lowerBound)
        // Original model value untouched.
        XCTAssertTrue(updated.contains("model = \"gpt-5\""))
    }

    func testAppendsToEmptySource() {
        let updated = editor.applying(
            ["model": .string("gpt-5.5")],
            to: ""
        )
        XCTAssertTrue(updated.contains("model = \"gpt-5.5\""))
    }

    func testEscapesQuotesAndBackslashesInWrittenStrings() {
        let updated = editor.applying(
            ["model": .string("weird \"name\" with \\slash")],
            to: ""
        )
        XCTAssertTrue(updated.contains(#"model = "weird \"name\" with \\slash""#))
        // And read back round-trips:
        XCTAssertEqual(
            editor.readString("model", in: updated),
            "weird \"name\" with \\slash"
        )
    }

    func testNilUpdateLeavesExistingValueAlone() {
        let source = "model = \"gpt-5\"\n"
        let updated = editor.applying(["model": nil], to: source)
        XCTAssertEqual(updated, source)
    }

    func testRespectsCRLFLineEndings() {
        let source = "model = \"gpt-5\"\r\n\r\n[features]\r\njs_repl = false\r\n"
        let updated = editor.applying(["model": .string("gpt-5.5")], to: source)
        XCTAssertTrue(updated.contains("\r\n"))
        XCTAssertFalse(updated.contains("\n\n"), "CRLF document should not gain bare LFs")
        XCTAssertTrue(updated.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(updated.contains("[features]"))
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
