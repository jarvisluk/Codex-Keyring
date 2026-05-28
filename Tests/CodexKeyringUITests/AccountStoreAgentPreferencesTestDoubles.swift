import Foundation
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

struct ThrowingAgentPreferencesPort: CodexAgentPreferencesPorting {
    let error: Error

    func captureCurrent() async throws -> AccountAgentPreferences {
        throw error
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {}
}

struct ApplyThrowingAgentPreferencesPort: CodexAgentPreferencesPorting {
    let error: Error

    func captureCurrent() async throws -> AccountAgentPreferences {
        AccountAgentPreferences()
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {
        throw error
    }
}

struct ProjectArrangementThrowingAgentPreferencesPort: CodexAgentPreferencesPorting {
    let error: Error

    func captureCurrent() async throws -> AccountAgentPreferences {
        AccountAgentPreferences()
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {}

    func captureProjectArrangement() async throws -> CodexProjectArrangement {
        throw error
    }
}
