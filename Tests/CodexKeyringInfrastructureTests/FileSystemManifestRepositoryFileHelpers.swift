import XCTest

extension FileSystemManifestRepositoryTestCase {
    func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }

    func snapshotFileName(for accountID: UUID) -> String {
        "\(accountID.uuidString).auth.json"
    }

    func writeSnapshotSource(
        named fileName: String = "auth.json",
        contents: String = #"{"tokens":{"access_token":"abc"}}"#
    ) throws -> URL {
        let source = tempDirectory.appendingPathComponent(fileName)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: source)
        return source
    }

    func createSnapshotDirectory(named fileName: String) throws -> URL {
        let url = accountsDirectory.appendingPathComponent(fileName, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func assertDirectoryExists(
        _ url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var isDirectory = ObjCBool(false)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            file: file,
            line: line
        )
        XCTAssertTrue(isDirectory.boolValue, file: file, line: line)
    }
}
