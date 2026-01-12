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
        let url = UserDefaults.standard.string(forKey: "rpc_url")
                    ?? "https://rpc.sepolia.org"
        Dependencies.setRPCURL(url)
//        WalletCoreValidator.runQuickCheck()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
