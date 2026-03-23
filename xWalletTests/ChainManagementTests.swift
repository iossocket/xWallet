//
//  ChainManagementTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 5/3/26.
//

import ComposableArchitecture
import Testing
import EthereumKit

@testable import xWallet
import Foundation

let testChains = [EvmChain.sepolia, EvmChain.mainnet].map { chain in
    Chain(id: chain.id, chainId: String(chain.chainId), name: chain.name, rpcURL: chain.rpcURL.absoluteString, isTestnet: chain.isTestnet, symbol: chain.symbol, decimals: chain.decimals, explorerURL: chain.explorerURL == nil ? nil : chain.explorerURL!.absoluteString, enabled: true)
}

@MainActor
struct ChainManagementTests {
    @Test
    func loadChainsSuccess() async {
        let store = TestStore(initialState: ChainManagement.State()) {
            ChainManagement()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { testChains }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.loadChainsResponse.success) {
            $0.isLoading = false
            $0.chains = testChains
        }
    }

    @Test
    func loadChainsFailure() async {
        enum DummyError: Error {
            case dummyError
        }
        let store = TestStore(initialState: ChainManagement.State()) {
            ChainManagement()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { throw DummyError.dummyError }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.loadChainsResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = DummyError.dummyError.localizedDescription
        }
    }

    @Test
    func chainRowTapped() async {
        let testChain = EvmChain.sepolia.toChain()
        let store = TestStore(initialState: ChainManagement.State()) {
            ChainManagement()
        }

        await store.send(.chainRowTapped(testChain)) {
            $0.chainDetail = ChainDetail.State(chain: testChain)
        }
    }

    @Test
    func chainToggledUpdate() async {
        let testChain = testChains[0]
        let presetChains = ChainPresets.presetsWithEnabledStatus()

        var initialState = ChainManagement.State(chains: [testChain])
        initialState.errorMessage = "Previous error"  // Set initial error so clearing it is a state change

        let store = TestStore(initialState: initialState) {
            ChainManagement()
        } withDependencies: {
            $0.chainRegistry.updateChain = { chain, enabled in
                return chain
            }
            $0.chainRegistry.listAllChains = { [] }
            $0.chainRegistry.batchInsertChains = { chains in
                return presetChains
            }
        }

        await store.send(.chainToggled(testChain, false))

        await store.receive(\.toggleResponse.success) {
            $0.errorMessage = nil
        }

        // When listAllChains returns empty array, no state changes in loadChainsResponse
        await store.receive(\.loadChainsResponse.success)

        await store.receive(\.batchInsertChains.success) {
            $0.isLoading = false
            $0.chains = presetChains
        }
    }
}

@MainActor
struct ChainDetailTests {
    @Test
    func saveButtonSuccess() async {
        let testChain = EvmChain.sepolia.toChain()
        var state = ChainDetail.State(chain: testChain)
        state.connectionStatus = .connected
        state.customRpcURL = "https://custom-rpc.example.com"

        let store = TestStore(initialState: state) {
            ChainDetail()
        } withDependencies: {
            $0.chainRegistry.updateChain = { chain, enabled in
                return chain
            }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(\.saveResponse.success) {
            $0.isSaving = false
        }

        await store.finish()
    }

    @Test
    func saveButtonInvalidURL() async {
        let testChain = EvmChain.sepolia.toChain()
        var state = ChainDetail.State(chain: testChain)
        state.connectionStatus = .connected
        state.customRpcURL = "invalid-url"

        let store = TestStore(initialState: state) {
            ChainDetail()
        }

        await store.send(.saveButtonTapped) {
            $0.connectionStatus = .failed("Invalid URL")
        }
    }
}
