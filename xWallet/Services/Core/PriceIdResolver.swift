//
//  PriceIdResolver.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation

protocol PriceIdResolver: Sendable {
    /// Resolve a symbol on a given chain to an external price ID.
    /// Returns symbol → priceId mapping for all resolvable symbols.
    func resolve(chainId: String, symbols: [String]) async -> [String: String]
}

/// Static resolver using hardcoded mappings. Async interface for future extensibility.
struct StaticPriceIdResolver: PriceIdResolver {
    func resolve(chainId: String, symbols: [String]) async -> [String: String] {
        var mapped: [String: String] = [:]
        for symbol in symbols {
            if isNativeSymbol(symbol, chainId: chainId) {
                mapped[symbol] = nativePriceId(for: chainId)
            } else if let id = tokenPriceId(for: symbol) {
                mapped[symbol] = id
            }
        }
        return mapped
    }

    private func nativePriceId(for chainId: String) -> String {
        switch chainId {
        case "1", "11155111", "8453", "42161", "10": return "ethereum"
        case "137":        return "matic-network"
        case "56":         return "binancecoin"
        case "starknet":   return "starknet"   // Starknet 原生代币是 STRK
        default:           return "ethereum"
        }
    }

    private func tokenPriceId(for symbol: String) -> String? {
        switch symbol.uppercased() {
        case "USDC", "EURC": return "usd-coin"
        case "USDT":         return "tether"
        case "DAI":          return "dai"
        case "LINK":         return "chainlink"
        case "WETH":         return "weth"
        case "WBTC":         return "wrapped-bitcoin"
        case "ARB":          return "arbitrum"
        case "STRK":         return "starknet"
        default:             return nil
        }
    }

    private func isNativeSymbol(_ symbol: String, chainId: String) -> Bool {
        switch chainId {
        case "137":       return symbol.uppercased() == "MATIC"
        case "56":        return symbol.uppercased() == "BNB"
        case "starknet":  return symbol.uppercased() == "STRK"
        default:          return symbol.uppercased() == "ETH"
        }
    }
}
