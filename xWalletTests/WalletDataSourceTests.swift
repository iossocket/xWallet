//
//  WalletDataSourceTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 4/3/26.
//

import Foundation
import GRDB
import ComposableArchitecture
import Testing

@testable import xWallet

struct WalletDataSourceTests {
    @Test
    func loadSecretPrefersMnemonicWhenMnemonicAndPrivateKeyBothExist() throws {
        let box = InMemoryKeychain()
        try withDependencies {
            $0.keychainStore = .inMemory(box)
        } operation: {
            let repo = WalletSecretRepository.liveValue
            let walletId = UUID()
            let mnemonic = "test test test test test test test test test test test junk"
            let privateKey = Data([0x01, 0x02, 0x03, 0x04])

            try repo.saveSecret(source: .mnemonic(mnemonic), id: walletId)
            try repo.saveSecret(source: .privateKey(privateKey, .evm), id: walletId)

            let secret = try repo.loadSecret(id: walletId, reason: "")

            #expect(secret == .mnemonic(mnemonic))
        }
    }

    @Test
    func loadSecretReturnsPrivateKeyWithOriginalAccountType() throws {
        let box = InMemoryKeychain()
        try withDependencies {
            $0.keychainStore = .inMemory(box)
        } operation: {
            let repo = WalletSecretRepository.liveValue
            let walletId = UUID()
            let privateKey = Data([0xAB, 0xCD, 0xEF])

            try repo.saveSecret(source: .privateKey(privateKey, .starknet(.argent)), id: walletId)

            let secret = try repo.loadSecret(id: walletId, reason: "")

            #expect(secret == .privateKey(privateKey, .starknet(.argent)))
        }
    }

    @Test
    func loadSecretSupportsLegacyMnemonicPayloadStoredUnderWalletKey() throws {
        let box = InMemoryKeychain()
        let walletId = UUID()
        let mnemonic = "legacy test test test test test test test test test test test"

        box.storage[Self.privateKeyAccount(for: walletId)] = try JSONEncoder().encode([
            "type": "mnemonic",
            "value": mnemonic
        ])

        try withDependencies {
            $0.keychainStore = .inMemory(box)
        } operation: {
            let repo = WalletSecretRepository.liveValue
            let secret = try repo.loadSecret(id: walletId, reason: "")

            #expect(secret == .mnemonic(mnemonic))
        }
    }

    @Test
    func deleteSecretDeletesBothSecretKeysAndIgnoresMissingItems() throws {
        let box = InMemoryKeychain()
        try withDependencies {
            $0.keychainStore = .inMemory(box)
        } operation: {
            let repo = WalletSecretRepository.liveValue
            let walletId = UUID()

            try repo.saveSecret(source: .mnemonic("test test test test test test test test test test test junk"), id: walletId)
            try repo.saveSecret(source: .privateKey(Data([0x10, 0x20]), .evm), id: walletId)

            try repo.deleteSecret(id: walletId)

            #expect(box.storage.isEmpty)
            #expect(Set(box.deletedAccounts) == Set([
                Self.privateKeyAccount(for: walletId),
                Self.mnemonicAccount(for: walletId),
            ]))

            try repo.deleteSecret(id: walletId)

            #expect(box.deletedAccounts.count == 4)
        }
    }

    @Test
    func setActiveWalletDeactivatesOnlyWalletsOnSameChainType() throws {
        let repo = try Self.makeWalletRepository()
        let evmWallet1 = Self.makeIdentity(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            name: "EVM Wallet 1",
            accountType: .evm
        )
        let evmWallet2 = Self.makeIdentity(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            name: "EVM Wallet 2",
            accountType: .evm
        )
        let starknetWallet = Self.makeIdentity(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
            name: "Starknet Wallet",
            accountType: .starknet(.oz),
            chainId: StarknetChainId.sepolia.rawValue
        )

        try repo.saveIdentity(evmWallet1)
        try repo.saveIdentity(evmWallet2)
        try repo.saveIdentity(starknetWallet)

        let firstActiveWallet = try repo.setActiveWallet(evmWallet1.id)
        let activeStarknetWallet = try repo.setActiveWallet(starknetWallet.id)
        let finalActiveWallet = try repo.setActiveWallet(evmWallet2.id)

        _ = try #require(firstActiveWallet)
        _ = try #require(activeStarknetWallet)
        let activatedWallet = try #require(finalActiveWallet)

        #expect(activatedWallet.id == evmWallet2.id)

        let activeSet = try repo.activeIdentitySet()
        #expect(activeSet.evm?.id == evmWallet2.id)
        #expect(activeSet.starknet?.id == starknetWallet.id)
    }
}

private extension WalletDataSourceTests {
    static func makeWalletRepository() throws -> WalletRepository {
        let dbQueue = try DatabaseQueue(path: ":memory:")
        try dbQueue.write { db in
            try db.create(table: "wallet_identity") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("sourceType", .text).notNull()
                table.column("chainType", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.column("isActive", .boolean).notNull().defaults(to: false)
                table.column("chainId", .text)
                table.column("starknetAccountType", .text)
            }

            try db.create(table: "derived_address") { table in
                table.column("walletId", .text).notNull()
                    .references("wallet_identity", onDelete: .cascade)
                table.column("chain", .text).notNull()
                table.column("path", .text).notNull().defaults(to: "")
                table.column("address", .text).notNull()
                table.primaryKey(["walletId", "chain", "path"])
            }
        }

        return withDependencies {
            $0.databaseStore.dbQueue = { dbQueue }
        } operation: {
            WalletRepository.liveValue
        }
    }

    static func makeIdentity(
        id: UUID,
        name: String,
        accountType: AccountType,
        chainId: String? = nil
    ) -> WalletIdentity {
        let chainType = accountType.chainType
        let path = switch chainType {
        case .evm: "m/44'/60'/0'/0/0"
        case .starknet: "m/44'/9004'/0'/0/0"
        }

        return WalletIdentity(
            id: id,
            name: name,
            sourceType: .mnemonic,
            accountType: accountType,
            createdAt: Date(),
            chainId: chainId,
            derivedAddresses: [
                DerivedAddress(
                    chain: chainType,
                    path: path,
                    address: "address-\(id.uuidString.lowercased())"
                )
            ]
        )
    }

    static func privateKeyAccount(for id: UUID) -> String {
        "wallet_\(id.uuidString)"
    }

    static func mnemonicAccount(for id: UUID) -> String {
        "wallet_mnemonic_\(id.uuidString)"
    }
}

private final class InMemoryKeychain {
    var storage: [String: Data] = [:]
    var deletedAccounts: [String] = []
}

private extension KeychainStore {
    static func inMemory(_ box: InMemoryKeychain) -> KeychainStore {
        KeychainStore(
            saveData: { data, account, _ in
                box.storage[account] = data
            },
            loadData: { account, _, _ in
                guard let data = box.storage[account] else {
                    throw KeychainError.itemNotFound
                }
                return data
            },
            delete: { account in
                box.deletedAccounts.append(account)
                guard box.storage.removeValue(forKey: account) != nil else {
                    throw KeychainError.itemNotFound
                }
            },
            deleteAll: {
                box.deletedAccounts.append(contentsOf: box.storage.keys)
                box.storage.removeAll()
            }
        )
    }
}
