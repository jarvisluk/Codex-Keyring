import Foundation

extension AppPaths {
    public static func ensureDirectories() throws {
        try PrivateFilePermissions.createDirectory(at: applicationSupportDirectory)
        try PrivateFilePermissions.createDirectory(at: accountsDirectory)
        try PrivateFilePermissions.createDirectory(at: loginStagingDirectory)
        try PrivateFilePermissions.createDirectory(at: backupsDirectory)
        try PrivateFilePermissions.createDirectory(at: logsDirectory)
    }

    static func applicationSupportDirectory(
        candidates: [URL],
        homeDirectory: URL
    ) -> URL {
        applicationSupportBaseDirectory(
            candidates: candidates,
            homeDirectory: homeDirectory
        )
        .appendingPathComponent(appName, isDirectory: true)
    }

    private static func applicationSupportBaseDirectory(
        candidates: [URL],
        homeDirectory: URL
    ) -> URL {
        if let firstCandidate = candidates.first {
            return firstCandidate
        }

        return homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
    }
}
