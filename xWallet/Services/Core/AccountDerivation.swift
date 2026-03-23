//
//  AccountDerivation.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import EthereumKit
import StarknetKit
import MultiChainCore

struct EvmAccountDerivation {
    static func deriveFromMnemonic(_ mnemonic: String) throws -> DerivedAddress {
        let account = try EthereumAccount(mnemonic: mnemonic, path: .ethereum)
        return DerivedAddress(
            chain: .evm,
            path: "m/44'/60'/0'/0/0",
            address: account.address.checksummed
        )
    }
    
    static func deriveFromPrivateKey(_ data: Data) throws -> DerivedAddress {
        let account = try EthereumAccount(privateKey: data)
        return DerivedAddress(chain: .evm, path: "", address: account.address.checksummed)
    }
}

struct StarknetAccountDerivation {
    static func deriveFromMnemonic(_ mnemonic: String, accountType: StarknetAccountType) throws -> DerivedAddress {
        let seed = try BIP39.seed(from: mnemonic, password: "")
        let privateKey = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: DerivationPath.starknet)
        guard let publicKey = try? StarkCurve.getPublicKey(privateKey: privateKey) else {
            throw CryptoError.publicKeyDerivationFailed
        }
        
        let address: StarknetAddress
        switch accountType {
        case .oz:
            address = try OpenZeppelinAccount().computeAddress(publicKey: publicKey, salt: publicKey)
        case .argent:
            address = try ArgentAccount().computeAddress(publicKey: publicKey, salt: publicKey)
        }
        
        return DerivedAddress(
            chain: .starknet,
            path: "m/44'/9004'/0'/0/0",
            address: address.checksummed
        )
    }
    
    static func deriveFromPrivateKey(_ data: Data, accountType: StarknetAccountType) throws -> DerivedAddress {
        guard let publicKey = try? StarkCurve.getPublicKey(privateKey: Felt(data)) else {
            throw CryptoError.publicKeyDerivationFailed
        }
        
        let address: StarknetAddress
        switch accountType {
        case .oz:
            address = try OpenZeppelinAccount().computeAddress(publicKey: publicKey, salt: publicKey)
        case .argent:
            address = try ArgentAccount().computeAddress(publicKey: publicKey, salt: publicKey)
        }
        
        return DerivedAddress(
            chain: .starknet,
            path: "m/44'/9004'/0'/0/0",
            address: address.checksummed
        )
    }
}
