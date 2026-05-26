import SwiftUI

struct AddCurrentAccountSheet: View {
    // module-internal; rendered by ContentView
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AccountStore
    @State private var alias = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save Current Codex Login")
                .font(.title2.bold())

            Text("This copies the current ~/.codex/auth.json into this app's private account snapshots. Token contents are not shown.")
                .foregroundStyle(.secondary)

            TextField("Alias", text: $alias)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    store.addCurrentAccount(alias: alias)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
