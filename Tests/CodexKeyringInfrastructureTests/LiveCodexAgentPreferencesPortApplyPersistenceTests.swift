import XCTest
import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAgentPreferencesPortApplyPersistenceTests: LiveCodexAgentPreferencesPortTestCase {
    func testApplyPreservesUnrelatedTomlAndJsonKeys() async throws {
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
        try writeConfigToml(originalToml)
        let originalState = #"{"electron-saved-workspace-roots":["/Users/me/x"],"electron-persisted-atom-state":{"some-unrelated":42,"agent-mode-by-host-id":{"local":"auto-review"}}}"#
        try writeGlobalState(originalState)

        let port = makePort()
        try await port.apply(AccountAgentPreferences(
            model: "gpt-5.5",
            modelReasoningEffort: "xhigh",
            agentMode: "full-access",
            skipFullAccessConfirm: true
        ))

        let updatedToml = try readConfigToml()
        XCTAssertTrue(updatedToml.contains("# important user comment"))
        XCTAssertTrue(updatedToml.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(updatedToml.contains("model_reasoning_effort = \"xhigh\""))
        XCTAssertTrue(updatedToml.contains("notify = [\"/usr/local/bin/notifier\", \"turn-ended\"]"))
        XCTAssertTrue(updatedToml.contains("[projects.\"/Users/me/x\"]"))
        XCTAssertTrue(updatedToml.contains("trust_level = \"trusted\""))
        XCTAssertTrue(updatedToml.contains("[features]"))
        XCTAssertTrue(updatedToml.contains("memories = true"))

        let parsed = try parsedGlobalState()
        XCTAssertEqual(parsed["electron-saved-workspace-roots"] as? [String], ["/Users/me/x"])
        let atom = try XCTUnwrap(parsed["electron-persisted-atom-state"] as? [String: Any])
        XCTAssertEqual(atom["some-unrelated"] as? Int, 42)
        XCTAssertEqual(
            (atom["agent-mode-by-host-id"] as? [String: Any])?["local"] as? String,
            "full-access"
        )
        XCTAssertEqual((atom["skip-full-access-confirm"] as? NSNumber)?.boolValue, true)
        XCTAssertEqual(try filePermissions(at: configTomlURL), 0o600)
        XCTAssertEqual(try filePermissions(at: globalStateURL), 0o600)
        XCTAssertEqual(try filePermissions(at: workDir), 0o700)
    }

    func testApplyIsNoopForEmptyPreferences() async throws {
        try writeConfigToml("model = \"gpt-5\"\n")
        let originalSize = try fileSize(at: configTomlURL)

        try await makePort().apply(AccountAgentPreferences())

        let afterSize = try fileSize(at: configTomlURL)
        XCTAssertEqual(afterSize, originalSize)
    }

    func testApplyCreatesDistinctConfigAndStateDirectoriesPrivately() async throws {
        let port = makePort(configDir: "config-home", stateDir: "state-home")
        let configURL = workDir
            .appendingPathComponent("config-home", isDirectory: true)
            .appendingPathComponent("config.toml")
        let stateURL = workDir
            .appendingPathComponent("state-home", isDirectory: true)
            .appendingPathComponent(".codex-global-state.json")

        try await port.apply(AccountAgentPreferences(
            model: "gpt-5.5",
            agentMode: "full-access"
        ))

        XCTAssertTrue(FileManager.default.fileExists(atPath: configURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateURL.path))
        XCTAssertEqual(try filePermissions(at: configURL), 0o600)
        XCTAssertEqual(try filePermissions(at: stateURL), 0o600)
        XCTAssertEqual(try filePermissions(at: configURL.deletingLastPathComponent()), 0o700)
        XCTAssertEqual(try filePermissions(at: stateURL.deletingLastPathComponent()), 0o700)
    }
}
