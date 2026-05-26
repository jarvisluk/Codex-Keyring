import Foundation

/// Observes external changes to the user's `~/.codex/auth.json` so the app
/// can react when Codex App rotates the OAuth refresh token in the
/// background.
///
/// The handler is invoked at most once per coalesced batch of file events
/// (typical implementations debounce raw FS events). Implementations must
/// tolerate the file briefly disappearing during atomic replace writes.
public protocol LiveAuthWatching: AnyObject, Sendable {
    /// Begin observing the watched URL. Subsequent calls are no-ops as long
    /// as the watcher is already running.
    func start(onChange handler: @escaping @Sendable () -> Void)

    /// Stop observing and release the underlying file handle.
    func stop()
}

/// Stub implementation that satisfies the protocol but never fires. Useful
/// in tests / previews where filesystem observation is undesirable.
public final class NoopLiveAuthWatcher: LiveAuthWatching, @unchecked Sendable {
    public init() {}
    public func start(onChange handler: @escaping @Sendable () -> Void) {}
    public func stop() {}
}
