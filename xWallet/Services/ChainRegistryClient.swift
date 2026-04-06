//
//  ChainRegistryClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 4/3/26.
//

import GRDB
import EthereumKit
import Foundation
import Dependencies

struct ChainRegistryClient {
    var listAllChains: @Sendable () async throws -> [Chain]
    var listEnabledChains: @Sendable () async throws -> [Chain]
    var createNewChain: @Sendable (Chain, Bool) async throws -> Chain
    var updateChain: @Sendable (Chain, Bool) async throws -> Chain?
    var batchInsertChains: @Sendable ([Chain]) async throws -> [Chain]
}

extension ChainRegistryClient: DependencyKey {
    static var liveValue: ChainRegistryClient {
        let dataSource = ChainDataSource(dbQueue: DatabaseService.dbQueue)
        return ChainRegistryClient {
            try await dataSource.listChains()
        } listEnabledChains: {
            try await dataSource.listEnabledChains()
        } createNewChain: { chain, enable in
            try await dataSource.save(chain, enable: enable)
        } updateChain: { chain, enable in
            try await dataSource.update(chain, enable: enable)
        } batchInsertChains: { chains in
            try await dataSource.save(chains)
        }
    }

    static var testValue: ChainRegistryClient {
        ChainRegistryClient {
            []
        } listEnabledChains: {
            []
        } createNewChain: { chain, _ in
            chain
        } updateChain: { chain, _ in
            chain
        } batchInsertChains: { chains in
            chains
        }
    }
}

extension DependencyValues {
    var chainRegistry: ChainRegistryClient {
        get { self[ChainRegistryClient.self] }
        set { self[ChainRegistryClient.self] = newValue }
    }
}
