import Sparkle
import SwiftUI

@MainActor
public final class SoftwareUpdateController: ObservableObject {
    public let isConfigured: Bool
    @Published public private(set) var isAutomaticCheckEnabled: Bool
    @Published public private(set) var isAutomaticDownloadEnabled: Bool
    @Published public private(set) var canAutomaticallyDownloadUpdates: Bool

    private let updaterController: SPUStandardUpdaterController?

    public init(bundle: Bundle = .main) {
        isConfigured = Self.hasSparkleConfiguration(in: bundle)
        guard isConfigured else {
            updaterController = nil
            isAutomaticCheckEnabled = false
            isAutomaticDownloadEnabled = false
            canAutomaticallyDownloadUpdates = false
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
        isAutomaticCheckEnabled = false
        isAutomaticDownloadEnabled = false
        canAutomaticallyDownloadUpdates = false
        refreshAutomaticUpdateState()
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
            isAutomaticDownloadEnabled = false
            canAutomaticallyDownloadUpdates = false
            return
        }

        if updater.automaticallyChecksForUpdates != enabled {
            updater.automaticallyChecksForUpdates = enabled
        }

        if !enabled && updater.automaticallyDownloadsUpdates {
            updater.automaticallyDownloadsUpdates = false
        }
        refreshAutomaticUpdateState()
    }

    public func setAutomaticDownloadEnabled(_ enabled: Bool) {
        guard let updater = updaterController?.updater else {
            isAutomaticDownloadEnabled = false
            canAutomaticallyDownloadUpdates = false
            return
        }

        if enabled && !updater.allowsAutomaticUpdates {
            refreshAutomaticUpdateState()
            return
        }

        if updater.automaticallyDownloadsUpdates != enabled {
            updater.automaticallyDownloadsUpdates = enabled
        }
        refreshAutomaticUpdateState()
    }

    private func refreshAutomaticUpdateState() {
        guard let updater = updaterController?.updater else {
            isAutomaticCheckEnabled = false
            isAutomaticDownloadEnabled = false
            canAutomaticallyDownloadUpdates = false
            return
        }

        isAutomaticCheckEnabled = updater.automaticallyChecksForUpdates
        isAutomaticDownloadEnabled = updater.automaticallyDownloadsUpdates
        canAutomaticallyDownloadUpdates = updater.allowsAutomaticUpdates
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
