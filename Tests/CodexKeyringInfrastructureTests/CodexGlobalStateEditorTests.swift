import XCTest
@testable import CodexKeyringInfrastructure

final class CodexGlobalStateEditorTests: XCTestCase {
    private let editor = CodexGlobalStateEditor()

    func testReadsStringAtNestedPath() {
        let data = #"{"electron-persisted-atom-state":{"agent-mode-by-host-id":{"local":"full-access"}}}"#
            .data(using: .utf8)!
        XCTAssertEqual(
            editor.readString(at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"], in: data),
            "full-access"
        )
        XCTAssertNil(editor.readString(at: ["nope"], in: data))
    }

    func testReadsBoolAtNestedPath() {
        let data = #"{"electron-persisted-atom-state":{"skip-full-access-confirm":true,"some-int":1}}"#
            .data(using: .utf8)!
        XCTAssertEqual(
            editor.readBool(at: ["electron-persisted-atom-state", "skip-full-access-confirm"], in: data),
            true
        )
        // Integers must not be coerced to bools.
        XCTAssertNil(editor.readBool(at: ["electron-persisted-atom-state", "some-int"], in: data))
    }

    func testReadsStringArrayAtPath() {
        let data = #"{"project-order":["/a","remote-id"],"bad":["/a",1]}"#
            .data(using: .utf8)!
        XCTAssertEqual(editor.readStringArray(at: ["project-order"], in: data), ["/a", "remote-id"])
        XCTAssertNil(editor.readStringArray(at: ["bad"], in: data))
    }

    func testWritePreservesOtherKeysAndCreatesMissingParents() throws {
        let original = #"{"electron-persisted-atom-state":{"some-unrelated":42,"agent-mode-by-host-id":{"local":"auto-review"}},"electron-saved-workspace-roots":["/x","/y"]}"#
            .data(using: .utf8)!
        let updated = try editor.writing(
            "full-access",
            at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"],
            in: original
        )

        let parsed = try JSONSerialization.jsonObject(with: updated) as! [String: Any]
        let atom = parsed["electron-persisted-atom-state"] as! [String: Any]
        XCTAssertEqual(atom["some-unrelated"] as? Int, 42)
        let agentMode = atom["agent-mode-by-host-id"] as! [String: Any]
        XCTAssertEqual(agentMode["local"] as? String, "full-access")
        let workspaces = parsed["electron-saved-workspace-roots"] as! [String]
        XCTAssertEqual(workspaces, ["/x", "/y"])
    }

    func testWriteCanCreateBrandNewBranch() throws {
        let original = #"{"electron-persisted-atom-state":{}}"#.data(using: .utf8)!
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

    func testWriteBooleanRoundtrips() throws {
        let original = #"{"electron-persisted-atom-state":{}}"#.data(using: .utf8)!
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
        let original = #"{"a":{"b":"c","d":"e"}}"#.data(using: .utf8)!
        let updated = try editor.writing(nil, at: ["a", "b"], in: original)
        XCTAssertNil(editor.readString(at: ["a", "b"], in: updated))
        XCTAssertEqual(editor.readString(at: ["a", "d"], in: updated), "e")
    }
}
