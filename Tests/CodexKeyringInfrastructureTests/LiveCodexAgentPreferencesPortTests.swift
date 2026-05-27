import XCTest
import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAgentPreferencesPortTests: XCTestCase {
    private let workDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-keyring-prefs-tests-\(UUID().uuidString)", isDirectory: true)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: workDir.path) {
            try FileManager.default.removeItem(at: workDir)
        }
    }

    private func makePort(
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.LiveCodexAgentPreferencesPort.\(UUID().uuidString)")
    ) -> LiveCodexAgentPreferencesPort {
        LiveCodexAgentPreferencesPort(
            configTomlURL: workDir.appendingPathComponent("config.toml"),
            globalStateURL: workDir.appendingPathComponent(".codex-global-state.json"),
            ioQueue: ioQueue
        )
    }

    private func makePort(configDir: String, stateDir: String) -> LiveCodexAgentPreferencesPort {
        LiveCodexAgentPreferencesPort(
            configTomlURL: workDir.appendingPathComponent(configDir, isDirectory: true).appendingPathComponent("config.toml"),
            globalStateURL: workDir.appendingPathComponent(stateDir, isDirectory: true).appendingPathComponent(".codex-global-state.json")
        )
    }

    func testCaptureReturnsEmptyWhenFilesMissing() async throws {
        let port = makePort()
        let prefs = try await port.captureCurrent()
        XCTAssertTrue(prefs.isEmpty)
    }

    func testCaptureCurrentThrowsWhenConfigPathIsDirectory() async throws {
        let configURL = workDir.appendingPathComponent("config.toml", isDirectory: true)
        try FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)

        do {
            _ = try await makePort().captureCurrent()
            XCTFail("Expected capture to fail when config.toml is not a file.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected config.toml to be a file"))
        }
    }

    func testCaptureCurrentThrowsWhenStatePathIsDirectory() async throws {
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json", isDirectory: true)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: true)

        do {
            _ = try await makePort().captureCurrent()
            XCTFail("Expected capture to fail when global-state is not a file.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected global-state.json to be a file"))
        }
    }

    func testCaptureProjectArrangementThrowsWhenStatePathIsDirectory() async throws {
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json", isDirectory: true)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: true)

        do {
            _ = try await makePort().captureProjectArrangement()
            XCTFail("Expected project arrangement capture to fail when global-state is not a file.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected global-state.json to be a file"))
        }
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

    func testCaptureCurrentRunsOnConfiguredIOQueue() async throws {
        let tomlURL = workDir.appendingPathComponent("config.toml")
        try "model = \"old\"\n".write(to: tomlURL, atomically: true, encoding: .utf8)
        let ioQueue = DispatchQueue(label: "tests.LiveCodexAgentPreferencesPort.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "agent preferences io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        let port = makePort(ioQueue: ioQueue)

        let captureStarted = expectation(description: "agent preferences capture started")
        let captureTask = Task {
            captureStarted.fulfill()
            return try await port.captureCurrent()
        }
        await fulfillment(of: [captureStarted], timeout: 1)
        try "model = \"queued\"\n".write(to: tomlURL, atomically: true, encoding: .utf8)

        releaseQueue()
        didReleaseQueue = true
        let prefs = try await captureTask.value
        XCTAssertEqual(prefs.model, "queued")
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
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: updatedStateData) as? [String: Any])
        XCTAssertEqual(parsed["electron-saved-workspace-roots"] as? [String], ["/Users/me/x"])
        let atom = try XCTUnwrap(parsed["electron-persisted-atom-state"] as? [String: Any])
        XCTAssertEqual(atom["some-unrelated"] as? Int, 42)
        XCTAssertEqual(
            (atom["agent-mode-by-host-id"] as? [String: Any])?["local"] as? String,
            "full-access"
        )
        XCTAssertEqual((atom["skip-full-access-confirm"] as? NSNumber)?.boolValue, true)
        XCTAssertEqual(try filePermissions(at: tomlURL), 0o600)
        XCTAssertEqual(try filePermissions(at: stateURL), 0o600)
        XCTAssertEqual(try filePermissions(at: workDir), 0o700)
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
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: updatedStateData) as? [String: Any])
        XCTAssertEqual(parsed["project-order"] as? [String], ["/before-a", "remote-before"])
        XCTAssertEqual(parsed["pinned-project-ids"] as? [String], ["/before-a"])
        XCTAssertEqual(parsed["electron-saved-workspace-roots"] as? [String], ["/keep"])
        let atom = try XCTUnwrap(parsed["electron-persisted-atom-state"] as? [String: Any])
        XCTAssertEqual(atom["sidebar-organize-mode-v1"] as? String, "manual")
        XCTAssertEqual(
            (atom["agent-mode-by-host-id"] as? [String: Any])?["local"] as? String,
            "full-access"
        )
        XCTAssertEqual(try filePermissions(at: stateURL), 0o600)
        XCTAssertEqual(try filePermissions(at: workDir), 0o700)
    }

    func testApplyIsNoopForEmptyPreferences() async throws {
        let tomlURL = workDir.appendingPathComponent("config.toml")
        try "model = \"gpt-5\"\n".write(to: tomlURL, atomically: true, encoding: .utf8)
        let originalSize = try fileSize(at: tomlURL)

        try await makePort().apply(AccountAgentPreferences())

        let afterSize = try fileSize(at: tomlURL)
        XCTAssertEqual(afterSize, originalSize)
    }

    func testApplyThrowsWhenConfigPathIsDirectory() async throws {
        let configURL = workDir.appendingPathComponent("config.toml", isDirectory: true)
        try FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)

        do {
            try await makePort().apply(AccountAgentPreferences(model: "gpt-5.5"))
            XCTFail("Expected apply to fail when config.toml is not a file.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected config.toml to be a file"))
        }
    }

    func testApplyThrowsWhenStatePathIsDirectory() async throws {
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json", isDirectory: true)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: true)

        do {
            try await makePort().apply(AccountAgentPreferences(agentMode: "full-access"))
            XCTFail("Expected apply to fail when global-state is not a file.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected global-state.json to be a file"))
        }
    }

    func testApplyRefusesToOverwriteNonObjectGlobalStateParent() async throws {
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json")
        let originalState = #"{"electron-persisted-atom-state":"legacy-value"}"#
        try originalState.write(to: stateURL, atomically: true, encoding: .utf8)

        do {
            try await makePort().apply(AccountAgentPreferences(agentMode: "full-access"))
            XCTFail("Expected apply to fail when a global-state parent is not an object.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected JSON object at electron-persisted-atom-state"))
        }

        XCTAssertEqual(try String(contentsOf: stateURL, encoding: .utf8), originalState)
    }

    func testApplyDoesNotPartiallyWriteTomlWhenGlobalStateIsInvalid() async throws {
        let tomlURL = workDir.appendingPathComponent("config.toml")
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json")
        let originalToml = "model = \"gpt-5\"\n"
        let originalState = #"{"electron-persisted-atom-state":"legacy-value"}"#
        try originalToml.write(to: tomlURL, atomically: true, encoding: .utf8)
        try originalState.write(to: stateURL, atomically: true, encoding: .utf8)

        do {
            try await makePort().apply(AccountAgentPreferences(
                model: "gpt-5.5",
                agentMode: "full-access"
            ))
            XCTFail("Expected apply to fail before writing any prepared updates.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected JSON object at electron-persisted-atom-state"))
        }

        XCTAssertEqual(try String(contentsOf: tomlURL, encoding: .utf8), originalToml)
        XCTAssertEqual(try String(contentsOf: stateURL, encoding: .utf8), originalState)
    }

    func testRestoreProjectArrangementThrowsWhenStatePathIsDirectory() async throws {
        let stateURL = workDir.appendingPathComponent(".codex-global-state.json", isDirectory: true)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: true)

        do {
            try await makePort().restoreProjectArrangement(
                CodexProjectArrangement(projectOrder: ["/project"])
            )
            XCTFail("Expected project arrangement restore to fail when global-state is not a file.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Expected global-state.json to be a file"))
        }
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

    private func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }

    private func fileSize(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        )
        return value.intValue
    }
}
