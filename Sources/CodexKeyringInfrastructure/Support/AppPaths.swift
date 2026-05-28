import Foundation

public enum AppPaths {
    public static let appName = "CodexKeyring"

    public static var codexDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    public static var codexAuthFile: URL {
        codexDirectory.appendingPathComponent("auth.json")
    }

    public static var codexConfigTomlFile: URL {
        codexDirectory.appendingPathComponent("config.toml")
    }

    public static var codexGlobalStateFile: URL {
        codexDirectory.appendingPathComponent(".codex-global-state.json")
    }

    public static var applicationSupportDirectory: URL {
        applicationSupportDirectory(
            candidates: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask),
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    public static var accountsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Accounts", isDirectory: true)
    }

    public static var loginStagingDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("LoginStaging", isDirectory: true)
    }

    public static var backupsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    public static var manifestFile: URL {
        applicationSupportDirectory.appendingPathComponent("profiles.json")
    }

    public static var logsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    public static let logFileName = "codex-keyring.log"

    public static var currentLogFile: URL {
        logsDirectory.appendingPathComponent(logFileName)
    }
}
