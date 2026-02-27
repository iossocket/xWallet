//
//  WalletClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 24/2/26.
//

import Foundation
import Dependencies
import MultiChainKit
import MultiChainCore
import EthereumKit
import GRDB


enum ChainType: String, Codable, Equatable, Sendable {
    case evm
    case starknet
}

enum WalletSource: Equatable, Sendable {
    case mnemonic(String)
    case privateKey(Data, ChainType)
}

struct DerivedAddress: Equatable, Codable, Sendable {
    let chain: ChainType              // .evm / .starknet
    let path: String                  // "m/44'/60'/0'/0/0" when import by pk it will be ""
    let address: String
}

struct WalletIdentity: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var name: String                  // customized name
    let sourceType: SourceType
    let chainType: ChainType
    let createdAt: Date
    var derivedAddresses: [DerivedAddress]

    enum SourceType: String, Codable, Sendable {
        case mnemonic
        case privateKey
    }

    var primaryAddress: String? {
        derivedAddresses.first?.address
    }
}

struct WalletClient {
    var createWallet: @Sendable (String?, ChainType) async throws -> WalletIdentity
    var importMnemonic: @Sendable (String, String?, ChainType) async throws -> WalletIdentity
    var importPrivateKey: @Sendable (String, String?, ChainType) async throws -> WalletIdentity
    var listWallets: @Sendable () async throws -> [WalletIdentity]
    var switchWallet: @Sendable (UUID) async throws -> Void
    var activeEvmAccount: @Sendable (EthereumProvider) async throws -> EthereumSignableAccount
    var activeStarknetAccount: @Sendable () async throws -> StarknetAccount
    var activeIdentity: @Sendable () async throws -> WalletIdentity
    var deleteWallet: @Sendable (UUID) async throws -> Void
}

extension WalletClient: DependencyKey {
    static var liveValue: WalletClient {
        let storage = try! WalletStorage.makeDefault()
        return WalletClient(
            createWallet: { name, chain in
                let mnemonic = try BIP39.generateMnemonic()
                let address = try deriveAddress(mnemonic: mnemonic, chain: chain)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(chain: chain),
                    sourceType: .mnemonic,
                    chainType: chain,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try await storage.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try await storage.saveIdentity(identity)
                try await storage.setActiveWallet(identity.id)
                return identity
            },
            importMnemonic: { mnemonic, name, chain in
                guard BIP39.validate(mnemonic) else {
                    throw WalletError.invalidMnemonic
                }
                let address = try deriveAddress(mnemonic: mnemonic, chain: chain)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(chain: chain),
                    sourceType: .mnemonic,
                    chainType: chain,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try await storage.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try await storage.saveIdentity(identity)
                try await storage.setActiveWallet(identity.id)
                return identity
            },
            importPrivateKey: { hex, name, chain in
                let pkData = try PrivateKeyUtils.normalizePrivateKey(hex: hex)
                let address = try deriveAddressFromPrivateKey(pkData, chain: chain)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(chain: chain),
                    sourceType: .privateKey,
                    chainType: chain,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try await storage.saveSecret(.privateKey(pkData, chain), for: identity.id)
                try await storage.saveIdentity(identity)
                try await storage.setActiveWallet(identity.id)
                return identity
            },
            listWallets: {
                try await storage.listIdentities()
            },
            switchWallet: { id in
                try await storage.setActiveWallet(id)
            },
            activeEvmAccount: { provider in
                let identity = try await storage.activeIdentity()
                guard identity.chainType == .evm else {
                    throw WalletError.chainMismatch
                }
                let secret = try await storage.loadSecret(for: identity.id)
                switch secret {
                case .mnemonic(let mnemonic):
                    let signer = try EthereumSigner(mnemonic: mnemonic, path: .ethereum)
                    return try EthereumSignableAccount(signer, provider: provider)
                case .privateKey(let data, _):
                    let signer = try EthereumSigner(privateKey: data)
                    return try EthereumSignableAccount(signer, provider: provider)
                }
            },
            activeStarknetAccount: {
                let identity = try await storage.activeIdentity()
                guard identity.chainType == .starknet else {
                    throw WalletError.chainMismatch
                }
                let secret = try await storage.loadSecret(for: identity.id)
                switch secret {
                case .mnemonic(let mnemonic):
                    let signer = try StarknetSigner(mnemonic: mnemonic, path: .starknet)
                    guard let pubKey = signer.publicKeyFelt else {
                        throw SignerError.publicKeyDerivationFailed
                    }
                    let accountType = OpenZeppelinAccount()
                    let address = try accountType.computeAddress(publicKey: pubKey, salt: pubKey)
                    return StarknetAccount(signer: signer, address: address, chain: .sepolia)
                case .privateKey(let data, _):
                    let signer = try StarknetSigner(privateKey: data)
                    guard let pubKey = signer.publicKeyFelt else {
                        throw SignerError.publicKeyDerivationFailed
                    }
                    let accountType = OpenZeppelinAccount()
                    let address = try accountType.computeAddress(publicKey: pubKey, salt: pubKey)
                    return StarknetAccount(signer: signer, address: address, chain: .sepolia)
                }
            },
            activeIdentity: {
                try await storage.activeIdentity()
            },
            deleteWallet: { id in
                try await storage.deleteSecret(for: id)
                try await storage.deleteIdentity(id)
            }
        )
    }

    static var testValue: WalletClient {
        let _ = "test test test test test test test test test test test junk"
        let testIdentity = WalletIdentity(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test Wallet",
            sourceType: .mnemonic,
            chainType: .evm,
            createdAt: Date(),
            derivedAddresses: [
                DerivedAddress(
                    chain: .evm,
                    path: "m/44'/60'/0'/0/0",
                    address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
                )
            ]
        )
        return WalletClient(
            createWallet: { _, _ in testIdentity },
            importMnemonic: { _, _, _ in testIdentity },
            importPrivateKey: { _, _, _ in testIdentity },
            listWallets: { [testIdentity] },
            switchWallet: { _ in },
            activeEvmAccount: { _ in throw WalletError.notFound },
            activeStarknetAccount: { throw WalletError.notFound },
            activeIdentity: { testIdentity },
            deleteWallet: { _ in }
        )
    }
}

extension DependencyValues {
    var walletClient: WalletClient {
        get { self[WalletClient.self] }
        set { self[WalletClient.self] = newValue }
    }
}

extension WalletClient {
    private static func deriveAddress(mnemonic: String, chain: ChainType) throws -> DerivedAddress {
        switch chain {
        case .evm:
            let signer = try EthereumSigner(mnemonic: mnemonic, path: .ethereum)
            let account = try EthereumSignableAccount(signer)
            return DerivedAddress(
                chain: .evm,
                path: "m/44'/60'/0'/0/0",
                address: account.address.checksummed
            )
        case .starknet:
            let signer = try StarknetSigner(mnemonic: mnemonic, path: .starknet)
            guard let pubKey = signer.publicKeyFelt else {
                throw SignerError.publicKeyDerivationFailed
            }
            let accountType = OpenZeppelinAccount()
            let address = try accountType.computeAddress(publicKey: pubKey, salt: pubKey)
            return DerivedAddress(
                chain: .starknet,
                path: "m/44'/9004'/0'/0/0",
                address: address.description
            )
        }
    }
    
    private static func deriveAddressFromPrivateKey(_ data: Data, chain: ChainType) throws -> DerivedAddress {
        switch chain {
        case .evm:
            let signer = try EthereumSigner(privateKey: data)
            let account = try EthereumSignableAccount(signer)
            return DerivedAddress(chain: .evm, path: "", address: account.address.checksummed)
        case .starknet:
            let signer = try StarknetSigner(privateKey: data)
            guard let pubKey = signer.publicKeyFelt else {
                throw SignerError.publicKeyDerivationFailed
            }
            let accountType = OpenZeppelinAccount()
            let address = try accountType.computeAddress(publicKey: pubKey, salt: pubKey)
            return DerivedAddress(chain: .starknet, path: "", address: address.description)
        }
    }

    private static func defaultWalletName(chain: ChainType) -> String {
        switch chain {
        case .evm: return "EVM Wallet"
        case .starknet: return "Starknet Wallet"
        }
    }
}

struct WalletIdentityRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "wallet_identity"

    let id: String           // UUID string
    var name: String
    let sourceType: String   // "mnemonic" / "privateKey"
    let chainType: String    // "evm" / "starknet"
    let createdAt: Double    // timeIntervalSince1970
    var isActive: Bool
}

struct DerivedAddressRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "derived_address"

    let walletId: String
    let chain: String
    let path: String
    let address: String
}

private actor WalletStorage {
    private let dbQueue: DatabaseQueue
    private let keychainService = KeychainService()
    
    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    static func makeDefault() throws -> WalletStorage {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("wallets.sqlite3").path
        let dbQueue = try DatabaseQueue(path: path)
        try Self.migrator.migrate(dbQueue)
        return WalletStorage(dbQueue: dbQueue)
    }
    
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
        return migrator
    }
    
    func saveIdentity(_ identity: WalletIdentity) throws {
        try dbQueue.write { db in
            try WalletIdentityRecord(
                id: identity.id.uuidString,
                name: identity.name,
                sourceType: identity.sourceType.rawValue,
                chainType: identity.chainType.rawValue,
                createdAt: identity.createdAt.timeIntervalSince1970,
                isActive: false
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
        try keychainService.saveData(data, account: key)
    }

    func loadSecret(for id: UUID) throws -> WalletSource {
        let key = "wallet_\(id.uuidString)"
        let data = try keychainService.loadData(account: key)
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
        try keychainService.delete(account: key)
    }
}

enum WalletError: Error {
    case invalidMnemonic
    case invalidPrivateKey
    case notFound
    case chainMismatch
    case encodingFailed
    case decodingFailed
}
