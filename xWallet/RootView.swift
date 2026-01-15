//
//  RootView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 14/1/26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var appStore: Store<AppReducer>
    @StateObject private var accountStore: ScopedStore<AppReducer, AccountState, AccountAction>
    
    init(appStore: Store<AppReducer>) {
        self.appStore = appStore
        _accountStore = StateObject(
            wrappedValue: appStore.scope(
                state: \.account,
                action: AppAction.account
            )
        )
    }

    var body: some View {
        root.task {
            appStore.send(.appLaunched)
        }
    }
    
    
    @ViewBuilder
    private var root: some View {
        switch appStore.state.launchPhase {
        case .booting, .needsOnboarding:
            ImportAccountView(store: accountStore)
        case .ready:
            ContentView(appStore: appStore)
        }
    }
}

// Preview
#Preview {
    RootView(
        appStore: Store(
            initialState: AppState(),
            reducer: AppReducer()
        )
    )
}

