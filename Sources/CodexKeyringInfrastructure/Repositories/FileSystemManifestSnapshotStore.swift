import Foundation
import CodexKeyringDomain

struct FileSystemManifestSnapshotStore {
    let accountsDirectory: URL
    let fileManager: FileManager
    let fileIO: FileSystemManifestSnapshotFileIO

    init(accountsDirectory: URL, fileManager: FileManager = .default) {
        self.accountsDirectory = accountsDirectory
        self.fileManager = fileManager
        self.fileIO = FileSystemManifestSnapshotFileIO(fileManager: fileManager)
    }

    func writeAtomically(from source: URL, for accountID: UUID) throws -> String {
        let snapshotName = FileSystemManifestSnapshotName(accountID: accountID)
        let fileName = snapshotName.fileName
        let destination = snapshotName.url(in: accountsDirectory)
        try fileIO.copyAtomically(from: source, to: destination)
        return fileName
    }

    func delete(named fileName: String) throws {
        guard let url = validURL(named: fileName) else {
            throw CodexKeyringError.fileSystemFailure(reason: "Invalid snapshot file name.")
        }
        try fileIO.removeIfPresent(at: url)
    }

    func url(named fileName: String) -> URL {
        guard let url = validURL(named: fileName) else {
            return accountsDirectory.appendingPathComponent(".invalid-snapshot-name")
        }
        return url
    }

    func exists(named fileName: String) -> Bool {
        guard let url = validURL(named: fileName) else { return false }
        return (try? fileIO.snapshotExists(at: url)) ?? false
    }

    private func validURL(named fileName: String) -> URL? {
        FileSystemManifestSnapshotName(fileName: fileName)?.url(in: accountsDirectory)
    }

}
