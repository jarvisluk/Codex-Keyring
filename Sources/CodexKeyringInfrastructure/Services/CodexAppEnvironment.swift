import AppKit
import Foundation

/// Provides the I/O primitives used by ``NSWorkspaceCodexAppController``.
/// All members are async to make swapping in deterministic test doubles easy.
public protocol CodexAppEnvironment: Sendable {
    func runningCodexApps() -> [RunningCodexApp]
    func bundleExists(at url: URL) -> Bool
    func launchApp(at url: URL) async throws
}

/// Default ``CodexAppEnvironment`` backed by `NSWorkspace`/`NSRunningApplication`.
public struct NSWorkspaceEnvironment: CodexAppEnvironment {
    public let bundleIdentifier: String?
    public let appURL: URL

    public init(bundleIdentifier: String?, appURL: URL) {
        self.bundleIdentifier = bundleIdentifier
        self.appURL = appURL
    }

    public func runningCodexApps() -> [RunningCodexApp] {
        let apps = NSWorkspace.shared.runningApplications
        if let bundleID = bundleIdentifier {
            let matched = apps.filter { $0.bundleIdentifier == bundleID }
            if !matched.isEmpty { return matched }
        }
        return apps.filter { $0.bundleURL?.lastPathComponent == appURL.lastPathComponent }
    }

    public func bundleExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    @MainActor
    public func launchApp(at url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
