import CodexKeyringDomain

extension AccountStore {
    func startLiveAuthWatcher() {
        liveAuthWatcher.start { [weak self] in
            Task { @MainActor in
                self?.handleLiveAuthChange()
            }
        }
    }

    func handleLiveAuthChange() {
        guard liveAuthSyncCoalescer.requestSync() == .start else {
            logService?.debug("live auth file changed while sync is pending; coalescing follow-up")
            return
        }

        logService?.debug("live auth file changed; syncing active snapshot")
        run(clearErrorOnStart: false) {
            defer {
                if self.liveAuthSyncCoalescer.finishSync() {
                    self.handleLiveAuthChange()
                }
            }
            let result = try await self.useCases.syncLiveAuth()
            if result.didUpdateSnapshot || result.didUpdateMetadata || result.didReassignActive {
                let state = try await self.useCases.refreshState()
                self.apply(state)
                if result.didUpdateSnapshot {
                    self.logService?.info("captured rotated refresh token into snapshot id=\(result.updatedAccountID?.uuidString ?? "<none>")")
                }
                if result.didUpdateMetadata {
                    self.logService?.info("refreshed live auth metadata for account id=\(result.updatedAccountID?.uuidString ?? "<none>")")
                }
                if result.didReassignActive {
                    self.logService?.info("reconciled active account to id=\(result.updatedAccountID?.uuidString ?? "<none>")")
                }
            }
        }
    }
}
