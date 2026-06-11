//
//  ChainDataSource.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import GRDB
import Foundation
import ComposableArchitecture

@DependencyClient
struct ChainDataSource {
    var listChains: () async throws -> [Chain]
    var listEnabledChains: () async throws -> [Chain]
    var saveChain: (Chain, Bool) async throws -> Chain
    var saveChains: ([Chain]) async throws -> [Chain]
    var update: (Chain, Bool) async throws -> Chain?
    var saveToken: (Token) async throws -> Token
    var listTokens: (Chain) async throws -> [Token]
}

extension ChainDataSource: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.databaseStore) var databaseStore
        let dbQueue = databaseStore.dbQueue()
        return ChainDataSource {
            try await dbQueue.read { db in
                try Chain.fetchAll(db)
            }
        } listEnabledChains: {
            try await dbQueue.read { db in
                try Chain
                    .filter(Column("enabled") == true)
                    .fetchAll(db)
            }
        } saveChain: { chain, enable in
            try await dbQueue.write { db in
                let record = Chain(
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
        } saveChains: { chains in
            try await dbQueue.write { db in
                for chain in chains {
                    try chain.insert(db)
                }
                return chains
            }
        } update: { chain, enable in
            try await dbQueue.write { db -> Chain? in
                guard var record = try Chain
                    .filter(Column("id") == chain.id)
                    .fetchOne(db) else { return nil }

                record = Chain(
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
        } saveToken: { token in
            try await dbQueue.write { db in
                guard try Chain.fetchOne(db, key: token.chainFK) != nil else {
                    throw DatabaseError(message: "Chain not found")
                }
                
                try token.save(db)
                return token
            }
        } listTokens: { chain in
            try await dbQueue.read { db in
                try Token
                    .filter(Column("chainFK") == chain.id)
                    .fetchAll(db)
            }
        }
    }
}

extension DependencyValues {
    var chainDataSource: ChainDataSource {
        get { self[ChainDataSource.self] }
        set { self[ChainDataSource.self] = newValue }
    }
}
