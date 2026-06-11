//
//  WalletClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 24/2/26.
//

import Foundation
import ComposableArchitecture
import MultiChainKit
import MultiChainCore
import EthereumKit
import GRDB

enum ChainConfig {
    case evm
    case starknet(accountType: StarknetAccountType, chainId: StarknetChainId)
}

@DependencyClient
struct WalletClient {
    var createWallet: @Sendable (String?, AccountType) async throws -> WalletIdentity?
    var importMnemonic: @Sendable (String, String?, AccountType) async throws -> WalletIdentity?
    var importPrivateKey: @Sendable (String, String?, ChainConfig) async throws -> WalletIdentity?
    var listWallets: @Sendable () async throws -> [WalletIdentity]
    var switchWallet: @Sendable (UUID) async throws -> WalletIdentity?
    var activeEvmAccount: @Sendable (EthereumProvider) async throws -> EthereumAccount
    var activeStarknetAccount: @Sendable () async throws -> StarknetAccount
    var starknetAccount: @Sendable (UUID, String) async throws -> StarknetAccount
    var activeIdentitySet: @Sendable () async throws -> ActiveWalletIdentitySet
    var deleteWallet: @Sendable (UUID) async throws -> Void
}

extension WalletClient: DependencyKey {
    static var liveValue: WalletClient {
        @Dependency(\.walletRepository) var store
        return WalletClient(
            createWallet: { name, accountType in
                let mnemonic = try BIP39.generateMnemonic()
                let (address, pk) = try AccountDerivation.deriveAddressFromMnemonic(mnemonic, accountType: accountType)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(accountType: accountType),
                    sourceType: .mnemonic,
                    accountType: accountType,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.mnemonic(mnemonic), identity.id)
                try store.saveSecret(.privateKey(pk, accountType), identity.id)
                try store.saveIdentity(identity)
                return identity
            },
            importMnemonic: { mnemonic, name, accountType in
                guard BIP39.validate(mnemonic) else {
                    throw WalletError.invalidMnemonic
                }
                let (address, pk) = try AccountDerivation.deriveAddressFromMnemonic(mnemonic, accountType: accountType)
                let identity = WalletIdentity(
                    id: UUID(),
                    name: name ?? defaultWalletName(accountType: accountType),
                    sourceType: .mnemonic,
                    accountType: accountType,
                    createdAt: Date(),
                    derivedAddresses: [address]
                )
                try store.saveSecret(.mnemonic(mnemonic), identity.id)
                try store.saveSecret(.privateKey(pk, accountType), identity.id)
                try store.saveIdentity(identity)
                return identity
            },
            importPrivateKey: { hex, name, config in
                let pkData = try PrivateKeyUtils.normalizePrivateKey(hex: hex)
                switch config {
                case .evm:
                    let address = try AccountDerivation.deriveAddressFromPrivateKey(pkData, accountType: AccountType.evm)
                    let identity = WalletIdentity(
                        id: UUID(),
                        name: name ?? defaultWalletName(accountType: .evm),
                        sourceType: .privateKey,
                        accountType: .evm,
                        createdAt: Date(),
                        derivedAddresses: [address]
                    )
                    try store.saveSecret(.privateKey(pkData, .evm), identity.id)
                    try store.saveIdentity(identity)
                    return identity
                case .starknet(let accountType, let chainId):
                    let address = try AccountDerivation.deriveAddressFromPrivateKey(pkData, accountType: .starknet(accountType))
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
                    try store.saveSecret(.privateKey(pkData, type), identity.id)
                    try store.saveIdentity(identity)
                    return identity
                }
            },
            listWallets: {
                try store.listIdentities()
            },
            switchWallet: { id in
                guard let identity = try store.identity(id) else {
                    return nil
                }
                if identity.accountType.chainType == .starknet {
                    let isDeployed = try await isStarknetIdentityDeployed(identity)
                    guard isDeployed else {
                        throw WalletError.starknetAccountNotDeployed
                    }
                }
                return try store.setActiveWallet(id)
            },
            activeEvmAccount: { provider in
                let identitySet = try store.activeIdentitySet()
                guard let identity = identitySet.evm else {
                    throw WalletError.chainMismatch
                }
                let secret = try store.loadSecret(identity.id, "activating ethereum account: \(identity.name)")
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
                return try makeStarknetAccount(identity: identity, store: store, reason: "activating starknet account \(identity.name)")
            },
            starknetAccount: { id, reason in
                guard let identity = try store.identity(id) else {
                    throw WalletError.notFound
                }
                guard identity.accountType.chainType == .starknet else {
                    throw WalletError.chainMismatch
                }
                return try makeStarknetAccount(identity: identity, store: store, reason: reason)
            },
            activeIdentitySet: {
                try store.activeIdentitySet()
            },
            deleteWallet: { id in
                try store.deleteSecret(id)
                try store.deleteIdentity(id)
            }
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
    private static func isStarknetIdentityDeployed(_ identity: WalletIdentity) async throws -> Bool {
        guard let primaryAddress = identity.primaryAddress,
              let strkAddress = StarknetAddress(primaryAddress) else {
            return false
        }
        let chain: Starknet = identity.chainId == StarknetChainId.mainnet.rawValue ? .mainnet : .sepolia
        let provider = StarknetProvider(chain: chain)
        let req = StarknetRequestBuilder.getClassHashAtRequest(address: strkAddress)
        do {
            let _: String = try await provider.send(request: req)
            return true
        } catch {
            return false
        }
    }

    private static func makeStarknetAccount(identity: WalletIdentity, store: WalletRepository, reason: String) throws -> StarknetAccount {
        let secret = try store.loadSecret(identity.id, reason)
        let chain: Starknet = identity.chainId == "SN_MAIN" ? .mainnet : .sepolia
        let provider = StarknetProvider(chain: chain)
        guard let snAccountType = identity.accountType.starknetAccountType else {
            throw WalletError.chainMismatch
        }
        let acctType: any StarknetKit.StarknetAccountType = switch snAccountType {
        case .argent: ArgentAccount()
        case .oz: OpenZeppelinAccount()
        }
        guard let primaryAddress = identity.primaryAddress, let address = StarknetAddress(primaryAddress) else {
            throw CryptoError.invalidMnemonic
        }
        switch secret {
        case .mnemonic(let mnemonic):
            return try StarknetAccount(mnemonic: mnemonic, path: DerivationPath.starknet, address: address, chain: chain, provider: provider, accountType: acctType)
        case .privateKey(let data, _):
            return try StarknetAccount(privateKey: Felt(data), address: address, chain: chain, provider: provider, accountType: acctType)
        }
    }

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
    case starknetAccountNotDeployed
}
