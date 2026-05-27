import CodexKeyringDomain
import SwiftUI

struct AddCurrentAccountSheet: View {
    // module-internal; rendered by ContentView
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AccountStore
    @State private var alias = ""
    @FocusState private var isAliasFocused: Bool

    private var canSave: Bool {
        store.canAddCurrentLogin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Current Codex Login")
                .font(.title2.bold())

            currentAuthSummary

            Text("Token contents are copied into a private local snapshot and are never shown.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Alias", text: $alias)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .focused($isAliasFocused)
                .onSubmit(save)
                .help("Optional. Leave blank to use the account email.")

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            isAliasFocused = true
        }
    }

    private func save() {
        guard canSave else { return }
        store.addCurrentAccount(alias: alias)
        dismiss()
    }

    @ViewBuilder
    private var currentAuthSummary: some View {
        if let metadata = store.currentAuthMetadata {
            let summary = AddCurrentAccountSummary(metadata: metadata)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                summaryRow("Email", summary.email)
                summaryRow("Plan", summary.plan)
                summaryRow("Auth", summary.authMode)
                summaryRow("Fingerprint", summary.fingerprint)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        } else {
            Label("No readable Codex auth.json", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

struct AddCurrentAccountSummary: Equatable {
    let email: String
    let plan: String
    let authMode: String
    let fingerprint: String

    init(metadata: AuthMetadata) {
        email = Self.display(metadata.email, fallback: "Unknown email")
        plan = Self.display(metadata.plan, fallback: "Unknown")
        authMode = Self.display(metadata.authMode, fallback: "Unknown")
        fingerprint = Self.displayFingerprint(metadata.fingerprint)
    }

    private static func display(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func displayFingerprint(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }
        return String(trimmed.prefix(10))
    }
}
