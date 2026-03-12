//
//  ChainDataSource.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import GRDB
import Foundation

struct ChainDataSource {
    private let dbQueue: DatabaseQueue
    
    func listChains() async throws -> [Chain] {
        try await dbQueue.read { db in
            try Chain.fetchAll(db)
        }
    }

    func listEnabledChains() async throws -> [Chain] {
        try await dbQueue.read { db in
            try Chain
                .filter(Column("enabled") == true)
                .fetchAll(db)
        }
    }
    
    func save(_ chain: Chain, enable: Bool) async throws -> Chain {
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
    }
    
    func save(_ chains: [Chain]) async throws -> [Chain] {
        try await dbQueue.write { db in
            for chain in chains {
                try chain.insert(db)
            }
            return chains
        }
    }
    
    func update(_ chain: Chain, enable: Bool) async throws -> Chain? {
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
    }
    
    func save(_ token: Token) async throws -> Token {
        try await dbQueue.write { db in
            guard try Chain.fetchOne(db, key: token.chainFK) != nil else {
                throw DatabaseError(message: "Chain not found")
            }
            
            try token.save(db)
            return token
        }
    }
    
    func listTokens(by chain: Chain) async throws -> [Token] {
        try await dbQueue.read { db in
            try Token
                .filter(Column("chainFK") == chain.id)
                .fetchAll(db)
        }
    }
}
