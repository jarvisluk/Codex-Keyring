import AppKit
import SwiftUI
import CodexKeyringDomain

public struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AccountStore
    @EnvironmentObject private var settingsPresentation: SettingsPresentationStore

    public init() {}

    public var body: some View {
        VStack {
            if store.activeAccount == nil {
                Label("No active saved account", systemImage: "person.crop.circle.badge.questionmark")
                Divider()
            }

            Button("Open Manager") {
                openManagerWindow()
            }

            Divider()

            Button("Add New Login") {
                store.loginNewCodexAccount()
            }
            .disabled(!store.canLoginNewAccount)

            Button("Add Current Login") {
                store.addCurrentAccount(alias: nil)
            }
            .disabled(!store.canAddCurrentLogin)

            Button("Import Auth Snapshot...") {
                AuthImportPanel.chooseAndImport(using: store)
            }
            .disabled(!store.canImportAccount)

            Divider()

            Button("Refresh") {
                store.refresh()
            }
            .disabled(!store.canRefreshAccounts)

            Button("Refresh Quotas") {
                store.refreshQuotasNow()
            }
            .disabled(!store.canRefreshQuotas)

            if !store.accounts.isEmpty {
                Divider()
                ForEach(store.accounts) { account in
                    let isActive = store.activeAccount?.id == account.id
                    Button {
                        guard !isActive else { return }
                        store.switchTo(
                            account,
                            restartCodexApp: store.settings.restartCodexAppAfterSwitch
                        )
                    } label: {
                        Label {
                            Text(MenuBarAccountPresentation(account: account).title)
                        } icon: {
                            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isActive ? .green : .secondary)
                        }
                    }
                    .disabled(!store.canSwitch(to: account))

                    if let quotaState = store.quotaStates[account.id],
                       let quotaLine = quotaState.menuDetailSummary {
                        Text(quotaLine)
                            .font(.caption)
                            .foregroundStyle(quotaState.health.tint)
                    }
                }
            }

            if let status = MenuBarStatusPresentation.make(
                statusMessage: store.statusMessage,
                lastError: store.lastError,
                isBusy: store.isStatusBusy
            ) {
                Divider()
                Label {
                    Text(status.title)
                } icon: {
                    Image(systemName: status.systemImage)
                        .foregroundStyle(status.tint)
                }
                .help(status.help)

                if status.isError {
                    Button("Clear Error") {
                        store.clearError()
                    }
                }
            }

            Divider()

            Button("Settings") {
                openManagerWindow()
                settingsPresentation.present()
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }

    private func openManagerWindow() {
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            if existing.isMiniaturized {
                existing.deminiaturize(nil)
            }
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MenuBarAccountPresentation: Equatable {
    let title: String

    init(account: CodexAccount) {
        title = account.displayName.cappedMenuBarText
    }
}

struct MenuBarStatusPresentation {
    let title: String
    let help: String
    let systemImage: String
    let tint: Color
    let isError: Bool

    static func make(
        statusMessage: String,
        lastError: String?,
        isBusy: Bool
    ) -> MenuBarStatusPresentation? {
        if let lastError {
            return MenuBarStatusPresentation(
                title: lastError.cappedMenuBarText,
                help: lastError,
                systemImage: "exclamationmark.triangle.fill",
                tint: .red,
                isError: true
            )
        }

        let trimmedStatus = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isBusy || !trimmedStatus.isEmpty && trimmedStatus != "Ready." else {
            return nil
        }
        return MenuBarStatusPresentation(
            title: trimmedStatus.cappedMenuBarText,
            help: trimmedStatus,
            systemImage: isBusy ? "hourglass" : "checkmark.circle",
            tint: isBusy ? .secondary : .green,
            isError: false
        )
    }
}
