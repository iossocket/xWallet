import SwiftUI

typealias AppStore = Store<AppReducer>
typealias WalletStore = ScopedStore<AppReducer, WalletState, WalletAction>
typealias SettingsStore = ScopedStore<AppReducer, SettingsState, SettingsAction>
typealias AccountStore = ScopedStore<AppReducer, AccountState, AccountAction>

// MARK: - Main View
struct ContentView: View {
    @ObservedObject var appStore: Store<AppReducer>
    
    @StateObject private var walletStore: WalletStore
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var accountStore: AccountStore
    
    init(appStore: Store<AppReducer>) {
        self.appStore = appStore
        _walletStore = StateObject(wrappedValue: appStore.scope(state: \.wallet, action: AppAction.wallet))
        _settingsStore = StateObject(wrappedValue: appStore.scope(state: \.settings, action: AppAction.settings))
        _accountStore = StateObject(wrappedValue: appStore.scope(state: \.account, action: AppAction.account))
    }
    
    
    var body: some View {
        TabView(selection: Binding(
            get: { appStore.state.selectedTab },
            set: { appStore.send(.tabSelected($0)) }
        )) {
            WalletTabView(store: walletStore)
                .tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
                .tag(Tab.wallet)

            Text("Market")
                .tabItem { Label("Market", systemImage: "chart.bar.fill") }
                .tag(Tab.market)

            Text("Discover")
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(Tab.discover)

            SettingsView(store: settingsStore)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.profile)
        }
    }
}
