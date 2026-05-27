import Foundation

enum PrivateFilePermissions {
    static let fileMode = 0o600
    static let directoryMode = 0o700

    static func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool = true,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates
        )
        try setDirectory(at: url, fileManager: fileManager)
    }

    static func setFile(at url: URL, fileManager: FileManager = .default) throws {
        try fileManager.setAttributes([.posixPermissions: fileMode], ofItemAtPath: url.path)
    }

    static func setDirectory(at url: URL, fileManager: FileManager = .default) throws {
        try fileManager.setAttributes([.posixPermissions: directoryMode], ofItemAtPath: url.path)
    }
}
