import Foundation
import CodexKeyringDomain

public enum AuthMetadataError: LocalizedError, Equatable {
    case fileMissing
    case unreadableJSON
    case unsupportedAuthShape

    public var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "Codex auth.json was not found."
        case .unreadableJSON:
            return "The selected auth file is not readable JSON."
        case .unsupportedAuthShape:
            return "The file does not look like a Codex auth.json file."
        }
    }

    var asDomainError: CodexKeyringError {
        switch self {
        case .fileMissing:
            return .authFileMissing(URL(fileURLWithPath: "/"))
        case .unreadableJSON:
            return .authFileUnreadable
        case .unsupportedAuthShape:
            return .unsupportedAuthShape
        }
    }
}
