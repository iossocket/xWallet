//
//  Chain.swift
//  xWallet
//
//  Created by Xueliang Zhu on 4/3/26.
//

import Foundation
import GRDB
import EthereumKit

struct EvmChainRecord: Codable, FetchableRecord, PersistableRecord, Sendable, Equatable {
    static let databaseTableName = "evm_chain"
    
    let id: String
    let chainId: UInt64
    let name: String
    let rpcURL: String
    let isTestnet: Bool
    let symbol: String
    let decimals: Int
    let explorerURL: String?
    let enabled: Bool
}

extension EvmChainRecord {
    func toChain() -> EvmChain {
        EvmChain(chainId: self.chainId, name: self.name, rpcURL: URL(string: self.rpcURL)!, isTestnet: self.isTestnet,
                 symbol: self.symbol, decimals: self.decimals, explorerURL: self.explorerURL == nil ? nil : URL(string: self.explorerURL!))
    }
}

extension EvmChain {
    func toRecord() -> EvmChainRecord {
        EvmChainRecord(id: self.id, chainId: self.chainId, name: self.name, rpcURL: self.rpcURL.absoluteString, isTestnet: self.isTestnet, symbol: self.symbol, decimals: self.decimals, explorerURL: self.explorerURL == nil ? nil : self.explorerURL!.absoluteString, enabled: false)
    }
}
