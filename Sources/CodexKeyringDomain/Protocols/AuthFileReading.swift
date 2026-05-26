import Foundation

public protocol AuthFileReading: Sendable {
    func read(from url: URL) async throws -> AuthMetadata
}
