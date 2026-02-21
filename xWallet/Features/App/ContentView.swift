import SwiftUI

typealias AppStore = Store<AppReducer>

// MARK: - Main View
struct ContentView: View {
    @ObservedObject var appStore: Store<AppReducer>
    
    init(appStore: Store<AppReducer>) {
        self.appStore = appStore
    }
    
    
    var body: some View {
        TabView(selection: Binding(
            get: { appStore.state.selectedTab },
            set: { appStore.send(.tabSelected($0)) }
        )) {
//            WalletTabView(store: walletStore)
//                .tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
//                .tag(Tab.wallet)

            Text("Market")
                .tabItem { Label("Market", systemImage: "chart.bar.fill") }
                .tag(Tab.market)

            Text("Discover")
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(Tab.discover)

//            SettingsView(store: settingsStore)
//                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
//                .tag(Tab.profile)
        }
    }
}
