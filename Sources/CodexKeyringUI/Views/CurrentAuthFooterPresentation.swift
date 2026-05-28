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
    let subtitle: String
    let contextMenuTitle: String
    let showsSaveAction: Bool
    let canSaveAction: Bool
    let accessibilitySummary: String

    init(
        metadata: AuthMetadata?,
        savedAccount: CodexAccount?,
        authPath: String,
        showsSaveAction: Bool = false,
        canSaveAction: Bool = false
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
            title = MetadataDisplayText.text(metadata.email, fallback: "Unknown email")
        } else {
            title = "No readable auth.json"
        }

        if let savedAccount {
            subtitle = "Saved as \(savedAccount.displayName)"
            contextMenuTitle = "Already in Credentials"
        } else if metadata != nil {
            subtitle = "Not in credentials"
            contextMenuTitle = "Add to Credentials"
        } else {
            subtitle = authPath
            contextMenuTitle = "Add to Credentials"
        }

        accessibilitySummary = "Current Codex Auth: \(title). \(subtitle)."
    }
}
