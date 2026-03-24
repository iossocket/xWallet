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


enum StarknetChainId: String, Codable, Equatable, Sendable {
    case mainnet = "SN_MAIN"
    case sepolia = "SN_SEPOLIA"
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
        if identity.chainType == .evm {
            evm = identity
        } else if identity.chainType == .starknet {
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
