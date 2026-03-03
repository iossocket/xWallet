//
//  SettingsTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing
import Foundation
import EthereumKit

@testable import xWallet

@MainActor
struct SettingsTests {

    @Test
    func checkConnectionSuccess() async {
        let state = Settings.State(
            isChecking: true,
            isValid: true,
            rpcURL: "https://rpc.sepolia.org"
        )
        let store = TestStore(initialState: state) {
            Settings()
        }

        await store.send(.checkResponse(.success(11155111))) {
            $0.isChecking = false
            $0.chainId = 11155111
            $0.connectionStatus = .connected
        }
    }

    @Test
    func checkConnectionFailure() async {
        let state = Settings.State(
            isChecking: true,
            isValid: true,
            rpcURL: "https://bad.url"
        )
        let store = TestStore(initialState: state) {
            Settings()
        }

        struct NetworkError: Error, LocalizedError {
            var errorDescription: String? { "Network request failed" }
        }

        await store.send(.checkResponse(.failure(NetworkError()))) {
            $0.isChecking = false
            $0.connectionStatus = .failed("Network request failed")
        }
    }

    @Test
    func invalidURLPreventsCheck() async {
        let state = Settings.State(
            isValid: false,
            rpcURL: "not-a-url"
        )
        let store = TestStore(initialState: state) {
            Settings()
        }

        await store.send(.checkButtonTapped) {
            $0.connectionStatus = .failed("Invalid URL")
        }
    }
}
