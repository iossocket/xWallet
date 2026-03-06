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
    var listAllChains: @Sendable () async throws -> [EvmChainRecord]
    var listEnabledChains: @Sendable () async throws -> [EvmChainRecord]
    var createNewChain: @Sendable (EvmChainRecord, Bool) async throws -> EvmChainRecord
    var updateChain: @Sendable (EvmChainRecord, Bool) async throws -> EvmChainRecord?
    var batchInsertChains: @Sendable ([EvmChainRecord]) async throws -> [EvmChainRecord]
}

extension ChainRegistryClient: DependencyKey {
    static var liveValue: ChainRegistryClient {
        let chainStorage = ChainStorage(dbQueue: LocalStorage.dbQueue)
        return ChainRegistryClient {
            try await chainStorage.listChains()
        } listEnabledChains: {
            try await chainStorage.listEnabledChains()
        } createNewChain: { evmChain, enable in
            try await chainStorage.save(evmChain, enable: enable)
        } updateChain: { evmChain, enable in
            try await chainStorage.update(evmChain, enable: enable)
        } batchInsertChains: { chains in
            try await chainStorage.save(chains)
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


private actor ChainStorage {
    private let dbQueue: DatabaseQueue
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }
    
    func listChains() async throws -> [EvmChainRecord] {
        try await dbQueue.read { db in
            try EvmChainRecord.fetchAll(db)
        }
    }

    func listEnabledChains() async throws -> [EvmChainRecord] {
        try await dbQueue.read { db in
            try EvmChainRecord
                .filter(Column("enabled") == true)
                .fetchAll(db)
        }
    }
    
    func save(_ chain: EvmChainRecord, enable: Bool) async throws -> EvmChainRecord {
        try await dbQueue.write { db in
            let record = EvmChainRecord(
                id: chain.id,
                chainId: chain.chainId,
                name: chain.name,
                rpcURL: chain.rpcURL,
                isTestnet: chain.isTestnet,
                symbol: chain.symbol,
                decimals: chain.decimals,
                explorerURL: chain.explorerURL,
                enabled: enable
            )
            try record.save(db)
            return record
        }
    }
    
    func save(_ chains: [EvmChainRecord]) async throws -> [EvmChainRecord] {
        try await dbQueue.write { db in
            for chain in chains {
                try chain.insert(db)
            }
            return chains
        }
    }
    
    func update(_ chain: EvmChainRecord, enable: Bool) async throws -> EvmChainRecord? {
        try await dbQueue.write { db -> EvmChainRecord? in
            guard var record = try EvmChainRecord
                .filter(Column("id") == chain.id)
                .fetchOne(db) else { return nil }

            record = EvmChainRecord(
                id: chain.id,
                chainId: chain.chainId,
                name: chain.name,
                rpcURL: chain.rpcURL,
                isTestnet: chain.isTestnet,
                symbol: chain.symbol,
                decimals: chain.decimals,
                explorerURL: chain.explorerURL,
                enabled: enable
            )
            try record.update(db)
            return record
        }
    }
}
