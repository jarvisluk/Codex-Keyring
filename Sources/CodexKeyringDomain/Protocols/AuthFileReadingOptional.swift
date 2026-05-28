import Foundation

extension AuthFileReading {
    func readIfPresent(from url: URL) async throws -> AuthMetadata? {
        do {
            return try await read(from: url)
        } catch CodexKeyringError.authFileMissing {
            return nil
        }
    }
}
