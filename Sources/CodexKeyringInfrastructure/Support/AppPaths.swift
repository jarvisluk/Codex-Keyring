import Foundation

enum AppPaths {
    static let appName = "CodexKeyring"

    static var codexDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    static var codexAuthFile: URL {
        codexDirectory.appendingPathComponent("auth.json")
    }

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appName, isDirectory: true)
    }

    static var accountsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Accounts", isDirectory: true)
    }

    static var backupsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    static var manifestFile: URL {
        applicationSupportDirectory.appendingPathComponent("profiles.json")
    }

    static func ensureDirectories() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try manager.createDirectory(at: accountsDirectory, withIntermediateDirectories: true)
        try manager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
    }
}
