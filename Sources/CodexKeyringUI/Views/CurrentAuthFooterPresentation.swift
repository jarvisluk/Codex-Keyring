import SwiftUI
import CodexKeyringDomain

enum CurrentAuthFooterTint: Equatable {
    case saved
    case secondary

    var color: Color {
        switch self {
        case .saved:
            return .green
        case .secondary:
            return .secondary
        }
    }
}

struct CurrentAuthFooterPresentation: Equatable {
    let statusSystemImage: String
    let statusIconTint: CurrentAuthFooterTint
    let title: String
    let titleLayoutValue: String
    let subtitle: String
    let subtitleLayoutValue: String
    let contextMenuTitle: String
    let showsSaveAction: Bool
    let canSaveAction: Bool
    let accessibilitySummary: String

    init(
        metadata: AuthMetadata?,
        savedAccount: CodexAccount?,
        authPath: String,
        showsSaveAction: Bool = false,
        canSaveAction: Bool = false,
        showsSensitiveValues: Bool = false
    ) {
        statusIconTint = savedAccount != nil ? .saved : .secondary
        self.showsSaveAction = showsSaveAction
        self.canSaveAction = canSaveAction
        if metadata == nil {
            statusSystemImage = "person.crop.circle.badge.questionmark"
        } else if savedAccount != nil {
            statusSystemImage = "checkmark.circle.fill"
        } else {
            statusSystemImage = "circle"
        }

        if let metadata {
            titleLayoutValue = MetadataDisplayText.text(metadata.email, fallback: "Unknown email")
            title = AccountSensitiveText.display(titleLayoutValue, revealed: showsSensitiveValues)
        } else {
            titleLayoutValue = "No readable auth.json"
            title = "No readable auth.json"
        }

        if let savedAccount {
            let savedAccountName = AccountSensitiveText.displayName(
                for: savedAccount,
                revealed: showsSensitiveValues
            )
            let savedAccountLayoutName = AccountSensitiveText.displayName(
                for: savedAccount,
                revealed: true
            )
            subtitle = "Saved as \(savedAccountName)"
            subtitleLayoutValue = "Saved as \(savedAccountLayoutName)"
            contextMenuTitle = "Already in Credentials"
        } else if metadata != nil {
            subtitle = "Not in credentials"
            subtitleLayoutValue = "Not in credentials"
            contextMenuTitle = "Add to Credentials"
        } else {
            subtitle = AccountSensitiveText.display(authPath, revealed: showsSensitiveValues)
            subtitleLayoutValue = authPath
            contextMenuTitle = "Add to Credentials"
        }

        accessibilitySummary = "Current Codex Auth: \(title). \(subtitle)."
    }
}
