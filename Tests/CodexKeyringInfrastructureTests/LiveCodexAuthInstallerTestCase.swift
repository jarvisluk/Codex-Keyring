import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

class LiveCodexAuthInstallerTestCase: XCTestCase {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LiveCodexAuthInstallerTests-\(UUID().uuidString)", isDirectory: true)
    lazy var codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
    lazy var backupsDirectory = tempDirectory.appendingPathComponent("backups", isDirectory: true)
    lazy var stagingDirectory = tempDirectory.appendingPathComponent("staging", isDirectory: true)
    lazy var liveAuthURL = codexDirectory.appendingPathComponent("auth.json")

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func makeInstaller(
        clock: Clock = SystemClock(),
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.LiveCodexAuthInstaller.\(UUID().uuidString)")
    ) -> LiveCodexAuthInstaller {
        LiveCodexAuthInstaller(
            liveAuthFileURL: liveAuthURL,
            codexDirectory: codexDirectory,
            backupsDirectory: backupsDirectory,
            loginStagingDirectory: stagingDirectory,
            clock: clock,
            ioQueue: ioQueue
        )
    }

    func writeAuthFile(_ url: URL, contents: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }
}
