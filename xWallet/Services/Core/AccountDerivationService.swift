//
//  AccountDerivation.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import EthereumKit
import StarknetKit
import MultiChainCore
import Foundation

enum AccountDerivationService {
    static func deriveAddressFromMnemonic(_ mnemonic: String, accountType: AccountType) throws -> (DerivedAddress, Data) {
        switch accountType {
        case .evm:
            let account = try EthereumAccount(mnemonic: mnemonic, path: .ethereum)
            return (DerivedAddress(
                chain: .evm,
                path: "m/44'/60'/0'/0/0",
                address: account.address.checksummed
            ), account.privateKey)
        case .starknet(let starknetAccountType):
            let seed = try BIP39.seed(from: mnemonic, password: "")
            let privateKey: Felt = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: DerivationPath.starknet)
            guard let publicKey = try? StarkCurve.getPublicKey(privateKey: privateKey) else {
              throw CryptoError.publicKeyDerivationFailed
            }
            switch starknetAccountType {
            case .oz:
                let accountType = OpenZeppelinAccount()
                let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
                return (DerivedAddress(
                    chain: .starknet,
                    path: "m/44'/9004'/0'/0/0",
                    address: address.checksummed
                ), privateKey.bigEndianData)
            case .argent:
                let accountType = ArgentAccount()
                let address = try accountType.computeAddress(publicKey: publicKey, salt: publicKey)
                return (DerivedAddress(
                    chain: .starknet,
                    path: "m/44'/9004'/0'/0/0",
                    address: address.checksummed
                ), privateKey.bigEndianData)
            }
        }
    }
    
    static func deriveAddressFromPrivateKey(_ data: Data, accountType: AccountType) throws -> DerivedAddress {
        switch accountType {
        case .evm:
            let account = try EthereumAccount(privateKey: data)
            return DerivedAddress(chain: .evm, path: "", address: account.address.checksummed)
        case .starknet(let starknetAccountType):
            guard let publicKey = try? StarkCurve.getPublicKey(privateKey: Felt(data)) else {
              throw CryptoError.publicKeyDerivationFailed
            }
            
            switch starknetAccountType {
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
            }
        }
    }

}
