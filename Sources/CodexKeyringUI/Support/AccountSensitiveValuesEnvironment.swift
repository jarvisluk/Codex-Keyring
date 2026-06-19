import SwiftUI

private struct AccountSensitiveValuesVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var accountSensitiveValuesVisible: Bool {
        get { self[AccountSensitiveValuesVisibleKey.self] }
        set { self[AccountSensitiveValuesVisibleKey.self] = newValue }
    }
}
