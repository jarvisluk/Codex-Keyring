import Foundation
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

struct NoopLaunchAtLoginController: LaunchAtLoginControlling {
    var isSupported: Bool { true }
    var isEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

final class RecordingLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    private var values: [Bool] = []

    var isSupported: Bool { true }

    var isEnabled: Bool {
        lock.withLock { enabled }
    }

    var setEnabledValues: [Bool] {
        lock.withLock { values }
    }

    func setEnabled(_ enabled: Bool) throws {
        lock.withLock {
            self.enabled = enabled
            values.append(enabled)
        }
    }
}
