import SwiftUI

struct AccountRenamePopover: View {
    @Binding var renameDraft: String
    let canSubmit: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Account")
                .font(.headline)

            TextField("New name", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .focused($isRenameFieldFocused)
                .onSubmit(onSubmit)
                .frame(width: 280)

            HStack {
                Spacer()
                Button("Cancel") {
                    isRenameFieldFocused = false
                    onCancel()
                }
                Button("Rename") {
                    isRenameFieldFocused = false
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            isRenameFieldFocused = true
        }
    }
}
