import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            WalletTabView(
                store: store.scope(state: \.wallet, action: \.wallet)
            )
            .tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
            .tag(Tab.wallet)

            Text("Market")
                .tabItem { Label("Market", systemImage: "chart.bar.fill") }
                .tag(Tab.market)

            NewsFeedBridge()
                .ignoresSafeArea()
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(Tab.discover)

            SettingsView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(Tab.profile)
        }
        #if DEBUG
        .onShake {
            XWDebugOverlay.shared.toggle()
        }
        #endif
    }
}
