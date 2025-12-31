//
//  WalletCoreValidator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import Foundation
import WalletCore

struct WalletCoreValidator {
    static func runQuickCheck() {
        print("--------------- 🚀 WalletCore ---------------")
        
        // 1. Verify: Try to generate a new HD wallet (12-word mnemonic)
        // This tests if the underlying entropy generation and C++ bridging are working correctly
        guard let wallet = HDWallet(strength: 128, passphrase: "") else {
            print("Failed to create HDWallet instance. WalletCore may not be properly linked.")
            return
        }
        
        print("HDWallet initialized successfully")
        
        // 2. Verify: Get mnemonic
        // Ensure string encoding conversion is working correctly
        let mnemonic = wallet.mnemonic
        print("Generated mnemonic: \(mnemonic)")
        
        // 3. Verify: Generate Ethereum address
        // This tests the key derivation logic for specific chains (BIP44)
        let ethAddress = wallet.getAddressForCoin(coin: .ethereum)
        print("Derived ETH address: \(ethAddress)")
        
        // 4. Verify: Generate Bitcoin address
        let btcAddress = wallet.getAddressForCoin(coin: .bitcoin)
        print("Derived BTC address: \(btcAddress)")
        
        // 5. Verify: Private key generation
        // Get ETH private key data
        let ethPrivateKey = wallet.getKeyForCoin(coin: .ethereum)
        let ethPrivateKeyData = ethPrivateKey.data
        print("🔐 ETH private key length: \(ethPrivateKeyData.count) bytes (expected 32)")
        
        if ethPrivateKeyData.count == 32 && !ethAddress.isEmpty {
            print("--------------- 🎉 Verification passed: Integration successful ---------------")
        } else {
            print("--------------- ⚠️ Verification warning: Data appears incomplete ---------------")
        }
    }
}
