import XCTest
@testable import CodexKeyringInfrastructure

class LiveCodexAgentPreferencesPortTestCase: XCTestCase {
    let workDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-keyring-prefs-tests-\(UUID().uuidString)", isDirectory: true)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: workDir.path) {
            try FileManager.default.removeItem(at: workDir)
        }
    }

    var configTomlURL: URL {
        workDir.appendingPathComponent("config.toml")
    }

    var globalStateURL: URL {
        workDir.appendingPathComponent(".codex-global-state.json")
    }

    func makePort(
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.LiveCodexAgentPreferencesPort.\(UUID().uuidString)")
    ) -> LiveCodexAgentPreferencesPort {
        LiveCodexAgentPreferencesPort(
            configTomlURL: configTomlURL,
            globalStateURL: globalStateURL,
            ioQueue: ioQueue
        )
    }

    func makePort(configDir: String, stateDir: String) -> LiveCodexAgentPreferencesPort {
        LiveCodexAgentPreferencesPort(
            configTomlURL: workDir.appendingPathComponent(configDir, isDirectory: true).appendingPathComponent("config.toml"),
            globalStateURL: workDir.appendingPathComponent(stateDir, isDirectory: true).appendingPathComponent(".codex-global-state.json")
        )
    }

    func writeConfigToml(_ content: String) throws {
        try content.write(to: configTomlURL, atomically: true, encoding: .utf8)
    }

    func readConfigToml() throws -> String {
        try String(contentsOf: configTomlURL, encoding: .utf8)
    }

    func writeGlobalState(_ content: String) throws {
        try content.write(to: globalStateURL, atomically: true, encoding: .utf8)
    }

    func parsedGlobalState() throws -> [String: Any] {
        let data = try Data(contentsOf: globalStateURL)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func createConfigPathDirectory() throws {
        try FileManager.default.createDirectory(at: configTomlURL, withIntermediateDirectories: true)
    }

    func createGlobalStatePathDirectory() throws {
        try FileManager.default.createDirectory(at: globalStateURL, withIntermediateDirectories: true)
    }

    func assertThrowsErrorContaining(
        _ expectedText: String,
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected operation to fail.", file: file, line: line)
        } catch {
            XCTAssertTrue(
                error.localizedDescription.contains(expectedText),
                "Expected '\(error.localizedDescription)' to contain '\(expectedText)'",
                file: file,
                line: line
            )
        }
    }

    func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }

    func fileSize(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
        )
        return value.intValue
    }
}
