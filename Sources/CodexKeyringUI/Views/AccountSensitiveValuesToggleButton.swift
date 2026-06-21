import SwiftUI

struct AccountSensitiveValuesToggleButton: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary)
                .frame(
                    width: KeyringStyle.Icon.toolbarSize,
                    height: KeyringStyle.Icon.toolbarSize
                )
                .accessibilityHidden(true)
        }
        .accessibilityLabel(title)
        .help(helpText)
    }

    private var title: String {
        isVisible ? "Hide Sensitive Info" : "Show Sensitive Info"
    }

    private var systemImage: String {
        isVisible ? "eye.slash" : "eye"
    }

    private var helpText: String {
        isVisible ? "Hide account-sensitive values." : "Show account-sensitive values."
    }
}
