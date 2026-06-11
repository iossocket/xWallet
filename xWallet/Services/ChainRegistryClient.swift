//
//  ChainRegistryClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 4/3/26.
//

import GRDB
import EthereumKit
import ComposableArchitecture

@DependencyClient
struct ChainRegistryClient {
    var listAllChains: @Sendable () async throws -> [Chain]
    var listEnabledChains: @Sendable () async throws -> [Chain]
    var createNewChain: @Sendable (Chain, Bool) async throws -> Chain
    var updateChain: @Sendable (Chain, Bool) async throws -> Chain?
    var batchInsertChains: @Sendable ([Chain]) async throws -> [Chain]
}

extension ChainRegistryClient: DependencyKey {
    static var liveValue: ChainRegistryClient {
        @Dependency(\.chainDataSource) var dataSource
        return ChainRegistryClient {
            try await dataSource.listChains()
        } listEnabledChains: {
            try await dataSource.listEnabledChains()
        } createNewChain: { chain, enable in
            try await dataSource.saveChain(chain, enable)
        } updateChain: { chain, enable in
            try await dataSource.update(chain, enable)
        } batchInsertChains: { chains in
            try await dataSource.saveChains(chains)
        }
    }
}

extension DependencyValues {
    var chainRegistry: ChainRegistryClient {
        get { self[ChainRegistryClient.self] }
        set { self[ChainRegistryClient.self] = newValue }
    }
}
