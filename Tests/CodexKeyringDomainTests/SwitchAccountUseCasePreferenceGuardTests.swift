import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCasePreferenceGuardTests: XCTestCase {
    func testSwitchAccountDoesNotTouchPreferencesWhenFeatureOff() async throws {
        let scenario = makeSwitchPreferenceScenario(
            settings: AppSettings(preserveAgentPreferencesPerAccount: false)
        )
        let port = MockAgentPreferencesPort()

        let result = try await switchAccountUseCase(
            repository: scenario.repository,
            installer: scenario.installer,
            registry: scenario.registry,
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: scenario.newAccount.id, restartCodexApp: true)

        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertFalse(result.appliedAgentPreferences)
    }

    func testSwitchAccountDoesNotApplyPreferencesWithoutRestart() async throws {
        let scenario = makeSwitchPreferenceScenario()
        let port = MockAgentPreferencesPort(captureValues: [AccountAgentPreferences(model: "gpt-5")])

        let result = try await switchAccountUseCase(
            repository: scenario.repository,
            installer: scenario.installer,
            registry: scenario.registry,
            appController: MockAppController(outcome: .relaunched),
            preferencesPort: port
        )(accountID: scenario.newAccount.id, restartCodexApp: false)

        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertFalse(result.appliedAgentPreferences)
    }

    func testSwitchAccountDoesNotStartCodexAppWhenNotRunning() async throws {
        let scenario = makeSwitchPreferenceScenario()
        let appController = MockAppController(outcome: .relaunched)
        appController.isRunning = false
        let port = MockAgentPreferencesPort(captureValues: [AccountAgentPreferences(model: "gpt-5")])

        let result = try await switchAccountUseCase(
            repository: scenario.repository,
            installer: scenario.installer,
            registry: scenario.registry,
            appController: appController,
            preferencesPort: port
        )(accountID: scenario.newAccount.id, restartCodexApp: true)

        XCTAssertEqual(result.restartOutcome, .wasNotRunning)
        XCTAssertEqual(appController.restartCallCount, 0)
        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertEqual(port.applied.count, 0)
        XCTAssertFalse(result.appliedAgentPreferences)
        XCTAssertEqual(scenario.registry.metadata(for: scenario.liveURL)?.fingerprint, "new")
    }
}
