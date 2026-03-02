//
//  ERC20TokenList.swift
//  xWallet
//
//  Created by Xueliang Zhu on 27/2/26.
//

import Foundation

/// Curated ERC20 token lists per chain
struct ERC20TokenList {
    /// Sepolia testnet tokens (chainId: 11155111)
    /// Sources: Circle docs, Chainlink docs, Uniswap v3 deployment
    static let sepoliaTokens: [ERC20Token] = [
        // USDC — Circle official Sepolia deployment
        // https://developers.circle.com/stablecoins/docs/usdc-on-test-networks
        ERC20Token(
            chainId: 11155111,
            address: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
            symbol: "USDC",
            decimals: 6,
            name: "USD Coin"
        ),

        // LINK — Chainlink official Sepolia deployment
        // https://docs.chain.link/resources/link-token-contracts#sepolia-testnet
        ERC20Token(
            chainId: 11155111,
            address: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
            symbol: "LINK",
            decimals: 18,
            name: "Chainlink Token"
        ),

        // WETH — Uniswap v3 Sepolia canonical WETH
        // https://docs.uniswap.org/contracts/v3/reference/deployments/ethereum-deployments
        ERC20Token(
            chainId: 11155111,
            address: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14",
            symbol: "WETH",
            decimals: 18,
            name: "Wrapped Ether"
        )
    ]

    /// Ethereum mainnet tokens (chainId: 1) - for future use
    static let mainnetTokens: [ERC20Token] = [
        ERC20Token(
            chainId: 1,
            address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            symbol: "USDC",
            decimals: 6,
            name: "USD Coin"
        ),
        ERC20Token(
            chainId: 1,
            address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
            symbol: "USDT",
            decimals: 6,
            name: "Tether USD"
        ),
        ERC20Token(
            chainId: 1,
            address: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
            symbol: "DAI",
            decimals: 18,
            name: "Dai Stablecoin"
        ),
        ERC20Token(
            chainId: 1,
            address: "0x514910771AF9Ca656af840dff83E8264EcF986CA",
            symbol: "LINK",
            decimals: 18,
            name: "Chainlink Token"
        ),
        ERC20Token(
            chainId: 1,
            address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
            symbol: "WETH",
            decimals: 18,
            name: "Wrapped Ether"
        )
    ]

    /// Get token list for a specific chain
    static func tokens(for chainId: UInt64) -> [ERC20Token] {
        switch chainId {
        case 11155111:
            return sepoliaTokens
        case 1:
            return mainnetTokens
        default:
            return []
        }
    }

    /// Find a token by address on a specific chain
    static func token(address: String, chainId: UInt64) -> ERC20Token? {
        tokens(for: chainId).first {
            $0.address.lowercased() == address.lowercased()
        }
    }
}
