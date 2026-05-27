import AppKit
import SwiftUI
import CodexKeyringDomain

public struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: AccountStore

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

            Button("Add Current Login") {
                store.addCurrentAccount(alias: nil)
            }
            .disabled(!store.canSaveCurrentAuth)

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
                        store.switchTo(account, restartCodexApp: true)
                    } label: {
                        Label {
                            Text(menuTitle(for: account))
                        } icon: {
                            Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                                .foregroundStyle(isActive ? .green : .secondary)
                        }
                    }

                    if let quotaState = store.quotaStates[account.id],
                       let quotaLine = quotaState.menuDetailSummary {
                        Button {} label: {
                            Text(quotaLine)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(quotaState.health.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            SettingsLink {
                Text("Settings")
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }

    private func menuTitle(for account: CodexAccount) -> String {
        let title = account.alias.isEmpty ? account.displayEmail : account.alias
        return title.count > 30 ? String(title.prefix(27)) + "..." : title
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
