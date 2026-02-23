//
//  WalletTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing
import BigInt

@testable import xWallet

@MainActor
struct WalletTests {
    @Test
    func toggleShowBalance() async {
        let store = TestStore(initialState: Wallet.State(showBalance: true)) {
            Wallet()
        }

        await store.send(.setShowBalance(false)) {
            $0.showBalance = false
        }
    }

    @Test
    func receiveButtonPresentsSheet() async {
        let store = TestStore(initialState: Wallet.State(address: "0xABC")) {
            Wallet()
        }

        await store.send(.receiveButtonTapped) {
            $0.receive = Receive.State(address: "0xABC")
        }
    }

    @Test
    func refreshWithoutAddressDoesNothing() async {
        let store = TestStore(initialState: Wallet.State(address: nil)) {
            Wallet()
        }
        await store.send(.refreshButtonTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
            $0.assets = AssetItem.preset
        }
    }
}
