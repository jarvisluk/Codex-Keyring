import SwiftUI

struct ToolbarActionLabel: View {
    let title: String
    let systemImage: String
    let isLoading: Bool

    init(_ title: String, systemImage: String, isLoading: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            ZStack {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
                    .opacity(isLoading ? 0 : 1)

                ProgressView()
                    .controlSize(.small)
                    .opacity(isLoading ? 1 : 0)
            }
            .frame(width: 16, height: 16)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(title)
    }
}
