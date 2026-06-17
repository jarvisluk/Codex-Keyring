import XCTest
@testable import CodexKeyringCLI

final class CodexKeyringCLIParserTests: XCTestCase {
    func testParsesSwitchWithNoRestartAndJSON() throws {
        let command = try CodexKeyringCLIParser().parse([
            "switch",
            "work",
            "--no-restart",
            "--json"
        ])

        XCTAssertEqual(
            command,
            .switchAccount(selector: "work", restart: .noRestart, json: true)
        )
    }

    func testRejectsConflictingRestartFlags() throws {
        XCTAssertThrowsError(
            try CodexKeyringCLIParser().parse([
                "switch",
                "work",
                "--restart",
                "--no-restart"
            ])
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Use only one of --restart or --no-restart."
            )
        }
    }

    func testRequiresRemoveConfirmationFlag() throws {
        let command = try CodexKeyringCLIParser().parse(["remove", "work"])

        XCTAssertEqual(command, .remove(selector: "work", confirmed: false, json: false))
    }

    func testParsesSettingsSet() throws {
        let command = try CodexKeyringCLIParser().parse([
            "settings",
            "set",
            "allowNetworkQuotaAPIs",
            "true"
        ])

        XCTAssertEqual(
            command,
            .settingsSet(key: "allowNetworkQuotaAPIs", value: "true", json: false)
        )
    }
}
