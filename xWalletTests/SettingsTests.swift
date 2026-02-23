//
//  SettingsTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing
import Foundation

@testable import xWallet

@MainActor
struct SettingsTests {
    @Test
    func checkConnectionSuccess() async {
        let store = TestStore(initialState: Settings.State(isValid: true, rpcURL: "https://rpc.sepolia.org")) {
            Settings()
        } withDependencies: {
            $0.evmRpcClient.getChainId = { _ in 11155111 }
        }

        await store.send(.checkButtonTapped) {
            $0.isChecking = true
            $0.connectionStatus = .idle
            $0.chainId = nil
        }
        await store.receive(\.checkResponse.success) {
            $0.isChecking = false
            $0.chainId = 11155111
            $0.connectionStatus = .connected
        }
    }

    @Test
    func checkConnectionFailure() async {
        let error = EthereumServiceError.invalidURL("bad")
        let store = TestStore(initialState: Settings.State(isValid: true, rpcURL: "https://bad.url")) {
            Settings()
        } withDependencies: {
            $0.evmRpcClient.getChainId = { _ in throw error }
        }

        await store.send(.checkButtonTapped) {
            $0.isChecking = true
            $0.connectionStatus = .idle
            $0.chainId = nil
        }
        await store.receive(\.checkResponse.failure) {
            $0.isChecking = false
            $0.connectionStatus = .failed(error.localizedDescription)
        }
    }

    @Test
    func invalidURLPreventsCheck() async {
        let store = TestStore(initialState: Settings.State(isValid: false, rpcURL: "not-a-url")) {
            Settings()
        }

        await store.send(.checkButtonTapped) {
            $0.connectionStatus = .failed("Invalid URL")
        }
    }
}
