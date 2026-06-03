import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class FileSystemManifestRepositoryManifestTests: FileSystemManifestRepositoryTestCase {
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

    func testLoadMigratesLegacySettingsToDefaultRestartOn() async throws {
        let repository = makeRepository()
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        try Data("""
        {
          "accounts": [],
          "activeAccountID": null,
          "settings": {
            "restartCodexAppAfterSwitch": false,
            "launchAtLogin": false,
            "allowNetworkQuotaAPIs": false
          }
        }
        """.utf8).write(to: manifestURL)

        let loaded = try await repository.load()
        let repaired = try readRawManifest()

        XCTAssertTrue(loaded.settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(loaded.settings.defaultsVersion, AppSettings.currentDefaultsVersion)
        XCTAssertTrue(repaired.settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(repaired.settings.defaultsVersion, AppSettings.currentDefaultsVersion)
    }

    func testLoadKeepsCurrentSettingsRestartOff() async throws {
        let repository = makeRepository()
        try writeRawManifest(
            AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(restartCodexAppAfterSwitch: false)
            )
        )

        let loaded = try await repository.load()

        XCTAssertFalse(loaded.settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(loaded.settings.defaultsVersion, AppSettings.currentDefaultsVersion)
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

        await assertFileSystemFailure(contains: "Could not read profiles.json:") {
            _ = try await repository.load()
        }
    }
}
