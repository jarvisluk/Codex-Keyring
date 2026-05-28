import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

class FileSystemManifestRepositoryTestCase: XCTestCase {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileSystemManifestRepositoryTests-\(UUID().uuidString)", isDirectory: true)
    lazy var appDirectory = tempDirectory.appendingPathComponent("ApplicationSupport", isDirectory: true)
    lazy var accountsDirectory = appDirectory.appendingPathComponent("Accounts", isDirectory: true)
    lazy var manifestURL = appDirectory.appendingPathComponent("profiles.json")

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func makeRepository() -> FileSystemManifestRepository {
        FileSystemManifestRepository(
            applicationSupportDirectory: appDirectory,
            accountsDirectory: accountsDirectory,
            manifestURL: manifestURL,
            ioQueue: DispatchQueue(label: "tests.FileSystemManifestRepository.\(UUID().uuidString)")
        )
    }

    func account(alias: String, email: String? = nil) -> CodexAccount {
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

    func writeRawManifest(_ manifest: AccountManifest) throws {
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let data = try Self.manifestEncoder.encode(manifest)
        try data.write(to: manifestURL)
    }

    func readRawManifest() throws -> AccountManifest {
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
