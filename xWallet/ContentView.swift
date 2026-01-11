import SwiftUI

// MARK: - Main View
struct ContentView: View {
    @StateObject private var appStore = Store(initialState: AppState(), reducer: AppReducer())
    
    private var tabBinding: Binding<Tab> {
        Binding(
            get: { appStore.state.selectedTab },
            set: { appStore.send(.tabSelected($0)) }
        )
    }
    
    var body: some View {
        TabView(selection: tabBinding) {
            WalletTabView(
                state: appStore.state.wallet,
                send: { appStore.send(.wallet($0)) }
            ).tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
                .tag(Tab.wallet)

            Text("Market")
                .tabItem { Label("Market", systemImage: "chart.bar.fill") }
                .tag(Tab.market)

            Text("Discover")
                .tabItem { Label("Discover", systemImage: "safari.fill") }
                .tag(Tab.discover)

            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
    }
}

// Preview
#Preview {
    ContentView()
}
