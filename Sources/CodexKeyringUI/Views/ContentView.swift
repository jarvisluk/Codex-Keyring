import SwiftUI

public struct ContentView: View {
    public init(showsAccountSensitiveValues: Binding<Bool> = .constant(false)) {
        _showsAccountSensitiveValues = showsAccountSensitiveValues
    }

    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settingsPresentation: SettingsPresentationStore
    @Binding var showsAccountSensitiveValues: Bool
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
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .background(
            MainWindowChromeConfigurator()
        )
        .environment(\.accountSensitiveValuesVisible, showsAccountSensitiveValues)
        .toolbar { accountToolbar }
        .accountStoreFailureAlert(store)
        .sheet(isPresented: $showingAddCurrentSheet) {
            AddCurrentAccountSheet()
                .environmentObject(store)
                .environment(\.accountSensitiveValuesVisible, showsAccountSensitiveValues)
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
            AccountDetailView(
                account: selectedAccount,
                showsAccountSensitiveValues: $showsAccountSensitiveValues
            )
        } else {
            EmptyAccountsView(
                onAddCurrentLogin: showAddCurrentLoginSheet,
                onImport: importAuthFile
            )
        }
    }
}
