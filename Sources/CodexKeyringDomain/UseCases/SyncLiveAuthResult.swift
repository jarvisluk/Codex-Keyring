import Foundation

public struct SyncLiveAuthResult: Sendable, Equatable {
    /// Account whose snapshot/metadata was just updated to match the live file.
    public let updatedAccountID: UUID?
    /// True when the live auth fingerprint moved (i.e. snapshot bytes were
    /// rewritten with a fresher refresh-token rotation).
    public let didUpdateSnapshot: Bool
    /// True when the saved manifest metadata was refreshed from the live auth
    /// without necessarily rewriting the snapshot bytes.
    public let didUpdateMetadata: Bool
    /// True when the manifest's `activeAccountID` was reconciled against the
    /// live file (e.g. user switched accounts outside this app).
    public let didReassignActive: Bool

    public init(
        updatedAccountID: UUID?,
        didUpdateSnapshot: Bool,
        didUpdateMetadata: Bool = false,
        didReassignActive: Bool
    ) {
        self.updatedAccountID = updatedAccountID
        self.didUpdateSnapshot = didUpdateSnapshot
        self.didUpdateMetadata = didUpdateMetadata
        self.didReassignActive = didReassignActive
    }

    public static let noop = SyncLiveAuthResult(
        updatedAccountID: nil,
        didUpdateSnapshot: false,
        didUpdateMetadata: false,
        didReassignActive: false
    )
}
