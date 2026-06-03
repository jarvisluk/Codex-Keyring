import SwiftUI

public struct ContentView: View {
    public init() {}
    @EnvironmentObject var store: AccountStore
    @SceneStorage("selectedAccountID") var selectedAccountIDString: String?
    @State var showingAddCurrentSheet = false

    public var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: selectedAccountID,
                onAddCurrentLogin: showAddCurrentLoginSheet
            )
        } detail: {
            detailContent
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
