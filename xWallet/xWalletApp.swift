//
//  xWalletApp.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/11/25.
//

import SwiftUI

@main
struct xWalletApp: App {
    init() {
        WalletCoreValidator.runQuickCheck()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
