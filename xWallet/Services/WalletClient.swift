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
    var createWallet: @Sendable (String?, AccountType) async throws -> WalletIdentity?
    var importMnemonic: @Sendable (String, String?, AccountType) async throws -> WalletIdentity?
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
        let store = WalletDataSource(dbQueue: DatabaseService.dbQueue, securityStore: KeychainService())
        return WalletClient(
            createWallet: { name, accountType in
                let mnemonic = try BIP39.generateMnemonic()
                let (address, pk) = try AccountDerivationService.deriveAddressFromMnemonic(mnemonic, accountType: accountType)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(accountType: accountType),
                    sourceType: .mnemonic,
                    accountType: accountType,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try store.saveSecret(.privateKey(pk, accountType), for: identity.id)
                try store.saveIdentity(identity)
                return try store.setActiveWallet(identity.id)
            },
            importMnemonic: { mnemonic, name, accountType in
                guard BIP39.validate(mnemonic) else {
                    throw WalletError.invalidMnemonic
                }
                let (address, pk) = try AccountDerivationService.deriveAddressFromMnemonic(mnemonic, accountType: accountType)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(accountType: accountType),
                    sourceType: .mnemonic,
                    accountType: accountType,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.mnemonic(mnemonic), for: identity.id)
                try store.saveSecret(.privateKey(pk, accountType), for: identity.id)
                try store.saveIdentity(identity)
                return try store.setActiveWallet(identity.id)
            },
            importPrivateKey: { hex, name, config in
                let pkData = try PrivateKeyUtils.normalizePrivateKey(hex: hex)
                switch config {
                case .evm:
                    let address = try AccountDerivationService.deriveAddressFromPrivateKey(pkData, accountType: .evm)
                    let identity = WalletIdentity(
                        id: UUID(),
                        name: name ?? defaultWalletName(accountType: .evm),
                        sourceType: .privateKey,
                        accountType: .evm,
                        createdAt: Date(),
                        derivedAddresses: [address]
                    )
                    try store.saveSecret(.privateKey(pkData, .evm), for: identity.id)
                    try store.saveIdentity(identity)
                    return try store.setActiveWallet(identity.id)
                case .starknet(let accountType, let chainId):
                    let address = try AccountDerivationService.deriveAddressFromPrivateKey(pkData, accountType: .starknet(accountType))
                    let type: AccountType = .starknet(accountType)
                    let identity = WalletIdentity(
                        id: UUID(),
                        name: name ?? defaultWalletName(accountType: type),
                        sourceType: .privateKey,
                        accountType: AccountType.starknet(accountType),
                        createdAt: Date(),
                        chainId: chainId.rawValue,
                        derivedAddresses: [address]
                    )
                    try store.saveSecret(.privateKey(pkData, type), for: identity.id)
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
                let secret = try store.loadSecret(for: identity.id)
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

                let secret = try store.loadSecret(for: identity.id)
                let chain: Starknet = identity.chainId == "SN_MAIN" ? .mainnet : .sepolia
                let provider = StarknetProvider(chain: chain)
                guard let snAccountType = identity.accountType.starknetAccountType else {
                    throw WalletError.chainMismatch
                }
                let acctType: any StarknetKit.StarknetAccountType = switch snAccountType {
                case .argent: ArgentAccount()
                case .oz: OpenZeppelinAccount()
                }
                switch secret {
                case .mnemonic(let mnemonic):
                    guard let primaryAddress = identity.primaryAddress, let address = StarknetAddress(primaryAddress) else {
                        throw CryptoError.invalidMnemonic
                    }
                    return try StarknetAccount(mnemonic: mnemonic, path: DerivationPath.starknet, address: address, chain: chain, provider: provider, accountType: acctType)
                case .privateKey(let data, _):
                    guard let primaryAddress = identity.primaryAddress, let address = StarknetAddress(primaryAddress) else {
                        throw CryptoError.invalidMnemonic
                    }
                    return try StarknetAccount(privateKey: Felt(data), address: address, chain: chain, provider: provider, accountType: acctType)
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
            accountType: .evm,
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
    private static func defaultWalletName(accountType: AccountType) -> String {
        switch accountType.chainType {
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
