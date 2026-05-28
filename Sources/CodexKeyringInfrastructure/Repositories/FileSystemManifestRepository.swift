import Foundation
import CodexKeyringDomain

/// `AccountRepository` backed by the local file system under
/// `~/Library/Application Support/CodexKeyring`.
///
/// Blocking IO is performed on a private serial queue so calls from the
/// `@MainActor` store never freeze the UI and manifest mutations do not race
/// each other on disk.
public final class FileSystemManifestRepository: AccountRepository, @unchecked Sendable {
    public let manifestURL: URL
    public let accountsDirectory: URL
    public let applicationSupportDirectory: URL

    let log = CodexKeyringLog.makeAppLogger(.manifest)
    let ioQueue: DispatchQueue
    let snapshotStore: FileSystemManifestSnapshotStore
    var fileManager: FileManager { .default }

    public init(
        applicationSupportDirectory: URL = AppPaths.applicationSupportDirectory,
        accountsDirectory: URL = AppPaths.accountsDirectory,
        manifestURL: URL = AppPaths.manifestFile,
        ioQueue: DispatchQueue = DispatchQueue(label: "com.junrong.CodexKeyring.ManifestRepository")
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.accountsDirectory = accountsDirectory
        self.manifestURL = manifestURL
        self.ioQueue = ioQueue
        self.snapshotStore = FileSystemManifestSnapshotStore(accountsDirectory: accountsDirectory)
    }
}
