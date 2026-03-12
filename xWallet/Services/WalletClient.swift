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
        let store = WalletDataSource(dbQueue: LocalStorage.dbQueue, securityStore: KeychainService())
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
                try store.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try store.saveIdentity(identity)
                try store.setActiveWallet(identity.id)
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
                try store.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try store.saveIdentity(identity)
                try store.setActiveWallet(identity.id)
                return identity
            },
            importPrivateKey: { hex, name, chain in
                let pkData = try PrivateKeyUtils.normalizePrivateKey(hex: hex)
                let address = try deriveAddressFromPrivateKey(pkData, chain: chain)
                // same private key will generate multipy same records
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(chain: chain),
                    sourceType: .privateKey,
                    chainType: chain,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.privateKey(pkData, chain), for: identity.id)
                try store.saveIdentity(identity)
                try store.setActiveWallet(identity.id)
                return identity
            },
            listWallets: {
                try store.listIdentities()
            },
            switchWallet: { id in
                try store.setActiveWallet(id)
            },
            activeEvmAccount: { provider in
                let identity = try store.activeIdentity()
                guard identity.chainType == .evm else {
                    throw WalletError.chainMismatch
                }
                let secret = try store.loadSecret(for: identity.id)
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
                let identity = try store.activeIdentity()
                guard identity.chainType == .starknet else {
                    throw WalletError.chainMismatch
                }
                let secret = try store.loadSecret(for: identity.id)
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
                try store.activeIdentity()
            },
            deleteWallet: { id in
                try store.deleteSecret(for: id)
                try store.deleteIdentity(id)
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

enum WalletError: Error {
    case invalidMnemonic
    case invalidPrivateKey
    case notFound
    case chainMismatch
    case encodingFailed
    case decodingFailed
    case noActiveIdentity
}
