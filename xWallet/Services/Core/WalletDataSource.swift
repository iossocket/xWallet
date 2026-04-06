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
    private let secretDataSource: WalletSecretDataSource

    nonisolated init(dbQueue: DatabaseQueue, securityStore: SecurityStore) {
        self.dbQueue = dbQueue
        self.secretDataSource = WalletSecretDataSource(securityStore: securityStore)
    }
    
    func saveIdentity(_ identity: WalletIdentity) throws {
        try dbQueue.write { db in
            try WalletIdentityRecord(
                id: identity.id.uuidString,
                name: identity.name,
                sourceType: identity.sourceType.rawValue,
                chainType: identity.accountType.chainType.rawValue,
                createdAt: identity.createdAt.timeIntervalSince1970,
                isActive: false,
                chainId: identity.chainId,
                starknetAccountType: identity.accountType.starknetAccountType?.rawValue
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
                guard let accountType = AccountType(rawValue: record.chainType, subtype: record.starknetAccountType) else {
                    throw WalletError.chainMismatch
                }
                return WalletIdentity(
                    id: UUID(uuidString: record.id)!,
                    name: record.name,
                    sourceType: WalletIdentity.SourceType(rawValue: record.sourceType)!,
                    accountType: accountType,
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

    func setActiveWallet(_ id: UUID) throws -> WalletIdentity? {
        try dbQueue.write { db in
            guard let record = try WalletIdentityRecord.filter(Column("id") == id.uuidString).fetchOne(db) else {
                return nil
            }
            try WalletIdentityRecord
                .filter(Column("chainType") == record.chainType)
                .updateAll(db, Column("isActive").set(to: false))
            try WalletIdentityRecord
                .filter(Column("id") == id.uuidString)
                .updateAll(db, Column("isActive").set(to: true))
            
            let addresses = try DerivedAddressRecord
                .filter(Column("walletId") == record.id)
                .fetchAll(db)
                .map { DerivedAddress(
                    chain: ChainType(rawValue: $0.chain)!,
                    path: $0.path,
                    address: $0.address
                )}
            
            guard let accountType = AccountType(rawValue: record.chainType, subtype: record.starknetAccountType) else {
                throw WalletError.chainMismatch
            }
            
            return WalletIdentity(
                id: UUID(uuidString: record.id)!,
                name: record.name,
                sourceType: WalletIdentity.SourceType(rawValue: record.sourceType)!,
                accountType: accountType,
                createdAt: Date(timeIntervalSince1970: record.createdAt),
                chainId: record.chainId,
                derivedAddresses: addresses
            )
        }
    }
    
    func activeIdentitySet() throws -> ActiveWalletIdentitySet {
        try dbQueue.read { db in
            let records = try WalletIdentityRecord
                .filter(Column("isActive") == true)
                .fetchAll(db)
            var evm: WalletIdentity? = nil
            var starknet: WalletIdentity? = nil
            for record in records {
                let addresses = try DerivedAddressRecord
                    .filter(Column("walletId") == record.id)
                    .fetchAll(db)
                    .map { DerivedAddress(
                        chain: ChainType(rawValue: $0.chain)!,
                        path: $0.path,
                        address: $0.address
                    )}
                guard let accountType = AccountType(rawValue: record.chainType, subtype: record.starknetAccountType) else {
                    throw WalletError.chainMismatch
                }
                let identity = WalletIdentity(
                    id: UUID(uuidString: record.id)!,
                    name: record.name,
                    sourceType: WalletIdentity.SourceType(rawValue: record.sourceType)!,
                    accountType: accountType,
                    createdAt: Date(timeIntervalSince1970: record.createdAt),
                    chainId: record.chainId,
                    derivedAddresses: addresses
                )
                switch identity.accountType.chainType {
                case .evm: evm = identity
                case .starknet: starknet = identity
                }
            }
            
            return ActiveWalletIdentitySet(evm: evm, starknet: starknet)
        }
    }

    func saveSecret(_ source: WalletSource, for id: UUID) throws {
        try secretDataSource.saveSecret(source, for: id)
    }

    func loadSecret(for id: UUID) throws -> WalletSource {
        try secretDataSource.loadSecret(for: id)
    }

    func deleteSecret(for id: UUID) throws {
        try secretDataSource.deleteSecret(for: id)
    }
}
