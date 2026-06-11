//
//  WalletRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import GRDB
import Foundation
import ComposableArchitecture

@DependencyClient
struct WalletRepository {
    var saveIdentity: (WalletIdentity) throws -> Void
    var listIdentities: () throws -> [WalletIdentity]
    var identity: (UUID) throws -> WalletIdentity?
    var deleteIdentity: (UUID) throws -> Void
    var setActiveWallet: (UUID) throws -> WalletIdentity?
    var activeIdentitySet: () throws -> ActiveWalletIdentitySet
    var saveSecret: (WalletSource, UUID) throws -> Void
    var loadSecret: (UUID, String) throws -> WalletSource
    var deleteSecret: (UUID) throws -> Void
    var truncate: () throws -> Void
}

extension WalletRepository: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.databaseStore) var databaseStore
        @Dependency(\.walletSecretRepository) var secret
        let dbQueue = databaseStore.dbQueue()
        return WalletRepository(
            saveIdentity: { identity in
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
            },
            listIdentities: {
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
            },
            identity: { id in
                try dbQueue.read { db in
                    guard let record = try WalletIdentityRecord
                        .filter(Column("id") == id.uuidString)
                        .fetchOne(db) else {
                        return nil
                    }

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
            },
            deleteIdentity: { id in
                try dbQueue.write { db in
                    _ = try WalletIdentityRecord.deleteOne(db, key: id.uuidString)
                }
            },
            setActiveWallet: { id in
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
            },
            activeIdentitySet: {
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
            },
            saveSecret: { source, id in
                try secret.saveSecret(source: source, id: id)
            },
            loadSecret: { id, reason in
                try secret.loadSecret(id: id, reason: reason)
            },
            deleteSecret: { id in
                try secret.deleteSecret(id: id)
            },
            truncate: {
                try dbQueue.write { db in
                    try WalletIdentityRecord.deleteAll(db)
                    try DerivedAddressRecord.deleteAll(db)
                    try secret.deleteAll()
                }
            }
        )
    }
}

extension DependencyValues {
    var walletRepository: WalletRepository {
        get { self[WalletRepository.self] }
        set { self[WalletRepository.self] = newValue }
    }
}
