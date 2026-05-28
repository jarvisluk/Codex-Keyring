import Foundation
import CodexKeyringDomain

extension AccountAgentPreferences {
    /// Compact human-readable summary for logs. Never includes anything that
    /// looks like a secret; these fields are enum-like strings or booleans.
    var liveAgentPreferencesSummary: String {
        var parts: [String] = []
        if let model { parts.append("model=\(model)") }
        if let modelReasoningEffort { parts.append("effort=\(modelReasoningEffort)") }
        if let approvalPolicy { parts.append("approval=\(approvalPolicy)") }
        if let approvalsReviewer { parts.append("reviewer=\(approvalsReviewer)") }
        if let sandboxMode { parts.append("sandbox=\(sandboxMode)") }
        if let agentMode { parts.append("agentMode=\(agentMode)") }
        if let skipFullAccessConfirm { parts.append("skipConfirm=\(skipFullAccessConfirm)") }
        return "[\(parts.joined(separator: ", "))]"
    }
}

extension CodexProjectArrangement {
    var liveProjectArrangementSummary: String {
        var parts: [String] = []
        if let projectOrder { parts.append("projectOrder=\(projectOrder.count)") }
        if let pinnedProjectIDs { parts.append("pinned=\(pinnedProjectIDs.count)") }
        if let sidebarOrganizeMode { parts.append("sidebarMode=\(sidebarOrganizeMode)") }
        return "[\(parts.joined(separator: ", "))]"
    }
}
