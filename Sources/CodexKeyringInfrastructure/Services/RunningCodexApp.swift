import AppKit

/// Abstraction over a running app instance so we can substitute
/// `NSRunningApplication` (which has no public initializer) in unit tests.
public protocol RunningCodexApp: Sendable {
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    @discardableResult func terminate() -> Bool
    @discardableResult func forceTerminate() -> Bool
}

extension NSRunningApplication: RunningCodexApp {}
