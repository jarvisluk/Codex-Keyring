import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class CodexAppControllerTests: XCTestCase {
    func testRestartTerminatesRunningAppRunsHookAndRelaunches() async throws {
        let app = FakeRunningCodexApp(pid: 101)
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
        let environment = FakeCodexAppEnvironment(apps: [app], bundleExists: true)
        let controller = NSWorkspaceCodexAppController(
            environment: environment,
            codexAppURL: appURL,
            pollInterval: .milliseconds(1),
            pollAttempts: 3
        )
        let hookCallCount = LockedCounter()

        let outcome = try await controller.restartIfRunning {
            hookCallCount.increment()
        }

        XCTAssertEqual(outcome, .relaunched)
        XCTAssertEqual(app.terminateCallCount, 1)
        XCTAssertEqual(app.forceTerminateCallCount, 0)
        XCTAssertEqual(hookCallCount.value, 1)
        XCTAssertEqual(environment.launchedURLs, [appURL])
    }

    func testRestartRunsHookBeforeReturningBundleMissing() async throws {
        let app = FakeRunningCodexApp(pid: 102)
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
        let environment = FakeCodexAppEnvironment(apps: [app], bundleExists: false)
        let controller = NSWorkspaceCodexAppController(
            environment: environment,
            codexAppURL: appURL,
            pollInterval: .milliseconds(1),
            pollAttempts: 3
        )
        let hookCallCount = LockedCounter()

        let outcome = try await controller.restartIfRunning {
            hookCallCount.increment()
        }

        XCTAssertEqual(outcome, .bundleMissing(path: appURL.path))
        XCTAssertEqual(app.terminateCallCount, 1)
        XCTAssertEqual(hookCallCount.value, 1)
        XCTAssertEqual(environment.launchedURLs, [])
    }

    func testRestartEscalatesToForceTerminateWhenGracefulQuitDoesNotExit() async throws {
        let app = FakeRunningCodexApp(pid: 103, terminatesGracefully: false)
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
        let environment = FakeCodexAppEnvironment(apps: [app], bundleExists: true)
        let controller = NSWorkspaceCodexAppController(
            environment: environment,
            codexAppURL: appURL,
            pollInterval: .milliseconds(1),
            pollAttempts: 2
        )

        let outcome = try await controller.restartIfRunning()

        XCTAssertEqual(outcome, .relaunched)
        XCTAssertEqual(app.terminateCallCount, 1)
        XCTAssertEqual(app.forceTerminateCallCount, 1)
        XCTAssertEqual(environment.launchedURLs, [appURL])
    }

    func testRestartFailsWhenForceTerminateDoesNotExit() async throws {
        let app = FakeRunningCodexApp(
            pid: 104,
            terminatesGracefully: false,
            terminatesForcefully: false
        )
        let appURL = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
        let environment = FakeCodexAppEnvironment(apps: [app], bundleExists: true)
        let controller = NSWorkspaceCodexAppController(
            environment: environment,
            codexAppURL: appURL,
            pollInterval: .milliseconds(1),
            pollAttempts: 1
        )

        do {
            _ = try await controller.restartIfRunning()
            XCTFail("Expected restart to fail when Codex App never exits.")
        } catch CodexKeyringError.codexAppRelaunchFailed(let reason) {
            XCTAssertTrue(reason.contains("104"))
            XCTAssertTrue(reason.contains("did not exit after forceTerminate"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(environment.launchedURLs, [])
    }
}
