import SwiftUI

struct AccountSensitiveValueText: View {
    let value: String
    let revealed: Bool
    let displayValue: String?

    init(
        _ value: String,
        revealed: Bool,
        displayValue: String? = nil
    ) {
        self.value = value
        self.revealed = revealed
        self.displayValue = displayValue
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(value)
                .hidden()
                .accessibilityHidden(true)
                .textSelection(.disabled)

            Text(displayValue ?? AccountSensitiveText.display(value, revealed: revealed))
        }
    }
}
