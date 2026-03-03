//
//  WalletTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing
import BigInt
import Foundation

@testable import xWallet

@MainActor
struct WalletTests {

    private static let testIdentity = WalletIdentity(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Test Wallet",
        sourceType: .mnemonic,
        chainType: .evm,
        createdAt: Date(),
        derivedAddresses: [
            DerivedAddress(
                chain: .evm,
                path: "m/44'/60'/0'/0/0",
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            )
        ]
    )

    @Test
    func toggleShowBalance() async {
        let state = Wallet.State(showBalance: true)
        let store = TestStore(initialState: state) {
            Wallet()
        }

        await store.send(.setShowBalance(false)) {
            $0.showBalance = false
        }
    }

    @Test
    func receiveButtonPresentsSheet() async {
        @Shared(.activeIdentity) var activeIdentity = Self.testIdentity

        let state = Wallet.State()
        let store = TestStore(initialState: state) {
            Wallet()
        }

        await store.send(.receiveButtonTapped) {
            $0.receive = Receive.State(address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
        }
    }

    @Test
    func refreshWithoutAddressDoesNothing() async {
        let state = Wallet.State()
        let store = TestStore(initialState: state) {
            Wallet()
        }

        await store.send(.refreshButtonTapped)
    }
}
