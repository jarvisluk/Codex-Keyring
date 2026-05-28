extension AccountStore {
    public func clearError() {
        if let lastError, statusMessage == lastError {
            statusMessage = "Ready."
        }
        lastError = nil
    }

    public func reportUserFacingError(_ error: Error) {
        setError(error)
    }
}
