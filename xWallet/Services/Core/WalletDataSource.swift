//
//  WalletDataSource.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import GRDB
import Foundation

struct WalletDataSource {
    private let dbQueue: DatabaseQueue
    private let securityStore: SecurityStore
    
    nonisolated init(dbQueue: DatabaseQueue, securityStore: SecurityStore) {
        self.dbQueue = dbQueue
        self.securityStore = securityStore
    }
    
    func saveIdentity(_ identity: WalletIdentity) throws {
        try dbQueue.write { db in
            try WalletIdentityRecord(
                id: identity.id.uuidString,
                name: identity.name,
                sourceType: identity.sourceType.rawValue,
                chainType: identity.chainType.rawValue,
                createdAt: identity.createdAt.timeIntervalSince1970,
                isActive: false,
                chainId: identity.chainId
            ).insert(db)

            for addr in identity.derivedAddresses {
                try DerivedAddressRecord(
                    walletId: identity.id.uuidString,
                    chain: addr.chain.rawValue,
                    path: addr.path,
                    address: addr.address
                ).insert(db)
            }
        }
    }
    
    func listIdentities() throws -> [WalletIdentity] {
        try dbQueue.read { db in
            let records = try WalletIdentityRecord
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return try records.map { record in
                let addresses = try DerivedAddressRecord
                    .filter(Column("walletId") == record.id)
                    .fetchAll(db)
                    .map { DerivedAddress(
                        chain: ChainType(rawValue: $0.chain)!,
                        path: $0.path,
                        address: $0.address
                    )}
                return WalletIdentity(
                    id: UUID(uuidString: record.id)!,
                    name: record.name,
                    sourceType: WalletIdentity.SourceType(rawValue: record.sourceType)!,
                    chainType: ChainType(rawValue: record.chainType)!,
                    createdAt: Date(timeIntervalSince1970: record.createdAt),
                    chainId: record.chainId,
                    derivedAddresses: addresses
                )
            }
        }
    }

    func deleteIdentity(_ id: UUID) throws {
        try dbQueue.write { db in
            _ = try WalletIdentityRecord.deleteOne(db, key: id.uuidString)
        }
    }

    func setActiveWallet(_ id: UUID) throws {
        try dbQueue.write { db in
            try WalletIdentityRecord
                .updateAll(db, Column("isActive").set(to: false))
            try WalletIdentityRecord
                .filter(Column("id") == id.uuidString)
                .updateAll(db, Column("isActive").set(to: true))
        }
    }
    
    func saveIdentityAndActiveWallet(_ identity: WalletIdentity) throws {
        try dbQueue.write { db in
            try WalletIdentityRecord(
                id: identity.id.uuidString,
                name: identity.name,
                sourceType: identity.sourceType.rawValue,
                chainType: identity.chainType.rawValue,
                createdAt: identity.createdAt.timeIntervalSince1970,
                isActive: false,
                chainId: identity.chainId
            ).insert(db)

            for addr in identity.derivedAddresses {
                try DerivedAddressRecord(
                    walletId: identity.id.uuidString,
                    chain: addr.chain.rawValue,
                    path: addr.path,
                    address: addr.address
                ).insert(db)
            }
            
            try WalletIdentityRecord
                .updateAll(db, Column("isActive").set(to: false))
            try WalletIdentityRecord
                .filter(Column("id") == identity.id.uuidString)
                .updateAll(db, Column("isActive").set(to: true))
        }
    }
    
    func activeIdentity() throws -> WalletIdentity {
        try dbQueue.read { db in
            guard let record = try WalletIdentityRecord
                .filter(Column("isActive") == true)
                .fetchOne(db) else {
                throw WalletError.notFound
            }
            let addresses = try DerivedAddressRecord
                .filter(Column("walletId") == record.id)
                .fetchAll(db)
                .map { DerivedAddress(
                    chain: ChainType(rawValue: $0.chain)!,
                    path: $0.path,
                    address: $0.address
                )}
            return WalletIdentity(
                id: UUID(uuidString: record.id)!,
                name: record.name,
                sourceType: WalletIdentity.SourceType(rawValue: record.sourceType)!,
                chainType: ChainType(rawValue: record.chainType)!,
                createdAt: Date(timeIntervalSince1970: record.createdAt),
                chainId: record.chainId,
                derivedAddresses: addresses
            )
        }
    }

    func saveSecret(_ source: WalletSource, for id: UUID) throws {
        let key = "wallet_\(id.uuidString)"
        let data: Data
        switch source {
        case .mnemonic(let mnemonic):
            data = try JSONEncoder().encode(["type": "mnemonic", "value": mnemonic])
        case .privateKey(let pkData, let chain):
            data = try JSONEncoder().encode([
                "type": "privateKey",
                "chain": chain.rawValue,
                "value": pkData.base64EncodedString()
            ])
        }
        try securityStore.saveData(data, account: key)
    }

    func loadSecret(for id: UUID) throws -> WalletSource {
        let key = "wallet_\(id.uuidString)"
        let data = try securityStore.loadData(account: key)
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        switch dict["type"] {
        case "mnemonic":
            return .mnemonic(dict["value"]!)
        case "privateKey":
            let chain = ChainType(rawValue: dict["chain"]!)!
            let pkData = Data(base64Encoded: dict["value"]!)!
            return .privateKey(pkData, chain)
        default:
            throw WalletError.decodingFailed
        }
    }

    func deleteSecret(for id: UUID) throws {
        let key = "wallet_\(id.uuidString)"
        try securityStore.delete(account: key)
    }
}
