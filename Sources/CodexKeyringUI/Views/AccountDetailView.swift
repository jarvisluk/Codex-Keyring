import SwiftUI
import CodexKeyringDomain

struct AccountDetailView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showingRemoveConfirmation = false
    @State private var aliasDraft = ""
    @FocusState private var isAliasFieldFocused: Bool

    var account: CodexAccount

    private var isActive: Bool {
        store.activeAccount?.id == account.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actions
                quota
                metadata
                safety
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle(account.displayName)
        .hidesWindowToolbarTitle()
        .onAppear {
            aliasDraft = account.alias
        }
        .onChange(of: account.id) {
            aliasDraft = account.alias
            isAliasFieldFocused = false
        }
        .onChange(of: account.alias) {
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
                    store.switchTo(account, restartCodexApp: true)
                } label: {
                    Label(isActive ? "Switch Again" : "Switch", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    showingRemoveConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            HStack {
                TextField("Alias", text: $aliasDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isAliasFieldFocused)
                    .onSubmit {
                        submitAliasRename()
                    }
                    .frame(maxWidth: 280)
                Button("Rename") {
                    submitAliasRename()
                }
            }
        }
    }

    private func submitAliasRename() {
        isAliasFieldFocused = false
        store.rename(account, to: aliasDraft)
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

    private var quota: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Quota", systemImage: "gauge.medium")
                    .font(.headline)
                Spacer()
                Button {
                    store.refreshQuotasNow()
                } label: {
                    Label("Refresh Quotas", systemImage: "arrow.clockwise")
                }
                .disabled(!store.settings.allowNetworkQuotaAPIs || store.isQuotaRefreshInProgress)
            }

            if !store.settings.allowNetworkQuotaAPIs {
                Text("Network quota API calls are disabled in Settings.")
                    .foregroundStyle(.secondary)
            } else if let state = store.quotaStates[account.id] {
                quotaStateContent(state)
            } else {
                Text("Quota has not been refreshed yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func quotaStateContent(_ state: AccountQuotaState) -> some View {
        switch state.phase {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing quota...")
                    .foregroundStyle(.secondary)
            }
        case .unsupported, .error:
            Label(state.message ?? state.health.label, systemImage: state.health.systemImage)
                .foregroundStyle(state.health.tint)
        case .available, .idle:
            if let snapshot = state.snapshot {
                quotaSnapshot(snapshot)
            } else {
                Text(state.message ?? "Quota unavailable.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func quotaSnapshot(_ snapshot: AccountQuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let primary = snapshot.primaryBucket {
                quotaBucket(primary, prominent: true)
            }

            let additional = snapshot.buckets.filter { $0.id != snapshot.primaryBucket?.id }
            if !additional.isEmpty {
                Divider()
                ForEach(additional) { bucket in
                    quotaBucket(bucket, prominent: false)
                }
            }

            Text("Last checked \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func quotaBucket(_ bucket: QuotaBucket, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(bucket.displayName, systemImage: bucket.health.systemImage)
                    .foregroundStyle(bucket.health.tint)
                    .font(prominent ? .headline : .subheadline.weight(.semibold))
                Spacer()
                Text(bucket.health.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(bucket.health.tint)
            }

            if let planType = bucket.planType, !planType.isEmpty {
                Text("Plan: \(planType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(bucket.windows.enumerated()), id: \.offset) { _, window in
                quotaWindow(window)
            }

            if bucket.isUnlimited {
                Label("Quota: unlimited", systemImage: "infinity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let credits = bucket.credits {
                quotaCredits(credits)
            }
        }
    }

    private func quotaWindow(_ window: QuotaWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(window.durationLabel)
                Spacer()
                Text("\(window.formattedRemaining) left")
                    .foregroundStyle(window.remainingPercent <= 15 ? .orange : .secondary)
            }
            .font(.caption)

            ProgressView(value: window.remainingPercent, total: 100)
                .tint(window.remainingPercent <= 5 ? .red : window.remainingPercent <= 15 ? .orange : .green)

            Text(window.formattedReset)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func quotaCredits(_ credits: QuotaCredits) -> some View {
        if credits.hasCredits {
            let label = credits.unlimited
                ? "Credits: unlimited"
                : "Credits: \(credits.balance ?? "unknown")"
            Label(label, systemImage: credits.isDepleted ? "creditcard.trianglebadge.exclamationmark" : "creditcard")
                .font(.caption)
                .foregroundStyle(credits.isDepleted ? .red : .secondary)
        }
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

private extension View {
    @ViewBuilder
    func hidesWindowToolbarTitle() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}
