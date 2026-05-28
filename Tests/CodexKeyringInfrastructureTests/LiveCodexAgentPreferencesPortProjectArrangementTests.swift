import XCTest
import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAgentPreferencesPortProjectArrangementTests: LiveCodexAgentPreferencesPortTestCase {
    func testCaptureProjectArrangementThrowsWhenStatePathIsDirectory() async throws {
        try createGlobalStatePathDirectory()

        await assertThrowsErrorContaining("Expected global-state.json to be a file") {
            _ = try await makePort().captureProjectArrangement()
        }
    }

    func testCaptureAndRestoreProjectArrangement() async throws {
        try writeGlobalState("""
        {
          "project-order": ["/before-a", "remote-before"],
          "pinned-project-ids": ["/before-a"],
          "electron-persisted-atom-state": {
            "sidebar-organize-mode-v1": "manual",
            "agent-mode-by-host-id": { "local": "auto-review" }
          },
          "electron-saved-workspace-roots": ["/keep"]
        }
        """)

        let port = makePort()
        let arrangement = try await port.captureProjectArrangement()
        XCTAssertEqual(arrangement.projectOrder, ["/before-a", "remote-before"])
        XCTAssertEqual(arrangement.pinnedProjectIDs, ["/before-a"])
        XCTAssertEqual(arrangement.sidebarOrganizeMode, "manual")

        try writeGlobalState("""
        {
          "project-order": ["/reset"],
          "pinned-project-ids": [],
          "electron-persisted-atom-state": {
            "sidebar-organize-mode-v1": "recent",
            "agent-mode-by-host-id": { "local": "full-access" }
          },
          "electron-saved-workspace-roots": ["/keep"]
        }
        """)

        try await port.restoreProjectArrangement(arrangement)

        let parsed = try parsedGlobalState()
        XCTAssertEqual(parsed["project-order"] as? [String], ["/before-a", "remote-before"])
        XCTAssertEqual(parsed["pinned-project-ids"] as? [String], ["/before-a"])
        XCTAssertEqual(parsed["electron-saved-workspace-roots"] as? [String], ["/keep"])
        let atom = try XCTUnwrap(parsed["electron-persisted-atom-state"] as? [String: Any])
        XCTAssertEqual(atom["sidebar-organize-mode-v1"] as? String, "manual")
        XCTAssertEqual(
            (atom["agent-mode-by-host-id"] as? [String: Any])?["local"] as? String,
            "full-access"
        )
        XCTAssertEqual(try filePermissions(at: globalStateURL), 0o600)
        XCTAssertEqual(try filePermissions(at: workDir), 0o700)
    }

    func testRestoreProjectArrangementThrowsWhenStatePathIsDirectory() async throws {
        try createGlobalStatePathDirectory()

        await assertThrowsErrorContaining("Expected global-state.json to be a file") {
            try await makePort().restoreProjectArrangement(
                CodexProjectArrangement(projectOrder: ["/project"])
            )
        }
    }
}
