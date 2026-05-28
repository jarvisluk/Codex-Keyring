enum AccountLiveAuthSyncDecision: Equatable {
    case start
    case coalesce
}

struct AccountLiveAuthSyncCoalescer {
    private var isSyncScheduled = false
    private var needsFollowUp = false

    mutating func requestSync() -> AccountLiveAuthSyncDecision {
        guard !isSyncScheduled else {
            needsFollowUp = true
            return .coalesce
        }

        isSyncScheduled = true
        return .start
    }

    mutating func finishSync() -> Bool {
        isSyncScheduled = false
        if needsFollowUp {
            needsFollowUp = false
            return true
        }
        return false
    }
}
