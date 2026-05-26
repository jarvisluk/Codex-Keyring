import SwiftUI
import CodexKeyringDomain

struct SidebarView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            Section("Accounts") {
                ForEach(store.accounts) { account in
                    AccountRow(
                        account: account,
                        isActive: store.activeAccount?.id == account.id,
                        quotaState: store.quotaStates[account.id]
                    )
                        .tag(account.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                CurrentAuthFooter()

                StatusFooter()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
    }
}

private struct StatusFooter: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if store.isRefreshInProgress {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            }

            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CurrentAuthFooter: View {
    @EnvironmentObject private var store: AccountStore

    private var statusImage: String {
        if store.currentAuthMetadata == nil {
            return "person.crop.circle.badge.questionmark"
        }
        if store.savedAccountForCurrentAuth != nil {
            return "checkmark.circle.fill"
        }
        return "person.crop.circle.badge.plus"
    }

    private var statusTint: Color {
        store.savedAccountForCurrentAuth == nil ? .secondary : .green
    }

    private var title: String {
        store.currentAuthMetadata?.email ?? "No readable auth.json"
    }

    private var subtitle: String {
        if let savedAccount = store.savedAccountForCurrentAuth {
            return "Saved as \(savedAccount.displayName)"
        }
        if store.currentAuthMetadata != nil {
            return "Not in credentials"
        }
        return store.storageLocations.codexAuthPath
    }

    private var contextMenuTitle: String {
        if store.savedAccountForCurrentAuth != nil {
            return "Already in Credentials"
        }
        return "Add to Credentials"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusImage)
                .foregroundStyle(statusTint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Current Codex Auth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button {
                store.addCurrentAccount(alias: nil)
            } label: {
                Label(contextMenuTitle, systemImage: "plus.circle")
            }
            .disabled(!store.canSaveCurrentAuth)
        }
        .help(store.storageLocations.codexAuthPath)
    }
}

private struct AccountRow: View {
    var account: CodexAccount
    var isActive: Bool
    var quotaState: AccountQuotaState?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                .foregroundStyle(isActive ? .green : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .lineLimit(1)
                Text(account.displayEmail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let quota = quotaState?.sidebarSummary {
                    Label(quota, systemImage: quotaState?.health.systemImage ?? "gauge.medium")
                        .font(.caption2)
                        .foregroundStyle(quotaState?.health.tint ?? .secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
