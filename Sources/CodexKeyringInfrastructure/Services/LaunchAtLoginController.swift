import Foundation
import ServiceManagement
import CodexKeyringDomain

public struct SMAppServiceLaunchAtLogin: LaunchAtLoginControlling {
    private let log = CodexKeyringLog.makeAppLogger(.launchAtLogin)

    public init() {}

    public var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    public func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw CodexKeyringError.launchAtLoginUnsupported
        }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    log.info("launch-at-login registered")
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                log.info("launch-at-login unregistered")
            }
        } catch {
            log.error("launch-at-login change failed: \(String(describing: error))")
            throw CodexKeyringError.launchAtLoginFailed(reason: error.localizedDescription)
        }
    }
}

/// Legacy facade preserved during migration.
public enum LaunchAtLoginController {
    public static var isSupported: Bool {
        SMAppServiceLaunchAtLogin().isSupported
    }

    public static var isEnabled: Bool {
        SMAppServiceLaunchAtLogin().isEnabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        try SMAppServiceLaunchAtLogin().setEnabled(enabled)
    }
}
