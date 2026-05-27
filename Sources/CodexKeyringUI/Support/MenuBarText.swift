import Foundation

extension String {
    var cappedMenuBarText: String {
        guard count > 30 else { return self }
        return String(prefix(27)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
