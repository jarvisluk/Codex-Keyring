import XCTest
@testable import CodexKeyringDomain

final class AddAccountUseCasePreferenceCaptureTests: XCTestCase {
    func testAddCurrentAccountCapturesAgentPreferencesWhenEnabled() async throws {
        let live = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = accountRepository(
            settings: AppSettings(preserveAgentPreferencesPerAccount: true)
        )
        let port = MockAgentPreferencesPort(
            captureValues: [AccountAgentPreferences(model: "gpt-5", agentMode: "full-access")]
        )

        let result = try await addAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            preferencesPort: port,
            clock: FixedClock(Date(timeIntervalSince1970: 500))
        )(
            sourceURL: liveURL,
            requestedAlias: "new",
            activate: true
        )

        let saved = try await repository.load()
        let account = try XCTUnwrap(saved.accounts.first)
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertEqual(account.agentPreferences?.model, "gpt-5")
        XCTAssertEqual(account.agentPreferences?.agentMode, "full-access")
        XCTAssertNil(result.agentPreferencesWarningReason)
    }

    func testAddCurrentAccountDoesNotCaptureAgentPreferencesWhenDisabled() async throws {
        let live = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = accountRepository(
            settings: AppSettings(preserveAgentPreferencesPerAccount: false)
        )
        let port = MockAgentPreferencesPort(
            captureValues: [AccountAgentPreferences(model: "gpt-5")]
        )

        let result = try await addAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            preferencesPort: port
        )(
            sourceURL: liveURL,
            requestedAlias: "new",
            activate: true
        )

        let saved = try await repository.load()
        let account = try XCTUnwrap(saved.accounts.first)
        XCTAssertEqual(port.captureCallCount, 0)
        XCTAssertNil(account.agentPreferences)
        XCTAssertNil(result.agentPreferencesWarningReason)
    }

    func testAddCurrentAccountWarnsWhenAgentPreferenceCaptureFails() async throws {
        let live = metadata(email: "new@example.com", fingerprint: "new")
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = accountRepository(
            settings: AppSettings(preserveAgentPreferencesPerAccount: true)
        )
        let port = MockAgentPreferencesPort(
            captureError: CodexKeyringError.fileSystemFailure(reason: "permission denied")
        )

        let result = try await addAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            preferencesPort: port
        )(
            sourceURL: liveURL,
            requestedAlias: "new",
            activate: true
        )

        let saved = try await repository.load()
        let account = try XCTUnwrap(saved.accounts.first)
        XCTAssertEqual(saved.activeAccountID, account.id)
        XCTAssertEqual(port.captureCallCount, 1)
        XCTAssertNil(account.agentPreferences)
        XCTAssertTrue(result.agentPreferencesWarningReason?.contains("permission denied") == true)
    }
}
