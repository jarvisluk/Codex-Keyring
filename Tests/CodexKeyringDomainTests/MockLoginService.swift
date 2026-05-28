import Foundation
@testable import CodexKeyringDomain

final class MockLoginService: CodexLoginServicing, @unchecked Sendable {
    private let action: @Sendable (@escaping @Sendable (URL) async throws -> Void) async throws -> Void

    init(action: @escaping @Sendable (@escaping @Sendable (URL) async throws -> Void) async throws -> Void) {
        self.action = action
    }

    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        try await action(openAuthURL)
    }
}
