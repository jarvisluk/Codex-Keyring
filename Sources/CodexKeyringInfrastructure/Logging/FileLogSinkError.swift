import Foundation

public enum FileLogSinkError: LocalizedError, Equatable {
    case exportFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .exportFailed(let reason):
            return "Could not export logs: \(reason)"
        }
    }
}
