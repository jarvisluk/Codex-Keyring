import Foundation
import os

public enum LoggerCategory: String, Sendable {
    case manifest
    case authParser
    case installer
    case codexApp
    case launchAtLogin
    case store
}

public enum CodexKeyringLog {
    public static let subsystem = "com.junrong.CodexKeyring"

    public static func make(_ category: LoggerCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
