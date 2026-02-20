//
//  Dependencies.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation
import EthereumKit

struct MyDependencyValues {
    var ethereumService: EthereumService
}

enum Dependencies {
    static var current = MyDependencyValues(
        ethereumService: EthereumService(provider: EthereumProvider(chain: Ethereum(chainId: 31337, name: "anvil", rpcURL: URL(string: "http://127.0.0.1:8545")!, isTestnet: true)))
    )

    static func setRPCURL(_ url: String) {
        current.ethereumService = EthereumService(provider: EthereumProvider(chain: Ethereum(chainId: 31337, name: "anvil", rpcURL: URL(string: url)!, isTestnet: true)))
    }
    
    static func bootstrap() {
        let url = UserDefaults.standard.string(forKey: "rpc_url") ?? "https://rpc.sepolia.org"
        Dependencies.setRPCURL(url)
    }
}

