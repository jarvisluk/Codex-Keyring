import XCTest
import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAgentPreferencesPortTests: XCTestCase {
    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-keyring-prefs-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let workDir, FileManager.default.fileExists(atPath: workDir.path) {
            try FileManager.default.removeItem(at: workDir)
        }
    }

    private func makePort() -> LiveCodexAgentPreferencesPort {
        LiveCodexAgentPreferencesPort(
            configTomlURL: workDir.appendingPathComponent("config.toml"),
            globalStateURL: workDir.appendingPathComponent(".codex-global-state.json")
        )
    }

    func testCaptureReturnsEmptyWhenFilesMissing() async throws {
        let port = makePort()
        let prefs = try await port.captureCurrent()
        XCTAssertTrue(prefs.isEmpty)
    }

    func testCaptureReadsFromBothFiles() async throws {
        let tomlURL = workDir.appendingPathComponent("config.toml")
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json")
        try """
        model = "gpt-5.5"
        model_reasoning_effort = "xhigh"
        approval_policy = "on-request"
        approvals_reviewer = "guardian_subagent"
        sandbox_mode = "workspace-write"

        [projects."/x"]
        trust_level = "trusted"
        """.write(to: tomlURL, atomically: true, encoding: .utf8)
        try #"{"electron-persisted-atom-state":{"agent-mode-by-host-id":{"local":"full-access"},"skip-full-access-confirm":true}}"#
            .write(to: stateURL, atomically: true, encoding: .utf8)

        let prefs = try await makePort().captureCurrent()
        XCTAssertEqual(prefs.model, "gpt-5.5")
        XCTAssertEqual(prefs.modelReasoningEffort, "xhigh")
        XCTAssertEqual(prefs.approvalPolicy, "on-request")
        XCTAssertEqual(prefs.approvalsReviewer, "guardian_subagent")
        XCTAssertEqual(prefs.sandboxMode, "workspace-write")
        XCTAssertEqual(prefs.agentMode, "full-access")
        XCTAssertEqual(prefs.skipFullAccessConfirm, true)
    }

    func testApplyPreservesUnrelatedTomlAndJsonKeys() async throws {
        let tomlURL = workDir.appendingPathComponent("config.toml")
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json")
        let originalToml = """
        # important user comment
        model = "gpt-5"
        notify = ["/usr/local/bin/notifier", "turn-ended"]

        [projects."/Users/me/x"]
        trust_level = "trusted"

        [features]
        js_repl = false
        memories = true
        """
        try originalToml.write(to: tomlURL, atomically: true, encoding: .utf8)
        let originalState = #"{"electron-saved-workspace-roots":["/Users/me/x"],"electron-persisted-atom-state":{"some-unrelated":42,"agent-mode-by-host-id":{"local":"auto-review"}}}"#
        try originalState.write(to: stateURL, atomically: true, encoding: .utf8)

        let port = makePort()
        try await port.apply(AccountAgentPreferences(
            model: "gpt-5.5",
            modelReasoningEffort: "xhigh",
            agentMode: "full-access",
            skipFullAccessConfirm: true
        ))

        let updatedToml = try String(contentsOf: tomlURL, encoding: .utf8)
        XCTAssertTrue(updatedToml.contains("# important user comment"))
        XCTAssertTrue(updatedToml.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(updatedToml.contains("model_reasoning_effort = \"xhigh\""))
        XCTAssertTrue(updatedToml.contains("notify = [\"/usr/local/bin/notifier\", \"turn-ended\"]"))
        XCTAssertTrue(updatedToml.contains("[projects.\"/Users/me/x\"]"))
        XCTAssertTrue(updatedToml.contains("trust_level = \"trusted\""))
        XCTAssertTrue(updatedToml.contains("[features]"))
        XCTAssertTrue(updatedToml.contains("memories = true"))

        let updatedStateData = try Data(contentsOf: stateURL)
        let parsed = try JSONSerialization.jsonObject(with: updatedStateData) as! [String: Any]
        XCTAssertEqual(parsed["electron-saved-workspace-roots"] as? [String], ["/Users/me/x"])
        let atom = parsed["electron-persisted-atom-state"] as! [String: Any]
        XCTAssertEqual(atom["some-unrelated"] as? Int, 42)
        XCTAssertEqual(
            (atom["agent-mode-by-host-id"] as? [String: Any])?["local"] as? String,
            "full-access"
        )
        XCTAssertEqual((atom["skip-full-access-confirm"] as? NSNumber)?.boolValue, true)
    }

    func testCaptureAndRestoreProjectArrangement() async throws {
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json")
        try """
        {
          "project-order": ["/before-a", "remote-before"],
          "pinned-project-ids": ["/before-a"],
          "electron-persisted-atom-state": {
            "sidebar-organize-mode-v1": "manual",
            "agent-mode-by-host-id": { "local": "auto-review" }
          },
          "electron-saved-workspace-roots": ["/keep"]
        }
        """.write(to: stateURL, atomically: true, encoding: .utf8)

        let port = makePort()
        let arrangement = try await port.captureProjectArrangement()
        XCTAssertEqual(arrangement.projectOrder, ["/before-a", "remote-before"])
        XCTAssertEqual(arrangement.pinnedProjectIDs, ["/before-a"])
        XCTAssertEqual(arrangement.sidebarOrganizeMode, "manual")

        try """
        {
          "project-order": ["/reset"],
          "pinned-project-ids": [],
          "electron-persisted-atom-state": {
            "sidebar-organize-mode-v1": "recent",
            "agent-mode-by-host-id": { "local": "full-access" }
          },
          "electron-saved-workspace-roots": ["/keep"]
        }
        """.write(to: stateURL, atomically: true, encoding: .utf8)

        try await port.restoreProjectArrangement(arrangement)

        let updatedStateData = try Data(contentsOf: stateURL)
        let parsed = try JSONSerialization.jsonObject(with: updatedStateData) as! [String: Any]
        XCTAssertEqual(parsed["project-order"] as? [String], ["/before-a", "remote-before"])
        XCTAssertEqual(parsed["pinned-project-ids"] as? [String], ["/before-a"])
        XCTAssertEqual(parsed["electron-saved-workspace-roots"] as? [String], ["/keep"])
        let atom = parsed["electron-persisted-atom-state"] as! [String: Any]
        XCTAssertEqual(atom["sidebar-organize-mode-v1"] as? String, "manual")
        XCTAssertEqual(
            (atom["agent-mode-by-host-id"] as? [String: Any])?["local"] as? String,
            "full-access"
        )
    }

    func testApplyIsNoopForEmptyPreferences() async throws {
        let tomlURL = workDir.appendingPathComponent("config.toml")
        try "model = \"gpt-5\"\n".write(to: tomlURL, atomically: true, encoding: .utf8)
        let originalSize = try FileManager.default.attributesOfItem(atPath: tomlURL.path)[.size] as! Int

        try await makePort().apply(AccountAgentPreferences())

        let afterSize = try FileManager.default.attributesOfItem(atPath: tomlURL.path)[.size] as! Int
        XCTAssertEqual(afterSize, originalSize)
    }
}
