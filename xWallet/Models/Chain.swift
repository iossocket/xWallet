//
//  Chain.swift
//  xWallet
//
//  Created by Xueliang Zhu on 4/3/26.
//

import Foundation
import GRDB
import EthereumKit
import StarknetKit

struct Chain: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    static let databaseTableName = "chains"

    let id: String
    let chainId: String
    let name: String
    let rpcURL: String
    let isTestnet: Bool
    let symbol: String
    let decimals: Int
    let explorerURL: String?
    let enabled: Bool
}

struct Token: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    static let databaseTableName = "erc20_tokens"

    let id: String
    let chainId: String
    let name: String
    let symbol: String
    let decimals: Int
    let contractAddress: String
    let chainFK: String
}

extension Chain {
    func toEvmChain() -> EvmChain {
        EvmChain(chainId: UInt64(self.chainId)!, name: self.name, rpcURL: URL(string: self.rpcURL)!, isTestnet: self.isTestnet,
                 symbol: self.symbol, decimals: self.decimals, explorerURL: self.explorerURL == nil ? nil : URL(string: self.explorerURL!))
    }

    func toStrkChain() -> Starknet {
        Starknet(chainId: Felt(self.chainId)!, name: self.name, rpcURL: URL(string: self.rpcURL)!, isTestnet: self.isTestnet, explorerURL: self.explorerURL == nil ? nil : URL(string: self.explorerURL!))
    }

    /// Convenience for EVM chains where chainId is numeric
    var numericChainId: UInt64? {
        UInt64(chainId)
    }
    
    func chainType() -> ChainType {
        if self.id.starts(with: "starknet") {
            return .starknet
        } else {
            return .evm
        }
    }
}

extension EvmChain {
    func toChain() -> Chain {
        Chain(
            id: self.id,
            chainId: String(self.chainId),
            name: self.name,
            rpcURL: self.rpcURL.absoluteString,
            isTestnet: self.isTestnet,
            symbol: self.symbol,
            decimals: self.decimals,
            explorerURL: self.explorerURL?.absoluteString,
            enabled: false
        )
    }
}

extension Starknet {
    func toChain() -> Chain {
        Chain(
            id: self.id,
            chainId: self.chainId.description,
            name: self.name,
            rpcURL: self.rpcURL.absoluteString,
            isTestnet: self.isTestnet,
            symbol: self.symbol,
            decimals: self.decimals,
            explorerURL: self.explorerURL?.absoluteString,
            enabled: false
        )
    }
}
