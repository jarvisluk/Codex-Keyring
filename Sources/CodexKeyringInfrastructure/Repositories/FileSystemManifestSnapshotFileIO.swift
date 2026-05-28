import Foundation
import CodexKeyringDomain

struct FileSystemManifestSnapshotFileIO {
    let fileManager: FileManager

    func copyAtomically(from source: URL, to destination: URL) throws {
        try requireSnapshotSourceFile(at: source)
        let temporaryURL = temporaryURL(for: destination)
        do {
            _ = try snapshotExists(at: destination)
            try fileManager.copyItem(at: source, to: temporaryURL)
            try PrivateFilePermissions.setFile(at: temporaryURL, fileManager: fileManager)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destination)
            }
            try PrivateFilePermissions.setFile(at: destination, fileManager: fileManager)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not stage snapshot: \(error.localizedDescription)"
            )
        }
    }

    func removeIfPresent(at url: URL) throws {
        guard try snapshotExists(at: url) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Could not delete snapshot: \(error.localizedDescription)"
            )
        }
    }

    func snapshotExists(at url: URL) throws -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return false }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Snapshot path is not a file: \(url.path)"
            )
        }
        return true
    }

    private func requireSnapshotSourceFile(at url: URL) throws {
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            throw CodexKeyringError.authFileMissing(url)
        }
        guard !isDirectory.boolValue else {
            throw CodexKeyringError.fileSystemFailure(
                reason: "Snapshot source is not a file: \(url.path)"
            )
        }
    }

    private func temporaryURL(for destination: URL) -> URL {
        destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
    }
}
