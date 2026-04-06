//
//  WalletDataSourceTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 4/3/26.
//

import Foundation
import GRDB
import Testing

@testable import xWallet

struct WalletDataSourceTests {
    @Test
    func loadSecretPrefersMnemonicWhenMnemonicAndPrivateKeyBothExist() throws {
        let securityStore = InMemorySecurityStore()
        let dataSource = WalletSecretDataSource(securityStore: securityStore)
        let walletId = UUID()
        let mnemonic = "test test test test test test test test test test test junk"
        let privateKey = Data([0x01, 0x02, 0x03, 0x04])

        try dataSource.saveSecret(.mnemonic(mnemonic), for: walletId)
        try dataSource.saveSecret(.privateKey(privateKey, .evm), for: walletId)

        let secret = try dataSource.loadSecret(for: walletId)

        #expect(secret == .mnemonic(mnemonic))
    }

    @Test
    func loadSecretReturnsPrivateKeyWithOriginalAccountType() throws {
        let securityStore = InMemorySecurityStore()
        let dataSource = WalletSecretDataSource(securityStore: securityStore)
        let walletId = UUID()
        let privateKey = Data([0xAB, 0xCD, 0xEF])

        try dataSource.saveSecret(.privateKey(privateKey, .starknet(.argent)), for: walletId)

        let secret = try dataSource.loadSecret(for: walletId)

        #expect(secret == .privateKey(privateKey, .starknet(.argent)))
    }

    @Test
    func loadSecretSupportsLegacyMnemonicPayloadStoredUnderWalletKey() throws {
        let securityStore = InMemorySecurityStore()
        let dataSource = WalletSecretDataSource(securityStore: securityStore)
        let walletId = UUID()
        let mnemonic = "legacy test test test test test test test test test test test"

        securityStore.storage[Self.privateKeyAccount(for: walletId)] = try JSONEncoder().encode([
            "type": "mnemonic",
            "value": mnemonic
        ])

        let secret = try dataSource.loadSecret(for: walletId)

        #expect(secret == .mnemonic(mnemonic))
    }

    @Test
    func deleteAllDeletesBothSecretKeysAndIgnoresMissingItems() throws {
        let securityStore = InMemorySecurityStore()
        let dataSource = WalletSecretDataSource(securityStore: securityStore)
        let walletId = UUID()

        try dataSource.saveSecret(.mnemonic("test test test test test test test test test test test junk"), for: walletId)
        try dataSource.saveSecret(.privateKey(Data([0x10, 0x20]), .evm), for: walletId)

        try dataSource.deleteAll(for: walletId)

        #expect(securityStore.storage.isEmpty)
        #expect(Set(securityStore.deletedAccounts) == Set([
            Self.privateKeyAccount(for: walletId),
            Self.mnemonicAccount(for: walletId),
        ]))

        try dataSource.deleteAll(for: walletId)

        #expect(securityStore.deletedAccounts.count == 4)
    }

    @Test
    func setActiveWalletDeactivatesOnlyWalletsOnSameChainType() throws {
        let dataSource = try Self.makeWalletDataSource()
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

        try dataSource.saveIdentity(evmWallet1)
        try dataSource.saveIdentity(evmWallet2)
        try dataSource.saveIdentity(starknetWallet)

        let firstActiveWallet = try dataSource.setActiveWallet(evmWallet1.id)
        let activeStarknetWallet = try dataSource.setActiveWallet(starknetWallet.id)
        let finalActiveWallet = try dataSource.setActiveWallet(evmWallet2.id)

        _ = try #require(firstActiveWallet)
        _ = try #require(activeStarknetWallet)
        let activatedWallet = try #require(finalActiveWallet)

        #expect(activatedWallet.id == evmWallet2.id)

        let activeSet = try dataSource.activeIdentitySet()
        #expect(activeSet.evm?.id == evmWallet2.id)
        #expect(activeSet.starknet?.id == starknetWallet.id)
    }
}

private extension WalletDataSourceTests {
    static func makeWalletDataSource() throws -> WalletDataSource {
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

        return WalletDataSource(dbQueue: dbQueue, securityStore: InMemorySecurityStore())
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

private final class InMemorySecurityStore: SecurityStore {
    var storage: [String: Data] = [:]
    var deletedAccounts: [String] = []

    func saveData(_ data: Data, account: String) throws {
        storage[account] = data
    }

    func loadData(account: String) throws -> Data {
        guard let data = storage[account] else {
            throw KeychainError.itemNotFound
        }
        return data
    }

    func delete(account: String) throws {
        deletedAccounts.append(account)
        guard storage.removeValue(forKey: account) != nil else {
            throw KeychainError.itemNotFound
        }
    }

    func deleteAll() throws {
        deletedAccounts.append(contentsOf: storage.keys)
        storage.removeAll()
    }
}
