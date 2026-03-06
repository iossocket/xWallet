//
//  AccountTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing
import Foundation

@testable import xWallet

@MainActor
struct AccountTests {

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
    func createWalletSuccess() async {
        let state = Account.State()
        let store = TestStore(initialState: state) {
            Account()
        } withDependencies: {
            $0.walletClient.createWallet = { _, _ in await Self.testIdentity }
        }

        await store.send(.createWalletTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.createWalletResponse.success) {
            $0.isLoading = false
            $0.activeIdentity = Self.testIdentity
            $0.isUnlocked = true
        }
    }

    @Test
    func createWalletFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "Failed to generate mnemonic" }
        }
        let state = Account.State()
        let store = TestStore(initialState: state) {
            Account()
        } withDependencies: {
            $0.walletClient.createWallet = { _, _ in throw FakeError() }
        }

        await store.send(.createWalletTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.createWalletResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = "Failed to generate mnemonic"
        }
    }

    @Test
    func importPrivateKeySuccess() async {
        let state = Account.State(
            onboardingStep: .importPrivateKey,
            selectedChain: .evm,
            privateKeyInput: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        )
        let store = TestStore(initialState: state) {
            Account()
        } withDependencies: {
            $0.walletClient.importPrivateKey = { _, _, _ in await Self.testIdentity }
        }

        await store.send(.importPrivateKeyTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.importPrivateKeyResponse.success) {
            $0.isLoading = false
            $0.activeIdentity = Self.testIdentity
            $0.isUnlocked = true
            $0.errorMessage = nil
        }
    }

    @Test
    func importPrivateKeyFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "Invalid private key format" }
        }
        let state = Account.State(
            onboardingStep: .importPrivateKey,
            selectedChain: .evm,
            privateKeyInput: "bad-key"
        )
        let store = TestStore(initialState: state) {
            Account()
        } withDependencies: {
            $0.walletClient.importPrivateKey = { _, _, _ in throw FakeError() }
        }

        await store.send(.importPrivateKeyTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.importPrivateKeyResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = "Invalid private key format"
        }
    }

    @Test
    func importMnemonicSuccess() async {
        let mnemonic = "test test test test test test test test test test test junk"
        let state = Account.State(
            onboardingStep: .importMnemonic,
            selectedChain: .evm,
            mnemonicInput: mnemonic
        )
        let store = TestStore(initialState: state) {
            Account()
        } withDependencies: {
            $0.walletClient.importMnemonic = { _, _, _ in await Self.testIdentity }
        }

        await store.send(.importMnemonicTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.importMnemonicResponse.success) {
            $0.isLoading = false
            $0.activeIdentity = Self.testIdentity
            $0.isUnlocked = true
            $0.errorMessage = nil
        }
    }

    @Test
    func importMnemonicFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "Invalid mnemonic" }
        }
        let state = Account.State(
            onboardingStep: .importMnemonic,
            selectedChain: .evm,
            mnemonicInput: "invalid words"
        )
        let store = TestStore(initialState: state) {
            Account()
        } withDependencies: {
            $0.walletClient.importMnemonic = { _, _, _ in throw FakeError() }
        }

        await store.send(.importMnemonicTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.importMnemonicResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = "Invalid mnemonic"
        }
    }

    @Test
    func chainSelection() async {
        let state = Account.State()
        let store = TestStore(initialState: state) {
            Account()
        }

        await store.send(.chainSelected(.starknet)) {
            $0.selectedChain = .starknet
        }
    }

    @Test
    func lockAccount() async {
        let state = Account.State(
            isUnlocked: true,
            activeIdentity: Self.testIdentity
        )
        let store = TestStore(initialState: state) {
            Account()
        }

        await store.send(.lockButtonTapped) {
            $0.isUnlocked = false
            $0.activeIdentity = nil
        }
    }
}
