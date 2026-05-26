import Foundation

public protocol LaunchAtLoginControlling: Sendable {
    var isSupported: Bool { get }
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}
