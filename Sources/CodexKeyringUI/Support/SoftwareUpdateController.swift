import Sparkle
import SwiftUI

@MainActor
public final class SoftwareUpdateController: ObservableObject {
    public let isConfigured: Bool
    @Published public private(set) var isAutomaticCheckEnabled: Bool

    private let updaterController: SPUStandardUpdaterController?

    public init(bundle: Bundle = .main) {
        isConfigured = Self.hasSparkleConfiguration(in: bundle)
        guard isConfigured else {
            updaterController = nil
            isAutomaticCheckEnabled = false
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        isAutomaticCheckEnabled = controller.updater.automaticallyChecksForUpdates
    }

    public var canCheckForUpdates: Bool {
        isConfigured && (updaterController?.updater.canCheckForUpdates ?? false)
    }

    public func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updaterController?.checkForUpdates(nil)
    }

    public func setAutomaticCheckEnabled(_ enabled: Bool) {
        guard let updater = updaterController?.updater else {
            isAutomaticCheckEnabled = false
            return
        }

        if updater.automaticallyChecksForUpdates != enabled {
            updater.automaticallyChecksForUpdates = enabled
        }
        isAutomaticCheckEnabled = updater.automaticallyChecksForUpdates
    }

    private static func hasSparkleConfiguration(in bundle: Bundle) -> Bool {
        let requiredKeys = ["SUFeedURL", "SUPublicEDKey"]
        return requiredKeys.allSatisfy { key in
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
                return false
            }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
