//
//  xWalletApp.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/11/25.
//

import SwiftUI

@main
struct xWalletApp: App {
    @StateObject private var appStore = Store(initialState: AppState(), reducer: AppReducer())
    
    init() {
        Dependencies.bootstrap()
//        WalletCoreValidator.runQuickCheck()
    }
    var body: some Scene {
        WindowGroup {
            RootView(appStore: appStore)
        }
    }
}
