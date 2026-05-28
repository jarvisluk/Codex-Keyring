import Foundation

extension SwitchAccountUseCase {
    public func callAsFunction(
        accountID: UUID,
        restartCodexApp: Bool
    ) async throws -> SwitchAccountResult {
        var manifest = try await repository.load()
        let target = try await loadSwitchTarget(accountID: accountID, from: manifest)
        let currentAuth = try await readLiveAuthIfPresent()

        try await syncCurrentLiveAuthIfPresent(currentAuth, manifest: &manifest)

        let wasAlreadyActive = isAlreadyActive(
            account: target.account,
            currentAuth: currentAuth,
            manifest: manifest
        )

        let restartPlan = makeRestartPlan(
            restartCodexApp: restartCodexApp,
            manifest: manifest
        )
        let warningBox = SwitchAccountWarningBox()

        await SwitchAccountPreferenceCapture(preferencesPort: preferencesPort)
            .captureOutgoingIfNeeded(
                manifest: &manifest,
                preserveEnabled: restartPlan.preserveEnabled,
                wasAlreadyActive: wasAlreadyActive,
                warningBox: warningBox
            )

        let installedSnapshot = try await installSnapshotIfNeeded(
            snapshotURL: target.snapshotURL,
            wasAlreadyActive: wasAlreadyActive
        )

        manifest.activeAccountID = target.account.id
        try await saveManifestAfterInstall(
            manifest,
            installedSnapshot: installedSnapshot
        )

        let restart = await SwitchAccountRestartCoordinator(
            appController: appController,
            preferencesPort: preferencesPort
        ).restartIfRequested(
            restartCodexApp: restartCodexApp,
            shouldRestartCodexApp: restartPlan.shouldRestartCodexApp,
            preserveEnabled: restartPlan.preserveEnabled,
            wasAlreadyActive: wasAlreadyActive,
            targetPreferences: targetPreferences(accountID: target.account.id, in: manifest),
            warningBox: warningBox
        )

        return SwitchAccountResult(
            state: AccountState(
                manifest: manifest,
                currentAuthMetadata: wasAlreadyActive ? currentAuth : target.selectedSnapshotMetadata
            ),
            switchedAlias: target.account.displayName,
            restartOutcome: restart.outcome,
            restartFailureReason: restart.failureReason,
            wasAlreadyActive: wasAlreadyActive,
            appliedAgentPreferences: restart.appliedAgentPreferences,
            agentPreferencesWarningReason: warningBox.agentPreferencesWarningReason,
            projectArrangementWarningReason: warningBox.projectArrangementWarningReason
        )
    }
}
