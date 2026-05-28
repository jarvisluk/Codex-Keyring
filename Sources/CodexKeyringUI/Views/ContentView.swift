import SwiftUI

public struct ContentView: View {
    public init() {}
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settingsPresentation: SettingsPresentationStore
    @SceneStorage("selectedAccountID") var selectedAccountIDString: String?
    @State var showingAddCurrentSheet = false

    public var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(
                    selection: selectedAccountID,
                    onAddCurrentLogin: showAddCurrentLoginSheet
                )
            } detail: {
                detailContent
            }
                .disabled(settingsPresentation.isPresented)

            if settingsPresentation.isPresented {
                SettingsModalOverlay {
                    settingsPresentation.dismiss()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(1)
            }
        }
        .background(MainWindowChromeConfigurator())
        .toolbar { accountToolbar }
        .accountStoreFailureAlert(store)
        .sheet(isPresented: $showingAddCurrentSheet) {
            AddCurrentAccountSheet()
                .environmentObject(store)
        }
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: accountIDs) {
            reconcileSelection()
        }
        .onChange(of: store.activeAccountID) {
            reconcileSelection()
        }
        .contentViewCommandHandlers(
            startNewLogin: startNewLogin,
            showAddCurrentLoginSheet: showAddCurrentLoginSheet,
            importAuthFile: importAuthFile
        )
        .animation(.easeInOut(duration: 0.16), value: settingsPresentation.isPresented)
    }
}

extension ContentView {
    @ViewBuilder
    var detailContent: some View {
        if let selectedAccount {
            AccountDetailView(account: selectedAccount)
        } else {
            EmptyAccountsView(
                onAddCurrentLogin: showAddCurrentLoginSheet,
                onImport: importAuthFile
            )
        }
    }
}
