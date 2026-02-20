//
//  EthereumService.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/1/26.
//

import Foundation
import Dependencies
import MultiChainCore
import EthereumKit

struct EthereumService {
    let provider: any Provider
}

extension EthereumService: DependencyKey {
    static var liveValue: EthereumService {
        let url = URL(string: "http://127.0.0.1:8545")!
        let ethereumProvider = EthereumProvider(chain: Ethereum(chainId: 31337, name: "anvil", rpcURL: url, isTestnet: true))
        return EthereumService(provider: ethereumProvider)
    }
}

extension DependencyValues {
    var ethereum: EthereumService {
        get { self[EthereumService.self] }
        set { self[EthereumService.self] = newValue }
    }
}
