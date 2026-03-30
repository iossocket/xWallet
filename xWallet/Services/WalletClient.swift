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

enum ChainConfig {
    case evm
    case starknet(accountType: StarknetAccountType, chainId: StarknetChainId)
}

struct WalletClient {
    var createWallet: @Sendable (String?, ChainType) async throws -> WalletIdentity?
    var importMnemonic: @Sendable (String, String?, ChainType) async throws -> WalletIdentity?
    var importPrivateKey: @Sendable (String, String?, ChainConfig) async throws -> WalletIdentity?
    var listWallets: @Sendable () async throws -> [WalletIdentity]
    var switchWallet: @Sendable (UUID) async throws -> WalletIdentity?
    var activeEvmAccount: @Sendable (EthereumProvider) async throws -> EthereumAccount
    var activeStarknetAccount: @Sendable () async throws -> StarknetAccount
    var activeIdentitySet: @Sendable () async throws -> ActiveWalletIdentitySet
    var deleteWallet: @Sendable (UUID) async throws -> Void
}

extension WalletClient: DependencyKey {
    static var liveValue: WalletClient {
        let store = WalletDataSource(dbQueue: LocalStorage.dbQueue, securityStore: KeychainService())
        return WalletClient(
            createWallet: { name, chain in
                let mnemonic = try BIP39.generateMnemonic()
                let (address, pk) = try deriveAddress(mnemonic: mnemonic, chain: chain)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(chain: chain),
                    sourceType: .mnemonic,
                    chainType: chain,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try store.saveSecret(.privateKey(pk, chain), for: identity.id)
                try store.saveIdentity(identity)
                return try store.setActiveWallet(identity.id)
            },
            importMnemonic: { mnemonic, name, chain in
                guard BIP39.validate(mnemonic) else {
                    throw WalletError.invalidMnemonic
                }
                let (address, pk) = try deriveAddress(mnemonic: mnemonic, chain: chain)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(chain: chain),
                    sourceType: .mnemonic,
                    chainType: chain,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try store.saveSecret(.privateKey(pk, chain), for: identity.id)
                try store.saveIdentity(identity)
                return try store.setActiveWallet(identity.id)
            },
            importPrivateKey: { hex, name, config in
                let pkData = try PrivateKeyUtils.normalizePrivateKey(hex: hex)
                switch config {
                case .evm:
                    let address = try deriveAddressFromPrivateKey(pkData, chain: .evm)
                    let identity = WalletIdentity(
                        id: UUID(),
                        name: name ?? defaultWalletName(chain: .evm),
                        sourceType: .privateKey,
                        chainType: .evm,
                        createdAt: Date(),
                        derivedAddresses: [address]
                    )
                    try store.saveSecret(.privateKey(pkData, .evm), for: identity.id)
                    try store.saveIdentity(identity)
                    return try store.setActiveWallet(identity.id)
                case .starknet(let accountType, let chainId):
                    let address = try deriveAddressFromPrivateKey(pkData, chain: .starknet, accountType: accountType)
                    let identity = WalletIdentity(
                        id: UUID(),
                        name: name ?? defaultWalletName(chain: .starknet),
                        sourceType: .privateKey,
                        chainType: .starknet,
                        createdAt: Date(),
                        chainId: chainId.rawValue,
                        derivedAddresses: [address]
                    )
                    try store.saveSecret(.privateKey(pkData, .starknet), for: identity.id)
                    try store.saveIdentity(identity)
                    return try store.setActiveWallet(identity.id)
                }
                
            },
            listWallets: {
                try store.listIdentities()
            },
            switchWallet: { id in
                try store.setActiveWallet(id)
            },
            activeEvmAccount: { provider in
                let identitySet = try store.activeIdentitySet()
                guard let identity = identitySet.evm else {
                    throw WalletError.chainMismatch
                }
                let secret = try store.loadPrivateKey(for: identity.id)
                switch secret {
                case .mnemonic(let mnemonic):
                    return try EthereumAccount(mnemonic: mnemonic, path: .ethereum, provider: provider)
                case .privateKey(let data, _):
                    return try EthereumAccount(privateKey: data, provider: provider)
                }
            },
            activeStarknetAccount: {
                let identitySet = try store.activeIdentitySet()
                guard let identity = identitySet.starknet else {
                    throw WalletError.chainMismatch
                }
                
                let secret = try store.loadPrivateKey(for: identity.id)
                let chain: Starknet = identity.chainId == "SN_MAIN" ? .mainnet : .sepolia
                let provider = StarknetProvider(chain: chain)
                switch secret {
                case .mnemonic(let mnemonic):
                    guard let primaryAddress = identity.primaryAddress, let address = StarknetAddress(primaryAddress) else {
                        throw CryptoError.invalidMnemonic
                    }
                    return try StarknetAccount(mnemonic: mnemonic, path: DerivationPath.starknet, address: address, chain: chain, provider: provider)
                case .privateKey(let data, _):
                    guard let primaryAddress = identity.primaryAddress, let address = StarknetAddress(primaryAddress) else {
                        throw CryptoError.invalidMnemonic
                    }
                    return try StarknetAccount(privateKey: Felt(data), address: address, chain: chain, provider: provider)
                }
            },
            activeIdentitySet: {
                try store.activeIdentitySet()
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
            switchWallet: { _ in nil },
            activeEvmAccount: { _ in throw WalletError.notFound },
            activeStarknetAccount: { throw WalletError.notFound },
            activeIdentitySet: { ActiveWalletIdentitySet(evm: testIdentity) },
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
    private static func deriveAddress(mnemonic: String, chain: ChainType, options: Dictionary<String, String>? = nil) throws -> (DerivedAddress, Data) {
        switch chain {
        case .evm:
            let account = try EthereumAccount(mnemonic: mnemonic, path: .ethereum)
            return (DerivedAddress(
                chain: .evm,
                path: "m/44'/60'/0'/0/0",
                address: account.address.checksummed
            ), account.privateKey)
        case .starknet:
            let seed = try BIP39.seed(from: mnemonic, password: "")
            let privateKey: Felt = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: DerivationPath.starknet)
            guard let publicKey = try? StarkCurve.getPublicKey(privateKey: privateKey) else {
              throw CryptoError.publicKeyDerivationFailed
            }
            guard let options = options, let accountType = options["accountType"] else {
                throw CryptoError.publicKeyDerivationFailed
            }
            switch accountType {
            case "oz":
                let accountType = OpenZeppelinAccount()
                let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
                return (DerivedAddress(
                    chain: .starknet,
                    path: "m/44'/9004'/0'/0/0",
                    address: address.checksummed
                ), privateKey.bigEndianData)
            case "argent":
                let accountType = ArgentAccount()
                let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
                return (DerivedAddress(
                    chain: .starknet,
                    path: "m/44'/9004'/0'/0/0",
                    address: address.checksummed
                ), privateKey.bigEndianData)
            default:
                break
            }
            throw CryptoError.publicKeyDerivationFailed
        }
    }
    
    private static func deriveAddressFromPrivateKey(_ data: Data, chain: ChainType, accountType: StarknetAccountType? = nil) throws -> DerivedAddress {
        switch chain {
        case .evm:
            let account = try EthereumAccount(privateKey: data)
            return DerivedAddress(chain: .evm, path: "", address: account.address.checksummed)
        case .starknet:
            guard let publicKey = try? StarkCurve.getPublicKey(privateKey: Felt(data)) else {
              throw CryptoError.publicKeyDerivationFailed
            }
            
            switch accountType {
            case .oz:
                let accountType = OpenZeppelinAccount()
                let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
                return DerivedAddress(
                    chain: .starknet,
                    path: "m/44'/9004'/0'/0/0",
                    address: address.checksummed
                )
            case .argent:
                let accountType = ArgentAccount()
                let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
                return DerivedAddress(
                    chain: .starknet,
                    path: "m/44'/9004'/0'/0/0",
                    address: address.checksummed
                )
            default:
                break
            }
            throw CryptoError.publicKeyDerivationFailed
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
