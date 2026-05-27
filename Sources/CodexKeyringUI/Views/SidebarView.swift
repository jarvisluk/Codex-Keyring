import SwiftUI
import CodexKeyringDomain

struct SidebarView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var selection: UUID?
    let onAddCurrentLogin: () -> Void

    var body: some View {
        List(selection: $selection) {
            Section("Accounts") {
                ForEach(store.accounts) { account in
                    AccountRow(
                        account: account,
                        isActive: store.activeAccount?.id == account.id,
                        isSelected: selection == account.id,
                        quotaState: store.quotaStates[account.id]
                    )
                        .tag(account.id)
                }
            }
        }
        .listStyle(.sidebar)
        .tint(.green)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                CurrentAuthFooter(onAddCurrentLogin: onAddCurrentLogin)

                StatusFooter()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
    }
}

private struct StatusFooter: View {
    @EnvironmentObject private var store: AccountStore

    private var isError: Bool {
        store.lastError != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(width: 14, height: 14)
            } else if store.isStatusBusy {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            }

            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(isError ? .red : .secondary)
                .lineLimit(isError ? 3 : 2)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(store.statusMessage)
        .accessibilityLabel("Status: \(store.statusMessage)")
    }
}

private struct CurrentAuthFooter: View {
    @EnvironmentObject private var store: AccountStore
    let onAddCurrentLogin: () -> Void

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

    private var presentation: CurrentAuthFooterPresentation {
        CurrentAuthFooterPresentation(
            metadata: store.currentAuthMetadata,
            savedAccount: store.savedAccountForCurrentAuth,
            authPath: store.storageLocations.codexAuthPath
        )
    }

    private var canAddCurrentAuth: Bool {
        store.canAddCurrentLogin
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

                Text(presentation.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if store.canSaveCurrentAuth {
                Button {
                    onAddCurrentLogin()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help("Save the current Codex auth as a named account.")
                .accessibilityLabel("Save Current Login")
                .disabled(!canAddCurrentAuth)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilitySummary)
        .contextMenu {
            Button {
                onAddCurrentLogin()
            } label: {
                Label(presentation.contextMenuTitle, systemImage: "plus.circle")
            }
            .disabled(!canAddCurrentAuth)
        }
        .help(store.storageLocations.codexAuthPath)
    }
}

struct CurrentAuthFooterPresentation: Equatable {
    let title: String
    let subtitle: String
    let contextMenuTitle: String
    let accessibilitySummary: String

    init(
        metadata: AuthMetadata?,
        savedAccount: CodexAccount?,
        authPath: String
    ) {
        if let metadata {
            title = Self.display(metadata.email, fallback: "Unknown email")
        } else {
            title = "No readable auth.json"
        }

        if let savedAccount {
            subtitle = "Saved as \(savedAccount.displayName)"
            contextMenuTitle = "Already in Credentials"
        } else if metadata != nil {
            subtitle = "Not in credentials"
            contextMenuTitle = "Add to Credentials"
        } else {
            subtitle = authPath
            contextMenuTitle = "Add to Credentials"
        }

        accessibilitySummary = "Current Codex Auth: \(title). \(subtitle)."
    }

    private static func display(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

private struct AccountRow: View {
    var account: CodexAccount
    var isActive: Bool
    var isSelected: Bool
    var quotaState: AccountQuotaState?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                .foregroundStyle(statusIconTint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                detailLine
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var detailLine: some View {
        HStack(spacing: 4) {
            Text(account.displayEmail)
                .foregroundStyle(secondaryTextTint)
                .truncationMode(.middle)
            if let quota = quotaState?.sidebarSummary {
                Text("-")
                    .foregroundStyle(secondaryTextTint)
                Text(quota)
                    .foregroundStyle(quotaTextTint)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }

    private var statusIconTint: Color {
        if isSelected {
            return isActive ? .white : .white.opacity(0.85)
        }
        return isActive ? .green : .secondary
    }

    private var secondaryTextTint: Color {
        isSelected ? .white.opacity(0.82) : .secondary
    }

    private var quotaTextTint: Color {
        if isSelected {
            return .white
        }
        return quotaState?.health.tint ?? .secondary
    }

    private var accessibilitySummary: String {
        var parts = [account.displayName, account.displayEmail]
        if isActive {
            parts.append("active")
        }
        if let quota = quotaState?.sidebarSummary {
            parts.append(quota)
        }
        return parts.joined(separator: ", ")
    }
}
