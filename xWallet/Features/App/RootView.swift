//
//  RootView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 14/1/26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var appStore: Store<AppReducer>
    
    init(appStore: Store<AppReducer>) {
        self.appStore = appStore
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
            ContentView(appStore: appStore)
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

