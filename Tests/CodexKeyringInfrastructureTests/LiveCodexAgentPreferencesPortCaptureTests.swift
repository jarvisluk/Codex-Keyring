import XCTest
import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAgentPreferencesPortCaptureTests: LiveCodexAgentPreferencesPortTestCase {
    func testCaptureReturnsEmptyWhenFilesMissing() async throws {
        let port = makePort()
        let prefs = try await port.captureCurrent()
        XCTAssertTrue(prefs.isEmpty)
    }

    func testCaptureCurrentThrowsWhenConfigPathIsDirectory() async throws {
        try createConfigPathDirectory()

        await assertThrowsErrorContaining("Expected config.toml to be a file") {
            _ = try await makePort().captureCurrent()
        }
    }

    func testCaptureCurrentThrowsWhenStatePathIsDirectory() async throws {
        try createGlobalStatePathDirectory()

        await assertThrowsErrorContaining("Expected global-state.json to be a file") {
            _ = try await makePort().captureCurrent()
        }
    }

    func testCaptureReadsFromBothFiles() async throws {
        try writeConfigToml("""
        model = "gpt-5.5"
        model_reasoning_effort = "xhigh"
        approval_policy = "on-request"
        approvals_reviewer = "guardian_subagent"
        sandbox_mode = "workspace-write"

        [projects."/x"]
        trust_level = "trusted"
        """)
        try writeGlobalState(
            #"{"electron-persisted-atom-state":{"agent-mode-by-host-id":{"local":"full-access"},"skip-full-access-confirm":true}}"#
        )

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
        try writeConfigToml("model = \"old\"\n")
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
        try writeConfigToml("model = \"queued\"\n")

        releaseQueue()
        didReleaseQueue = true
        let prefs = try await captureTask.value
        XCTAssertEqual(prefs.model, "queued")
    }
}
