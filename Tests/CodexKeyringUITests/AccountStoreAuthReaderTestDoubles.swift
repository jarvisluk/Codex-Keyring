import Foundation
@testable import CodexKeyringDomain

struct MissingAuthReader: AuthFileReading {
    func read(from url: URL) async throws -> AuthMetadata {
        throw CodexKeyringError.authFileMissing(url)
    }
}

struct StaticAuthReader: AuthFileReading {
    var metadata: AuthMetadata

    func read(from url: URL) async throws -> AuthMetadata {
        metadata
    }
}

struct MappedAuthReader: AuthFileReading {
    var metadataByURL: [URL: AuthMetadata]

    init(_ metadataByURL: [URL: AuthMetadata]) {
        self.metadataByURL = metadataByURL
    }

    func read(from url: URL) async throws -> AuthMetadata {
        guard let metadata = metadataByURL[url] else {
            throw CodexKeyringError.authFileMissing(url)
        }
        return metadata
    }
}
