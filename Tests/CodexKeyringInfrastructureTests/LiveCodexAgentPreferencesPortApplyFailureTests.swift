import XCTest
import CodexKeyringDomain

final class LiveCodexAgentPreferencesPortApplyFailureTests: LiveCodexAgentPreferencesPortTestCase {
    func testApplyThrowsWhenConfigPathIsDirectory() async throws {
        try createConfigPathDirectory()

        await assertThrowsErrorContaining("Expected config.toml to be a file") {
            try await makePort().apply(AccountAgentPreferences(model: "gpt-5.5"))
        }
    }

    func testApplyThrowsWhenStatePathIsDirectory() async throws {
        try createGlobalStatePathDirectory()

        await assertThrowsErrorContaining("Expected global-state.json to be a file") {
            try await makePort().apply(AccountAgentPreferences(agentMode: "full-access"))
        }
    }

    func testApplyRefusesToOverwriteNonObjectGlobalStateParent() async throws {
        let originalState = #"{"electron-persisted-atom-state":"legacy-value"}"#
        try writeGlobalState(originalState)

        await assertThrowsErrorContaining("Expected JSON object at electron-persisted-atom-state") {
            try await makePort().apply(AccountAgentPreferences(agentMode: "full-access"))
        }

        XCTAssertEqual(try String(contentsOf: globalStateURL, encoding: .utf8), originalState)
    }

    func testApplyDoesNotPartiallyWriteTomlWhenGlobalStateIsInvalid() async throws {
        let originalToml = "model = \"gpt-5\"\n"
        let originalState = #"{"electron-persisted-atom-state":"legacy-value"}"#
        try writeConfigToml(originalToml)
        try writeGlobalState(originalState)

        await assertThrowsErrorContaining("Expected JSON object at electron-persisted-atom-state") {
            try await makePort().apply(AccountAgentPreferences(
                model: "gpt-5.5",
                agentMode: "full-access"
            ))
        }

        XCTAssertEqual(try readConfigToml(), originalToml)
        XCTAssertEqual(try String(contentsOf: globalStateURL, encoding: .utf8), originalState)
    }
}
