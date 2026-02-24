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

struct WalletSnapshot: Equatable {
    let mnemonic: String
    let ethereumAddress: String
}

struct WalletClient {
    var createWallet: @Sendable () throws -> WalletSnapshot
    var restoreWallet: @Sendable (String) throws -> WalletSnapshot
    var loadWallet: @Sendable () throws -> WalletSnapshot
    var wallet: @Sendable () throws -> MultiChainWallet
    var deleteWallet: @Sendable () throws -> Void
}

extension WalletClient: DependencyKey {
    static var liveValue: WalletClient {
        // 用 actor 保证线程安全
        let storage = WalletStorage()
        return WalletClient(
            createWallet: {
                let mnemonic = try BIP39.generateMnemonic()
                let wallet = try MultiChainWallet(mnemonic: mnemonic)
                let address = wallet.ethereum.address.checksummed
                let snapshot = WalletSnapshot(mnemonic: mnemonic, ethereumAddress: address)
                try storage.save(snapshot)
                return snapshot
            },
            restoreWallet: { mnemonic in
                guard BIP39.validate(mnemonic) else {
                    throw WalletError.invalidMnemonic
                }
                let wallet = try MultiChainWallet(mnemonic: mnemonic)
                let address = wallet.ethereum.address.checksummed
                let snapshot = WalletSnapshot(mnemonic: mnemonic, ethereumAddress: address)
                try storage.save(snapshot)
                return snapshot
            },
            loadWallet: {
                try storage.load()
            },
            wallet: {
                let snapshot = try storage.load()
                return try MultiChainWallet(mnemonic: snapshot.mnemonic)
            },
            deleteWallet: {
                try storage.delete()
            }
        )
    }

    static var testValue: WalletClient {
        WalletClient(
            createWallet: {
                WalletSnapshot(
                    mnemonic: "test test test test test test test test test test test junk",
                    ethereumAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
                )
            },
            restoreWallet: { _ in
                WalletSnapshot(
                    mnemonic: "test test test test test test test test test test test junk",
                    ethereumAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
                )
            },
            loadWallet: { throw WalletError.notFound },
            wallet: { throw WalletError.notFound },
            deleteWallet: { }
        )
    }
}

extension DependencyValues {
    var walletClient: WalletClient {
        get { self[WalletClient.self] }
        set { self[WalletClient.self] = newValue }
    }
}

private actor WalletStorage {
    private let keychainService = KeychainService()
    private let mnemonicKey = "wallet_mnemonic"
    private let addressKey = "wallet_eth_address"

    func save(_ snapshot: WalletSnapshot) throws {
        guard let mnemonicData = snapshot.mnemonic.data(using: .utf8),
              let addressData = snapshot.ethereumAddress.data(using: .utf8) else {
            throw WalletError.encodingFailed
        }
        try keychainService.saveData(mnemonicData, account: mnemonicKey)
        try keychainService.saveData(addressData, account: addressKey)
    }

    func load() throws -> WalletSnapshot {
        let mnemonicData = try keychainService.loadData(account: mnemonicKey)
        let addressData = try keychainService.loadData(account: addressKey)
        guard let mnemonic = String(data: mnemonicData, encoding: .utf8),
              let address = String(data: addressData, encoding: .utf8) else {
            throw WalletError.decodingFailed
        }
        return WalletSnapshot(mnemonic: mnemonic, ethereumAddress: address)
    }

    func delete() throws {
        try keychainService.delete(account: mnemonicKey)
        try keychainService.delete(account: addressKey)
    }
}

enum WalletError: Error {
    case invalidMnemonic
    case notFound
    case encodingFailed
    case decodingFailed
}
