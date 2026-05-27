import Foundation

enum PrivateDirectoryAccess {
    static let directoryMode = 0o700

    static func ensureExists(at url: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: directoryMode], ofItemAtPath: url.path)
    }
}
