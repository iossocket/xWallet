//
//  EvmChainPresets.swift
//  xWallet
//
//  Created by Xueliang Zhu on 5/3/26.
//

import EthereumKit
import Foundation

enum EvmChainPresets {
    static let allPresets: [EvmChain] = [
        .mainnet,
        .sepolia,
        .polygon,
        .base,
        .bsc,
    ]

    /// Returns preset chains with enabled status
    /// Mainnet and Sepolia are enabled by default
    static func presetsWithEnabledStatus() -> [EvmChainRecord] {
        allPresets.map { chain in
            let isEnabled = chain.chainId == 1 || chain.chainId == 11_155_111  // Mainnet or Sepolia
            return EvmChainRecord(
                id: chain.id,
                chainId: chain.chainId,
                name: chain.name,
                rpcURL: chain.rpcURL.absoluteString,
                isTestnet: chain.isTestnet,
                symbol: chain.symbol,
                decimals: chain.decimals,
                explorerURL: chain.explorerURL?.absoluteString,
                enabled: isEnabled
            )
        }
    }
}
