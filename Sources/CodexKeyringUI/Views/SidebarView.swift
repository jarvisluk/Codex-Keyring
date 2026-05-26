import SwiftUI
import CodexKeyringDomain
import CodexKeyringInfrastructure

struct SidebarView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            Section("Accounts") {
                ForEach(store.accounts) { account in
                    AccountRow(account: account, isActive: store.activeAccount?.id == account.id)
                        .tag(account.id)
                }
            }

            Section("Current Codex Auth") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentAuthMetadata?.email ?? "No readable auth.json")
                        .lineLimit(1)
                    Text(AppPaths.codexAuthFile.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
    }
}

private struct AccountRow: View {
    var account: CodexAccount
    var isActive: Bool

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
            }
        }
        .padding(.vertical, 3)
    }
}
