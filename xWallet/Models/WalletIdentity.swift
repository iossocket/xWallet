//
//  Wallet.swift
//  xWallet
//
//  Created by Xueliang Zhu on 28/2/26.
//

import Foundation
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
