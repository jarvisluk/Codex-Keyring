import Foundation

struct FileSystemManifestSnapshotName {
    static let suffix = ".auth.json"

    let fileName: String

    init(accountID: UUID) {
        self.fileName = "\(accountID.uuidString)\(Self.suffix)"
    }

    init?(fileName: String) {
        guard fileName.hasSuffix(Self.suffix) else { return nil }
        guard fileName == (fileName as NSString).lastPathComponent else { return nil }
        let idPart = String(fileName.dropLast(Self.suffix.count))
        guard UUID(uuidString: idPart) != nil else { return nil }
        self.fileName = fileName
    }

    func url(in accountsDirectory: URL) -> URL {
        accountsDirectory.appendingPathComponent(fileName)
    }
}
