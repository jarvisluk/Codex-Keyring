import XCTest
@testable import CodexKeyringInfrastructure

final class CodexGlobalStateEditorReadingTests: XCTestCase {
    private let editor = CodexGlobalStateEditor()

    func testReadsStringAtNestedPath() {
        let data = Data(#"{"electron-persisted-atom-state":{"agent-mode-by-host-id":{"local":"full-access"}}}"#.utf8)
        XCTAssertEqual(
            editor.readString(at: ["electron-persisted-atom-state", "agent-mode-by-host-id", "local"], in: data),
            "full-access"
        )
        XCTAssertNil(editor.readString(at: ["nope"], in: data))
    }

    func testReadsBoolAtNestedPath() {
        let data = Data(#"{"electron-persisted-atom-state":{"skip-full-access-confirm":true,"some-int":1}}"#.utf8)
        XCTAssertEqual(
            editor.readBool(at: ["electron-persisted-atom-state", "skip-full-access-confirm"], in: data),
            true
        )
        // Integers must not be coerced to bools.
        XCTAssertNil(editor.readBool(at: ["electron-persisted-atom-state", "some-int"], in: data))
    }

    func testReadsStringArrayAtPath() {
        let data = Data(#"{"project-order":["/a","remote-id"],"bad":["/a",1]}"#.utf8)
        XCTAssertEqual(editor.readStringArray(at: ["project-order"], in: data), ["/a", "remote-id"])
        XCTAssertNil(editor.readStringArray(at: ["bad"], in: data))
    }
}
