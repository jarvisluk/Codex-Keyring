public protocol CodexKeyringOperationLocking: Sendable {
    func withLock<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T
}

public struct NoopCodexKeyringOperationLock: CodexKeyringOperationLocking {
    public init() {}

    public func withLock<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await operation()
    }
}
