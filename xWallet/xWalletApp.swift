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
    
    init() {
//        Dependencies.bootstrap()
//        WalletCoreValidator.runQuickCheck()
    }
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
