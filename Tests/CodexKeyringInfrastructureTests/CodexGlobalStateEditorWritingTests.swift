import XCTest
@testable import CodexKeyringInfrastructure

final class CodexGlobalStateEditorWritingTests: XCTestCase {
    private let editor = CodexGlobalStateEditor()

    func testWritePreservesOtherKeysAndCreatesMissingParents() throws {
        let original = Data(
            #"{"electron-persisted-atom-state":{"some-unrelated":42,"agent-mode-by-host-id":{"local":"auto-review"}},"electron-saved-workspace-roots":["/x","/y"]}"#.utf8
        )
        let updated = try editor.writing(
            "full-access",
            at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"],
            in: original
        )

        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        let atom = try XCTUnwrap(parsed["electron-persisted-atom-state"] as? [String: Any])
        XCTAssertEqual(atom["some-unrelated"] as? Int, 42)
        let agentMode = try XCTUnwrap(atom["agent-mode-by-host-id"] as? [String: Any])
        XCTAssertEqual(agentMode["local"] as? String, "full-access")
        let workspaces = try XCTUnwrap(parsed["electron-saved-workspace-roots"] as? [String])
        XCTAssertEqual(workspaces, ["/x", "/y"])
    }

    func testWriteCanCreateBrandNewBranch() throws {
        let original = Data(#"{"electron-persisted-atom-state":{}}"#.utf8)
        let updated = try editor.writing(
            "full-access",
            at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"],
            in: original
        )
        XCTAssertEqual(
            editor.readString(at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"], in: updated),
            "full-access"
        )
    }

    func testWriteRefusesToReplaceExistingNonObjectParent() throws {
        let original = Data(#"{"electron-persisted-atom-state":"legacy-value"}"#.utf8)

        do {
            _ = try editor.writing(
                "full-access",
                at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"],
                in: original
            )
            XCTFail("Expected non-object parent to fail instead of being overwritten.")
        } catch CodexGlobalStateEditor.EditorError.parentIsNotJSONObject(let path) {
            XCTAssertEqual(path, ["electron-persisted-atom-state"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteBooleanRoundtrips() throws {
        let original = Data(#"{"electron-persisted-atom-state":{}}"#.utf8)
        let updated = try editor.writing(
            NSNumber(value: true),
            at: ["electron-persisted-atom-state", "skip-full-access-confirm"],
            in: original
        )
        let asString = String(decoding: updated, as: UTF8.self)
        XCTAssertTrue(asString.contains("\"skip-full-access-confirm\":true"))
        XCTAssertEqual(
            editor.readBool(at: ["electron-persisted-atom-state", "skip-full-access-confirm"], in: updated),
            true
        )
    }

    func testWriteOnEmptyDataProducesValidJSON() throws {
        let updated = try editor.writing(
            "full-access",
            at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"],
            in: Data()
        )
        let parsed = try JSONSerialization.jsonObject(with: updated)
        XCTAssertNotNil(parsed as? [String: Any])
    }

    func testWriteNilRemovesLeafKey() throws {
        let original = Data(#"{"a":{"b":"c","d":"e"}}"#.utf8)
        let updated = try editor.writing(nil, at: ["a", "b"], in: original)
        XCTAssertNil(editor.readString(at: ["a", "b"], in: updated))
        XCTAssertEqual(editor.readString(at: ["a", "d"], in: updated), "e")
    }
}
