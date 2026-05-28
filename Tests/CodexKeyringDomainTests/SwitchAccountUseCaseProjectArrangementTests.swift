import XCTest
@testable import CodexKeyringDomain

final class SwitchAccountUseCaseProjectArrangementTests: XCTestCase {
    func testSwitchAccountRestoresProjectArrangementEvenWhenAgentPrefsOff() async throws {
        let arrangement = CodexProjectArrangement(
            projectOrder: ["/before-a", "remote-before"],
            pinnedProjectIDs: ["/before-a"],
            sidebarOrganizeMode: "manual"
        )
        let scenario = makeSwitchProjectArrangementScenario(arrangement: arrangement)

        let result = try await scenario.useCase()(
            accountID: scenario.newAccount.id,
            restartCodexApp: true
        )

        XCTAssertEqual(scenario.port.captureCallCount, 0)
        XCTAssertEqual(scenario.port.applied.count, 0)
        XCTAssertEqual(scenario.port.projectArrangementCaptureCallCount, 1)
        XCTAssertEqual(scenario.port.restoredProjectArrangements, [arrangement])
        XCTAssertFalse(result.appliedAgentPreferences)
    }

    func testSwitchAccountWarnsWhenProjectArrangementCaptureFails() async throws {
        let scenario = makeSwitchProjectArrangementScenario(
            projectArrangementCaptureError: CodexKeyringError.fileSystemFailure(reason: "global state denied")
        )

        let result = try await scenario.useCase()(
            accountID: scenario.newAccount.id,
            restartCodexApp: true
        )

        XCTAssertEqual(result.state.activeAccountID, scenario.newAccount.id)
        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertNil(result.restartFailureReason)
        XCTAssertEqual(scenario.port.projectArrangementCaptureCallCount, 1)
        XCTAssertTrue(scenario.port.restoredProjectArrangements.isEmpty)
        XCTAssertTrue(result.projectArrangementWarningReason?.contains("global state denied") == true)
    }

    func testSwitchAccountRelaunchesAndWarnsWhenProjectArrangementRestoreFails() async throws {
        let arrangement = CodexProjectArrangement(
            projectOrder: ["/before-a"],
            pinnedProjectIDs: ["/before-a"],
            sidebarOrganizeMode: "manual"
        )
        let scenario = makeSwitchProjectArrangementScenario(
            arrangement: arrangement,
            projectArrangementRestoreError: CodexKeyringError.fileSystemFailure(reason: "state denied")
        )

        let result = try await scenario.useCase()(
            accountID: scenario.newAccount.id,
            restartCodexApp: true
        )

        XCTAssertEqual(result.restartOutcome, .relaunched)
        XCTAssertNil(result.restartFailureReason)
        XCTAssertEqual(scenario.port.projectArrangementRestoreCallCount, 1)
        XCTAssertTrue(scenario.port.restoredProjectArrangements.isEmpty)
        XCTAssertTrue(result.projectArrangementWarningReason?.contains("state denied") == true)
        XCTAssertEqual(scenario.appController.restartCallCount, 1)
        XCTAssertTrue(scenario.appController.lastBeforeRelaunchRan)
    }
}
