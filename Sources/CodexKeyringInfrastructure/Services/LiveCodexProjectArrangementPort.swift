import Foundation
import CodexKeyringDomain

extension LiveCodexAgentPreferencesPort {
    public func captureProjectArrangement() async throws -> CodexProjectArrangement {
        try await performIO {
            guard let stateData = try self.fileStore.readGlobalStateDataIfPresent() else {
                self.log.debug("global-state.json missing at \(self.globalStateURL.path); skipping project arrangement capture")
                return CodexProjectArrangement()
            }

            let arrangement = CodexProjectArrangement(
                projectOrder: self.stateEditor.readStringArray(at: Self.projectOrderPath, in: stateData),
                pinnedProjectIDs: self.stateEditor.readStringArray(at: Self.pinnedProjectIDsPath, in: stateData),
                sidebarOrganizeMode: self.stateEditor.readString(at: Self.sidebarOrganizeModePath, in: stateData)
            )
            self.log.info("captured project arrangement \(arrangement.liveProjectArrangementSummary)")
            return arrangement
        }
    }

    public func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws {
        try await performIO {
            guard !arrangement.isEmpty else {
                self.log.debug("project arrangement restore skipped: no captured fields")
                return
            }

            try self.fileStore.ensureCodexDirectoryExists()

            var data = try self.fileStore.readGlobalStateDataIfPresent() ?? Data("{}".utf8)

            if let projectOrder = arrangement.projectOrder {
                data = try self.stateEditor.writing(projectOrder, at: Self.projectOrderPath, in: data)
            }
            if let pinnedProjectIDs = arrangement.pinnedProjectIDs {
                data = try self.stateEditor.writing(pinnedProjectIDs, at: Self.pinnedProjectIDsPath, in: data)
            }
            if let sidebarOrganizeMode = arrangement.sidebarOrganizeMode {
                data = try self.stateEditor.writing(sidebarOrganizeMode, at: Self.sidebarOrganizeModePath, in: data)
            }

            try self.fileStore.writeGlobalState(data: data)
            self.log.info("restored project arrangement \(arrangement.liveProjectArrangementSummary)")
        }
    }
}
