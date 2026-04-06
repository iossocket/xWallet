//
//  Wallet.swift
//  xWallet
//
//  Created by Xueliang Zhu on 28/2/26.
//

import Foundation
import GRDB
import StarknetKit

enum ChainType: String, Codable, Equatable, Sendable {
    case evm
    case starknet
}

enum StarknetAccountType: String, Codable, Equatable, Sendable {
    case oz
    case argent
}

enum AccountType: Codable, Equatable, Sendable {
    case evm
    case starknet(StarknetAccountType)

    var chainType: ChainType {
        switch self {
        case .evm: return .evm
        case .starknet: return .starknet
        }
    }

    var starknetAccountType: StarknetAccountType? {
        switch self {
        case .evm: return nil
        case .starknet(let type): return type
        }
    }

    var rawValue: String {
        chainType.rawValue
    }
}

extension AccountType {
    init?(rawValue: String, subtype: String? = nil) {
        switch rawValue {
        case "evm":
            self = .evm
        case "starknet":
            guard let subtype,
                  let starknetType = StarknetAccountType(rawValue: subtype) else {
                return nil
            }
            self = .starknet(starknetType)
        default:
            return nil
        }
    }
}


enum StarknetChainId: String, Codable, Equatable, Sendable {
    case mainnet = "SN_MAIN"
    case sepolia = "SN_SEPOLIA"
}

enum WalletSource: Equatable, Sendable {
    case mnemonic(String)
    case privateKey(Data, AccountType)
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
    let accountType: AccountType
    let createdAt: Date
    var chainId: String?
    var derivedAddresses: [DerivedAddress]

    enum SourceType: String, Codable, Sendable {
        case mnemonic
        case privateKey
    }

    var primaryAddress: String? {
        derivedAddresses.first?.address
    }
}

struct ActiveWalletIdentitySet: Equatable, Sendable {
    var evm: WalletIdentity?
    var starknet: WalletIdentity?
    
    var isEmpty: Bool {
        return evm == nil && starknet == nil
    }
    
    mutating func updateIdentity(identity: WalletIdentity?) {
        guard let identity = identity else {
            return
        }
        switch identity.accountType.chainType {
        case .evm:
            evm = identity
        case .starknet:
            starknet = identity
        }
    }
    
    mutating func clear() {
        evm = nil
        starknet = nil
    }
    
    func contains(identityId: UUID) -> Bool {
        if isEmpty {
            return false
        }
        
        if let evm = evm, evm.id == identityId {
            return true
        }
        
        if let starknet = starknet, starknet.id == identityId {
            return true
        }
        
        return false
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
    var chainId: String?
    var starknetAccountType: String?
}

struct DerivedAddressRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "derived_address"

    let walletId: String
    let chain: String
    let path: String
    let address: String
}

extension WalletIdentityRecord {
    func toWalletIdentity() {
        return 
    }
}
