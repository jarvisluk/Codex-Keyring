import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class FileSystemManifestRepositoryTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileSystemManifestRepositoryTests-\(UUID().uuidString)", isDirectory: true)
    private lazy var appDirectory = tempDirectory.appendingPathComponent("ApplicationSupport", isDirectory: true)
    private lazy var accountsDirectory = appDirectory.appendingPathComponent("Accounts", isDirectory: true)
    private lazy var manifestURL = appDirectory.appendingPathComponent("profiles.json")

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testSaveAndLoadRoundTripsManifestAndSortsAccounts() async throws {
        let repository = makeRepository()
        let b = account(alias: "beta")
        let a = account(alias: "alpha")
        let manifest = AccountManifest(
            accounts: [b, a],
            activeAccountID: b.id,
            settings: AppSettings(allowNetworkQuotaAPIs: true)
        )

        try await repository.save(manifest)
        let loaded = try await repository.load()

        XCTAssertEqual(loaded.accounts.map(\.alias), ["alpha", "beta"])
        XCTAssertEqual(loaded.activeAccountID, b.id)
        XCTAssertTrue(loaded.settings.allowNetworkQuotaAPIs)
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
        XCTAssertEqual(try filePermissions(at: manifestURL), 0o600)
        XCTAssertEqual(try filePermissions(at: appDirectory), 0o700)
        XCTAssertEqual(try filePermissions(at: accountsDirectory), 0o700)
    }

    func testSaveAndLoadSortsMatchingAliasesByEmail() async throws {
        let repository = makeRepository()
        let b = account(alias: "team", email: "b@example.com")
        let a = account(alias: "team", email: "a@example.com")
        let manifest = AccountManifest(
            accounts: [b, a],
            activeAccountID: b.id,
            settings: AppSettings()
        )

        try await repository.save(manifest)
        let loaded = try await repository.load()

        XCTAssertEqual(loaded.accounts.map(\.email), ["a@example.com", "b@example.com"])
        XCTAssertEqual(loaded.activeAccountID, b.id)
    }

    func testSaveAndLoadSortsEmptyAliasByDisplayNameFallback() async throws {
        let repository = makeRepository()
        let named = account(alias: "beta", email: "z@example.com")
        let fallback = account(alias: "", email: "alpha@example.com")
        let manifest = AccountManifest(
            accounts: [named, fallback],
            activeAccountID: fallback.id,
            settings: AppSettings()
        )

        try await repository.save(manifest)
        let loaded = try await repository.load()

        XCTAssertEqual(loaded.accounts.map(\.displayName), ["alpha@example.com", "beta"])
        XCTAssertEqual(loaded.activeAccountID, fallback.id)
    }

    func testMissingManifestLoadsEmptyAfterPreparingDirectories() async throws {
        let repository = makeRepository()

        let loaded = try await repository.load()

        XCTAssertTrue(loaded.accounts.isEmpty)
        XCTAssertNil(loaded.activeAccountID)
        XCTAssertEqual(loaded.settings, AppSettings())
        XCTAssertTrue(FileManager.default.fileExists(atPath: appDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: accountsDirectory.path))
        XCTAssertEqual(try filePermissions(at: appDirectory), 0o700)
        XCTAssertEqual(try filePermissions(at: accountsDirectory), 0o700)
    }

    func testLoadRepairsStaleActiveAccountIDAndPersistsRepair() async throws {
        let repository = makeRepository()
        let account = account(alias: "alpha")
        let staleID = UUID()
        try writeRawManifest(
            AccountManifest(
                accounts: [account],
                activeAccountID: staleID,
                settings: AppSettings()
            )
        )

        let loaded = try await repository.load()
        let repaired = try readRawManifest()

        XCTAssertNil(loaded.activeAccountID)
        XCTAssertNil(repaired.activeAccountID)
        XCTAssertEqual(loaded.accounts.map(\.id), [account.id])
    }

    func testUnreadableManifestPathThrowsDomainFileSystemError() async throws {
        let repository = makeRepository()
        try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: true)

        do {
            _ = try await repository.load()
            XCTFail("Expected unreadable manifest path to fail.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(
                reason.hasPrefix("Could not read profiles.json:"),
                "Unexpected reason: \(reason)"
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteSnapshotCopiesAndDeleteSnapshotRemovesAccountFile() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = tempDirectory.appendingPathComponent("auth.json")
        let contents = #"{"tokens":{"access_token":"abc"}}"#
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: source)

        let fileName = try await repository.writeSnapshot(from: source, for: accountID)
        let destination = repository.snapshotURL(named: fileName)

        XCTAssertEqual(fileName, "\(accountID.uuidString).auth.json")
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), contents)
        XCTAssertTrue(repository.snapshotExists(named: fileName))
        XCTAssertEqual(try filePermissions(at: destination), 0o600)

        try await repository.deleteSnapshot(named: fileName)

        XCTAssertFalse(repository.snapshotExists(named: fileName))
    }

    func testWriteSnapshotRejectsMissingSourceFile() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = tempDirectory.appendingPathComponent("missing-auth.json")

        do {
            _ = try await repository.writeSnapshot(from: source, for: accountID)
            XCTFail("Expected missing snapshot source to be rejected.")
        } catch CodexKeyringError.authFileMissing(let url) {
            XCTAssertEqual(url, source)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let fileName = "\(accountID.uuidString).auth.json"
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.snapshotURL(named: fileName).path))
    }

    func testWriteSnapshotRejectsDirectorySourcePath() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = tempDirectory.appendingPathComponent("auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

        do {
            _ = try await repository.writeSnapshot(from: source, for: accountID)
            XCTFail("Expected directory snapshot source to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Snapshot source is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let fileName = "\(accountID.uuidString).auth.json"
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.snapshotURL(named: fileName).path))
    }

    func testSnapshotExistsTreatsDirectoryAtSnapshotPathAsMissing() async throws {
        let repository = makeRepository()
        let fileName = "\(UUID().uuidString).auth.json"
        let snapshotPath = accountsDirectory.appendingPathComponent(fileName, isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        XCTAssertFalse(repository.snapshotExists(named: fileName))
    }

    func testDeleteSnapshotRefusesDirectoryAtSnapshotPath() async throws {
        let repository = makeRepository()
        let fileName = "\(UUID().uuidString).auth.json"
        let snapshotPath = accountsDirectory.appendingPathComponent(fileName, isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        do {
            try await repository.deleteSnapshot(named: fileName)
            XCTFail("Expected directory snapshot path to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Snapshot path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotPath.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testWriteSnapshotRefusesDirectoryAtDestination() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = tempDirectory.appendingPathComponent("auth.json")
        let fileName = "\(accountID.uuidString).auth.json"
        let snapshotPath = accountsDirectory.appendingPathComponent(fileName, isDirectory: true)
        try FileManager.default.createDirectory(at: accountsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)
        try Data(#"{"tokens":{"access_token":"abc"}}"#.utf8).write(to: source)

        do {
            _ = try await repository.writeSnapshot(from: source, for: accountID)
            XCTFail("Expected directory snapshot destination to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Snapshot path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotPath.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testInvalidSnapshotFileNamesCannotEscapeAccountsDirectory() async throws {
        let repository = makeRepository()
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let outside = appDirectory.appendingPathComponent("escape.auth.json")
        try Data("outside".utf8).write(to: outside)

        XCTAssertFalse(repository.snapshotExists(named: "../escape.auth.json"))
        XCTAssertFalse(repository.snapshotExists(named: "/tmp/escape.auth.json"))
        XCTAssertFalse(repository.snapshotExists(named: "nested/escape.auth.json"))
        XCTAssertFalse(repository.snapshotExists(named: "escape.txt"))
        XCTAssertFalse(repository.snapshotExists(named: "not-a-uuid.auth.json"))

        do {
            try await repository.deleteSnapshot(named: "../escape.auth.json")
            XCTFail("Expected invalid snapshot names to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertEqual(reason, "Invalid snapshot file name.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "outside")
    }

    private func makeRepository() -> FileSystemManifestRepository {
        FileSystemManifestRepository(
            applicationSupportDirectory: appDirectory,
            accountsDirectory: accountsDirectory,
            manifestURL: manifestURL,
            ioQueue: DispatchQueue(label: "tests.FileSystemManifestRepository.\(UUID().uuidString)")
        )
    }

    private func account(alias: String, email: String? = nil) -> CodexAccount {
        let id = UUID()
        let email = email ?? "\(alias)@example.com"
        return CodexAccount(
            id: id,
            alias: alias,
            email: email,
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "\(alias)-account",
            snapshotFileName: "\(id.uuidString).auth.json",
            fingerprint: "\(alias)-fingerprint",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
    }

    private func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }

    private func writeRawManifest(_ manifest: AccountManifest) throws {
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let data = try Self.manifestEncoder.encode(manifest)
        try data.write(to: manifestURL)
    }

    private func readRawManifest() throws -> AccountManifest {
        let data = try Data(contentsOf: manifestURL)
        return try Self.manifestDecoder.decode(AccountManifest.self, from: data)
    }

    private static let manifestEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let manifestDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
