import SwiftUI
import CodexKeyringDomain

struct AccountDetailView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showingRemoveConfirmation = false
    @State private var aliasDraft = ""

    var account: CodexAccount

    private var isActive: Bool {
        store.activeAccount?.id == account.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actions
                metadata
                safety
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle(account.displayName)
        .onAppear {
            aliasDraft = account.alias
        }
        .onChange(of: account.id) {
            aliasDraft = account.alias
        }
        .confirmationDialog("Remove saved account?", isPresented: $showingRemoveConfirmation) {
            Button("Remove Snapshot", role: .destructive) {
                store.remove(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved snapshot only. It does not delete the current Codex auth.json.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(account.displayName)
                    .font(.largeTitle.bold())
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.green)
                        .font(.callout.weight(.semibold))
                }
            }

            Text(account.displayEmail)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    store.switchTo(account, restartCodexApp: store.settings.restartCodexAppAfterSwitch)
                } label: {
                    Label(isActive ? "Switch Again" : "Switch", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.switchTo(account, restartCodexApp: true)
                } label: {
                    Label("Switch and Restart Codex App", systemImage: "arrow.clockwise.circle")
                }

                Button(role: .destructive) {
                    showingRemoveConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }

            HStack {
                TextField("Alias", text: $aliasDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Button("Rename") {
                    store.rename(account, to: aliasDraft)
                }
            }
        }
    }

    private var metadata: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            detailRow("Auth mode", account.authMode)
            detailRow("Plan", account.plan)
            detailRow("Account ID", account.accountIdentifier)
            detailRow("Fingerprint", account.shortFingerprint)
            detailRow("Saved", formatDate(account.createdAt))
            detailRow("Updated", formatDate(account.updatedAt))
            if let expiry = account.tokenExpiresAt {
                detailRow("Token expires", formatDate(expiry))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private var safety: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Token-safe by design", systemImage: "lock.shield")
                .font(.headline)
            Text("The app stores auth snapshots locally and only shows metadata such as email, plan, and fingerprint. It does not display access tokens or API keys.")
                .foregroundStyle(.secondary)
            Text("Snapshots live in \(store.storageLocations.accountsDirectoryPath). Backups before switching live in \(store.storageLocations.backupsDirectoryPath).")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
