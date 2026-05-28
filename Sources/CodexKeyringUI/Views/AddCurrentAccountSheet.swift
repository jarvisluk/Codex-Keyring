import SwiftUI

struct AddCurrentAccountSheet: View {
    // module-internal; rendered by ContentView
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AccountStore
    @State private var alias = ""
    @FocusState private var isAliasFocused: Bool

    private var presentation: AddCurrentAccountSheetPresentation {
        AddCurrentAccountSheetPresentation(
            metadata: store.currentAuthMetadata,
            canSave: store.canAddCurrentLogin
        )
    }

    var body: some View {
        let presentation = self.presentation
        VStack(alignment: .leading, spacing: KeyringStyle.Spacing.cardPadding) {
            Text("Save Current Codex Login")
                .font(.title2.bold())

            currentAuthSummary(for: presentation)

            Text("Token contents are copied into a private local snapshot and are never shown.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Alias", text: $alias)
                .textFieldStyle(.roundedBorder)
                .frame(width: KeyringStyle.Layout.sheetTextFieldWidth)
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
                .disabled(!presentation.canSave)
            }
        }
        .padding(KeyringStyle.Spacing.detailPagePadding)
        .frame(width: KeyringStyle.Layout.sheetWidth)
        .onAppear {
            isAliasFocused = true
        }
    }

    private func save() {
        guard presentation.canSave else { return }
        store.addCurrentAccount(alias: alias)
        dismiss()
    }

    @ViewBuilder
    private func currentAuthSummary(for presentation: AddCurrentAccountSheetPresentation) -> some View {
        if let summary = presentation.summary {
            AddCurrentAuthSummaryView(summary: summary)
        } else {
            Label(presentation.unreadableAuthTitle, systemImage: presentation.unreadableAuthSystemImage)
                .foregroundStyle(.secondary)
        }
    }
}
