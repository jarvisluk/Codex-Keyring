import Foundation
@testable import CodexKeyringDomain

final class MockAuthReader: AuthFileReading, @unchecked Sendable {
    private let registry: AuthFileRegistry

    init(registry: AuthFileRegistry) {
        self.registry = registry
    }

    func read(from url: URL) async throws -> AuthMetadata {
        guard let metadata = registry.metadata(for: url) else {
            throw CodexKeyringError.authFileMissing(url)
        }
        return metadata
    }
}

struct ThrowingAuthReader: AuthFileReading {
    let error: CodexKeyringError

    func read(from url: URL) async throws -> AuthMetadata {
        throw error
    }
}

final class URLFailingAuthReader: AuthFileReading, @unchecked Sendable {
    private let registry: AuthFileRegistry
    private let failingURL: URL
    private let error: CodexKeyringError

    init(registry: AuthFileRegistry, failingURL: URL, error: CodexKeyringError) {
        self.registry = registry
        self.failingURL = failingURL
        self.error = error
    }

    func read(from url: URL) async throws -> AuthMetadata {
        if url == failingURL {
            throw error
        }
        guard let metadata = registry.metadata(for: url) else {
            throw CodexKeyringError.authFileMissing(url)
        }
        return metadata
    }
}
