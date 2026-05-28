import Foundation

final class SwitchAccountWarningBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _agentPreferencesWarningReason: String?
    private var _projectArrangementWarningReason: String?
    private var _appliedAgentPreferences = false

    var agentPreferencesWarningReason: String? {
        lock.withLock { _agentPreferencesWarningReason }
    }

    var projectArrangementWarningReason: String? {
        lock.withLock { _projectArrangementWarningReason }
    }

    var appliedAgentPreferences: Bool {
        lock.withLock { _appliedAgentPreferences }
    }

    func recordAgentPreferencesWarning(_ reason: String) {
        lock.withLock {
            if _agentPreferencesWarningReason == nil {
                _agentPreferencesWarningReason = reason
            }
        }
    }

    func recordProjectArrangementWarning(_ reason: String) {
        lock.withLock {
            if _projectArrangementWarningReason == nil {
                _projectArrangementWarningReason = reason
            }
        }
    }

    func recordAppliedAgentPreferences() {
        lock.withLock {
            _appliedAgentPreferences = true
        }
    }
}
