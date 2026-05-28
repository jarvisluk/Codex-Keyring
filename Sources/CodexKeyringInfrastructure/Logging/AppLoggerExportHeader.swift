import Foundation

enum AppLoggerExportHeader {
    static func make() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let process = ProcessInfo.processInfo
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
        let os = process.operatingSystemVersionString
        return """
        # Codex Keyring log export
        # Exported: \(formatter.string(from: Date()))
        # App version: \(appVersion) (build \(build))
        # macOS: \(os)
        # Subsystem: \(CodexKeyringLog.subsystem)
        # Note: lines older than this file's retention window are not included.

        """
    }
}
