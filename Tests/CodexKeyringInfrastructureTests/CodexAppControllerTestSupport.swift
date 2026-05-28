import Foundation
@testable import CodexKeyringInfrastructure

final class FakeCodexAppEnvironment: CodexAppEnvironment, @unchecked Sendable {
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

final class LockedCounter: @unchecked Sendable {
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

final class FakeRunningCodexApp: RunningCodexApp, @unchecked Sendable {
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
