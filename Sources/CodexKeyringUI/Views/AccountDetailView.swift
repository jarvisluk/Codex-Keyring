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

    private var cleanedAliasDraft: String {
        aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAliasChange: Bool {
        cleanedAliasDraft != account.alias
    }

    private var canSubmitAliasRename: Bool {
        store.canRename(account, to: cleanedAliasDraft)
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
        .navigationTitle("Codex Keyring")
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
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .layoutPriority(1)
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
                .lineLimit(1)
                .truncationMode(.middle)
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
                .help(switchHelpText)
                .disabled(!store.canSwitch(to: account))

                Button(role: .destructive) {
                    showingRemoveConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!store.canRemove(account))
            }

            HStack {
                TextField("Alias", text: $aliasDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isAliasFieldFocused)
                    .onSubmit {
                        submitAliasRename()
                    }
                    .frame(maxWidth: 280)
                Button {
                    submitAliasRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .disabled(!canSubmitAliasRename)
            }
        }
    }

    private func submitAliasRename() {
        guard hasAliasChange else {
            aliasDraft = account.alias
            isAliasFieldFocused = false
            return
        }
        guard canSubmitAliasRename else { return }
        isAliasFieldFocused = false
        store.rename(account, to: cleanedAliasDraft)
    }

    private var switchHelpText: String {
        if store.settings.restartCodexAppAfterSwitch {
            return "Switch auth and restart Codex App so it reloads the account immediately."
        }
        return "Switch Codex CLI auth only. Restart Codex App yourself if it is already open."
    }

    private var metadata: some View {
        let details = AccountDetailMetadataPresentation(account: account)
        return Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            detailRow("Auth mode", details.authMode)
            detailRow("Plan", details.plan)
            detailRow("Account ID", details.accountIdentifier)
            detailRow("Fingerprint", details.fingerprint)
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
                .disabled(!store.canRefreshQuotas)
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
                    .lineLimit(2)
                    .truncationMode(.middle)
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
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var safety: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Token-safe by design", systemImage: "lock.shield")
                .font(.headline)
            Text("The app stores auth snapshots locally and only shows metadata such as email, plan, and fingerprint. It does not display access tokens or API keys.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Snapshots live in \(store.storageLocations.accountsDirectoryPath). Backups before switching live in \(store.storageLocations.backupsDirectoryPath).")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AccountDetailMetadataPresentation: Equatable {
    let authMode: String
    let plan: String
    let accountIdentifier: String
    let fingerprint: String

    init(account: CodexAccount) {
        authMode = Self.display(account.authMode, fallback: "Unknown")
        plan = Self.display(account.plan, fallback: "Unknown")
        accountIdentifier = Self.display(account.accountIdentifier, fallback: "Unknown")
        fingerprint = Self.fingerprint(account.fingerprint)
    }

    private static func display(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func fingerprint(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }
        return String(trimmed.prefix(10))
    }
}
