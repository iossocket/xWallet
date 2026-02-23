//
//  AccountTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing

@testable import xWallet

@MainActor
struct AccountTests {
    
    @Test
    func importSuccess() async {
        let store = TestStore(initialState: Account.State()) {
            Account()
        } withDependencies: {
            $0.keychain.saveData = { _, _ in }
        }

        await store.send(.importButtonTapped("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"))
        await store.receive(\.importResponse.success) {
            $0.address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            $0.isUnlocked = true
        }
    }
    
    @Test
    func importFailure() async {
        let store = TestStore(initialState: Account.State()) {
            Account()
        } withDependencies: {
            $0.keychain.saveData = { _, _ in throw KeychainError.unexpectedStatus(-1) }
        }

        await store.send(.importButtonTapped("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"))
        await store.receive(\.importResponse.failure) {
            $0.errorMessage = "Keychain error: -1"
            $0.isUnlocked = false
        }
    }
    
    @Test
    func lockAccount() async {
        let store = TestStore(
            initialState: Account.State(
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                isUnlocked: true
            )
        ) {
            Account()
        }

        await store.send(.lockButtonTapped) {
            $0.isUnlocked = false
            $0.address = nil
        }
    }
}
