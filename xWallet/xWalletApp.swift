//
//  xWalletApp.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/11/25.
//

import SwiftUI
import ComposableArchitecture

@main
struct xWalletApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    @Environment(\.scenePhase) var scenePhase

    init() {
        AppConfiguration.setup()
    }
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .onChange(of: scenePhase) { _, newPhase in
                    store.send(.scenePhaseChanged(newPhase))
                }
        }
    }
}
