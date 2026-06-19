import SwiftUI

struct AccountSensitiveValuesToggleButton: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            ToolbarActionLabel(
                isVisible ? "Hide Sensitive Info" : "Show Sensitive Info",
                systemImage: isVisible ? "eye.slash" : "eye"
            )
        }
        .help(isVisible ? "Hide account-sensitive values." : "Show account-sensitive values.")
    }
}
