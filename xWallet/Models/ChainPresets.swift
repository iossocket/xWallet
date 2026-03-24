//
//  ChainPresets.swift
//  xWallet
//
//  Created by Xueliang Zhu on 5/3/26.
//

import EthereumKit
import StarknetKit
import Foundation

enum ChainPresets {
    static let allPresets: [EvmChain] = [
        .mainnet,
        .sepolia,
        .polygon,
        .base,
        .bsc,
    ]

    /// Returns preset chains with enabled status
    /// Mainnet and Sepolia are enabled by default
    static func presetsWithEnabledStatus() -> [Chain] {
        func isChainEnabled(chain: EvmChain) -> Bool {
            return chain.chainId == 1 || chain.chainId == 11_155_111  // Mainnet or Sepolia
        }
        return allPresets.map { chain in
            let isEnabled = isChainEnabled(chain: chain)
            return Chain(
                id: chain.id,
                chainId: String(chain.chainId),
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

    static let starknetChains: [Starknet] = [
        .mainnet,
        .sepolia
    ]
}
