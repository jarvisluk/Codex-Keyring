import XCTest
@testable import CodexKeyringInfrastructure

final class CodexConfigTomlEditorWritingTests: XCTestCase {
    private let editor = CodexConfigTomlEditor()

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
        XCTAssertTrue(updated.contains("[projects.\"/Users/me/project\"]"))
        XCTAssertTrue(updated.contains("trust_level = \"trusted\""))
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

        guard let approvalIdx = updated.range(of: "approval_policy = \"never\""),
              let sandboxIdx = updated.range(of: "sandbox_mode = \"workspace-write\""),
              let sectionIdx = updated.range(of: "[projects.\"/Users/me\"]")
        else {
            XCTFail("missing inserted keys or section")
            return
        }
        XCTAssertLessThan(approvalIdx.lowerBound, sandboxIdx.lowerBound)
        XCTAssertLessThan(sandboxIdx.lowerBound, sectionIdx.lowerBound)
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
}
