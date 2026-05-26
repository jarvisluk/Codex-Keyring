import Foundation

public protocol CodexLoginServicing: Sendable {
    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws
}
