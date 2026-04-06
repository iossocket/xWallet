//
//  LocalStorage.swift
//  xWallet
//
//  Created by Xueliang Zhu on 5/3/26.
//

import GRDB
import Foundation

@globalActor
actor DatabaseActor: GlobalActor {
    static let shared = DatabaseActor()
}

enum DatabaseService {
    static let dbQueue: DatabaseQueue = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("wallets.sqlite3").path
        let dbQueue = try! DatabaseQueue(path: path)
        try! Self.migrator.migrate(dbQueue)
        return dbQueue
    }()
    
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "wallet_identity") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("sourceType", .text).notNull()
                t.column("chainType", .text).notNull()
                t.column("createdAt", .double).notNull()
                t.column("isActive", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "derived_address") { t in
                t.column("walletId", .text).notNull()
                    .references("wallet_identity", onDelete: .cascade)
                t.column("chain", .text).notNull()
                t.column("path", .text).notNull().defaults(to: "")
                t.column("address", .text).notNull()
                t.primaryKey(["walletId", "chain", "path"])
            }
        }
        migrator.registerMigration("v2") { db in
            try db.create(table: "evm_chain") { t in
                t.column("id", .text).primaryKey()
                t.column("chainId", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("rpcURL", .text).notNull()
                t.column("isTestnet", .boolean).notNull()
                t.column("symbol", .text).notNull()
                t.column("decimals", .integer).notNull()
                t.column("explorerURL", .text)
                t.column("enabled", .boolean).notNull().defaults(to: true)
            }
        }
        migrator.registerMigration("v3") { db in
            try db.create(table: "chains") { t in
                t.column("id", .text).primaryKey()
                t.column("chainId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("rpcURL", .text).notNull()
                t.column("isTestnet", .boolean).notNull()
                t.column("symbol", .text).notNull()
                t.column("decimals", .integer).notNull()
                t.column("explorerURL", .text)
                t.column("enabled", .boolean).notNull().defaults(to: true)
            }
            try db.create(table: "erc20_tokens") { t in
                t.column("id", .text).primaryKey()
                t.column("chainId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("symbol", .text).notNull()
                t.column("decimals", .integer).notNull()
                t.column("contractAddress", .text).notNull()
                t.column("chainFK", .text)
                    .notNull()
                    .references("chains", onDelete: .cascade)
            }
        }
        migrator.registerMigration("v4") { db in
            try db.alter(table: "wallet_identity") { t in
                t.add(column: "chainId", .text)
            }
        }
        migrator.registerMigration("v5") { db in
            try db.alter(table: "wallet_identity") { t in
                t.add(column: "starknetAccountType", .text)
            }
        }
        return migrator
    }
}

enum LocalStorageError: Error {
    case unknowError
}
