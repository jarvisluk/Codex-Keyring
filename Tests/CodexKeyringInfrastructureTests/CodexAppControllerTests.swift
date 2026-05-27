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

private final class FakeCodexAppEnvironment: CodexAppEnvironment, @unchecked Sendable {
    private let lock = NSLock()
    private let apps: [FakeRunningCodexApp]
    private let bundleExistsValue: Bool
    private var _launchedURLs: [URL] = []

    init(apps: [FakeRunningCodexApp], bundleExists: Bool) {
        self.apps = apps
        self.bundleExistsValue = bundleExists
    }

    var launchedURLs: [URL] {
        lock.withLock { _launchedURLs }
    }

    func runningCodexApps() -> [RunningCodexApp] {
        apps.filter { !$0.isTerminated }
    }

    func bundleExists(at url: URL) -> Bool {
        bundleExistsValue
    }

    func launchApp(at url: URL) async throws {
        lock.withLock {
            _launchedURLs.append(url)
        }
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock {
            count += 1
        }
    }
}

private final class FakeRunningCodexApp: RunningCodexApp, @unchecked Sendable {
    let processIdentifier: pid_t

    private let lock = NSLock()
    private let terminatesGracefully: Bool
    private let terminatesForcefully: Bool
    private var terminated = false
    private var _terminateCallCount = 0
    private var _forceTerminateCallCount = 0

    init(
        pid: pid_t,
        terminatesGracefully: Bool = true,
        terminatesForcefully: Bool = true
    ) {
        self.processIdentifier = pid
        self.terminatesGracefully = terminatesGracefully
        self.terminatesForcefully = terminatesForcefully
    }

    var isTerminated: Bool {
        lock.withLock { terminated }
    }

    var terminateCallCount: Int {
        lock.withLock { _terminateCallCount }
    }

    var forceTerminateCallCount: Int {
        lock.withLock { _forceTerminateCallCount }
    }

    @discardableResult
    func terminate() -> Bool {
        lock.withLock {
            _terminateCallCount += 1
            if terminatesGracefully {
                terminated = true
            }
            return terminatesGracefully
        }
    }

    @discardableResult
    func forceTerminate() -> Bool {
        lock.withLock {
            _forceTerminateCallCount += 1
            if terminatesForcefully {
                terminated = true
            }
            return terminatesForcefully
        }
    }
}
