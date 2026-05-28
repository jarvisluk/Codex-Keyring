import Foundation

extension CodexGlobalStateEditor {
    public enum EditorError: Error, Equatable, LocalizedError {
        case notAJSONObject
        case parentIsNotJSONObject(path: [String])

        public var errorDescription: String? {
            switch self {
            case .notAJSONObject:
                return "Expected global-state JSON root to be an object."
            case .parentIsNotJSONObject(let path):
                let location = path.joined(separator: ".")
                return "Expected JSON object at \(location) before writing global-state value."
            }
        }
    }
}
