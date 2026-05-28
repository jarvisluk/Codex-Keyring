import Foundation
import CodexKeyringDomain

/// Legacy enum-style facade preserved so existing callers keep compiling
/// during the migration to use-case injection.
public enum AuthMetadataParser {
    public static func parseAuthFile(at url: URL) throws -> AuthMetadata {
        try AuthFileParser.parseAuthFile(at: url)
    }
}
