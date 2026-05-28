import Foundation

extension ChatGPTOAuthLoginService {
    func persistAuth(tokens: ExchangedTokens) async throws {
        try await performIO {
            try ChatGPTOAuthFileWriter(
                authFileURL: self.authFileURL,
                codexDirectory: self.codexDirectory
            ).write(tokens: tokens)
        }
    }

    func performIO<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
