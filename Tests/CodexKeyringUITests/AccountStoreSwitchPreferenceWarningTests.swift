import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreSwitchPreferenceWarningTests: XCTestCase {
    func testSwitchShowsWarningWhenOutgoingAgentPreferencesCannotBeSaved() async throws {
        let fixture = AccountStoreSwitchTestFixture(
            agentPreferencesPort: ThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "permission denied")
            )
        )

        try await fixture.completeInitialRefreshAndSwitch()

        fixture.assertSwitchedToNew(statusContains: [
            "Codex App was restarted",
            "Agent settings could not be fully updated",
            "permission denied"
        ])
    }

    func testSwitchShowsWarningWhenIncomingAgentPreferencesCannotBeApplied() async throws {
        var new = makeAccount(id: UUID(), alias: "new")
        new.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let fixture = AccountStoreSwitchTestFixture(
            new: new,
            agentPreferencesPort: ApplyThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "config denied")
            )
        )

        try await fixture.completeInitialRefreshAndSwitch()

        fixture.assertSwitchedToNew(statusContains: [
            "Codex App was restarted",
            "Agent settings could not be fully updated",
            "config denied"
        ])
    }

    func testSwitchShowsWarningWhenProjectArrangementCannotBePreserved() async throws {
        let fixture = AccountStoreSwitchTestFixture(
            agentPreferencesPort: ProjectArrangementThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "global state denied")
            )
        )

        try await fixture.completeInitialRefreshAndSwitch()

        fixture.assertSwitchedToNew(statusContains: [
            "Codex App was restarted",
            "Codex project list layout could not be preserved",
            "global state denied"
        ])
    }
}
