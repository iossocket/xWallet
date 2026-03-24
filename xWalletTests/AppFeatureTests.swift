//
//  AppFeatureTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 6/3/26.
//

import ComposableArchitecture
import Testing
import EthereumKit

@testable import xWallet

@MainActor
struct AppFeatureTests {
    @Test
    func initializeChainsWhenDatabaseEmpty() async {
        let presetChains = ChainPresets.presetsWithEnabledStatus()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { [] }  // Empty database
            $0.chainRegistry.batchInsertChains = { chains in
                return presetChains
            }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.initializeChains)

        await store.receive(\.initializeChainsResponse.success)
    }

    @Test
    func initializeChainsWhenDatabaseNotEmpty() async {
        let existingChains = [EvmChain.sepolia, EvmChain.mainnet].map { $0.toChain() }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { existingChains }  // Database has chains
            $0.chainRegistry.batchInsertChains = { chains in
                return chains  // Starknet chains still need inserting
            }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.initializeChains)

        await store.receive(\.initializeChainsResponse.success)
    }

    @Test
    func initializeChainsHandlesError() async {
        enum DummyError: Error {
            case databaseError
        }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { throw DummyError.databaseError }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.initializeChains)

        await store.receive(\.initializeChainsResponse.failure)
    }
}
