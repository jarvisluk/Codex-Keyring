import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCasePreferenceSyncTests: XCTestCase {
    func testSwitchAccountCapturesOutgoingAndAppliesIncomingPreferencesWhenEnabled() async throws {
        let incomingPreferences = AccountAgentPreferences(
            model: "gpt-5.5",
            modelReasoningEffort: "xhigh",
            approvalPolicy: "never",
            approvalsReviewer: "guardian_subagent",
            sandboxMode: "workspace-write",
            agentMode: "full-access",
            skipFullAccessConfirm: true
        )
        let scenario = makeSwitchPreferenceScenario(incomingPreferences: incomingPreferences)
        let appController = MockAppController(outcome: .relaunched)
        let outgoingCaptured = AccountAgentPreferences(
            model: "gpt-5",
            modelReasoningEffort: "medium",
            agentMode: "auto-review"
        )
        let port = MockAgentPreferencesPort(captureValues: [outgoingCaptured])

        let result = try await switchAccountUseCase(
            repository: scenario.repository,
            installer: scenario.installer,
            registry: scenario.registry,
            appController: appController,
            preferencesPort: port
        )(accountID: scenario.newAccount.id, restartCodexApp: true)

        let saved = try await scenario.repository.load()
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertEqual(port.applied.count, 1)
        XCTAssertEqual(port.applied.first?.model, "gpt-5.5")
        XCTAssertEqual(port.applied.first?.agentMode, "full-access")
        XCTAssertEqual(port.applied.first?.skipFullAccessConfirm, true)
        XCTAssertEqual(
            saved.accounts.first(where: { $0.id == scenario.oldAccount.id })?.agentPreferences?.model,
            "gpt-5"
        )
        XCTAssertEqual(
            saved.accounts.first(where: { $0.id == scenario.oldAccount.id })?.agentPreferences?.agentMode,
            "auto-review"
        )
        XCTAssertTrue(result.appliedAgentPreferences)
        XCTAssertNil(result.agentPreferencesWarningReason)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertTrue(appController.lastBeforeRelaunchRan)
    }

    func testSwitchAccountWarnsWhenOutgoingAgentPreferenceCaptureFails() async throws {
        let scenario = makeSwitchPreferenceScenario()
        let port = MockAgentPreferencesPort(
            captureError: CodexKeyringError.fileSystemFailure(reason: "permission denied")
        )

        let result = try await switchAccountUseCase(
            repository: scenario.repository,
            installer: scenario.installer,
            registry: scenario.registry,
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: scenario.newAccount.id, restartCodexApp: true)

        let saved = try await scenario.repository.load()
        XCTAssertEqual(saved.activeAccountID, scenario.newAccount.id)
        XCTAssertNil(saved.accounts.first(where: { $0.id == scenario.oldAccount.id })?.agentPreferences)
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertEqual(port.applied.first?.model, "gpt-5.5")
        XCTAssertTrue(result.appliedAgentPreferences)
        XCTAssertTrue(result.agentPreferencesWarningReason?.contains("permission denied") == true)
    }

    func testSwitchAccountRelaunchesAndWarnsWhenIncomingPreferenceApplyFails() async throws {
        let scenario = makeSwitchPreferenceScenario()
        let appController = MockAppController(outcome: .relaunched)
        let port = MockAgentPreferencesPort(
            applyError: CodexKeyringError.fileSystemFailure(reason: "config denied")
        )

        let result = try await switchAccountUseCase(
            repository: scenario.repository,
            installer: scenario.installer,
            registry: scenario.registry,
            appController: appController,
            preferencesPort: port
        )(accountID: scenario.newAccount.id, restartCodexApp: true)

        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertNil(result.restartFailureReason)
        XCTAssertFalse(result.appliedAgentPreferences)
        XCTAssertEqual(port.applyCallCount, 1)
        XCTAssertTrue(port.applied.isEmpty)
        XCTAssertTrue(result.agentPreferencesWarningReason?.contains("config denied") == true)
        XCTAssertEqual(appController.restartCallCount, 1)
        XCTAssertTrue(appController.lastBeforeRelaunchRan)
    }
}
