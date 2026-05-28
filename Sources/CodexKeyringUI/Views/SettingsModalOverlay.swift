import SwiftUI

struct SettingsModalOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            SettingsView(onDismiss: onDismiss)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(
                        cornerRadius: KeyringStyle.Radius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: KeyringStyle.Radius.card,
                        style: .continuous
                    )
                    .stroke(.quaternary, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand(perform: onDismiss)
    }
}
