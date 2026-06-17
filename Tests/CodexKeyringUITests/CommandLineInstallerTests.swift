import XCTest
@testable import CodexKeyringUI

final class CommandLineInstallerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommandLineInstallerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testInstallCopiesExecutableCommand() throws {
        let source = try executableFixture(contents: "new-cli")
        let destination = temporaryDirectory
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("ckr")

        let result = try CommandLineInstaller.install(
            sourceURL: source,
            destinationURL: destination
        )

        XCTAssertEqual(result.destinationPath, destination.path)
        XCTAssertEqual(try String(contentsOf: destination), "new-cli")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: destination.path))
    }

    func testInstallReplacesExistingCommand() throws {
        let source = try executableFixture(contents: "replacement-cli")
        let destinationDirectory = temporaryDirectory.appendingPathComponent("bin", isDirectory: true)
        let destination = destinationDirectory.appendingPathComponent("ckr")
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try "old-cli".write(to: destination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: destination.path
        )

        _ = try CommandLineInstaller.install(
            sourceURL: source,
            destinationURL: destination
        )

        XCTAssertEqual(try String(contentsOf: destination), "replacement-cli")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: destination.path))
    }

    func testInstallRejectsNonExecutableSource() throws {
        let source = temporaryDirectory.appendingPathComponent("ckr-source")
        try "not-executable".write(to: source, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try CommandLineInstaller.install(
                sourceURL: source,
                destinationURL: temporaryDirectory.appendingPathComponent("ckr")
            )
        )
    }

    func testUninstallRemovesExistingCommand() throws {
        let destination = try executableFixture(contents: "installed-cli")

        let result = try CommandLineInstaller.uninstall(destinationURL: destination)

        XCTAssertEqual(result.destinationPath, destination.path)
        XCTAssertTrue(result.didRemove)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testUninstallIsNoopWhenCommandIsMissing() throws {
        let destination = temporaryDirectory.appendingPathComponent("missing-ckr")

        let result = try CommandLineInstaller.uninstall(destinationURL: destination)

        XCTAssertEqual(result.destinationPath, destination.path)
        XCTAssertFalse(result.didRemove)
    }

    private func executableFixture(contents: String) throws -> URL {
        let source = temporaryDirectory.appendingPathComponent("ckr-source-\(UUID().uuidString)")
        try contents.write(to: source, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: source.path
        )
        return source
    }
}
