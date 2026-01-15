//
//  Dependencies.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation

struct DependencyValues {
    var ethereum: EthereumService
}

enum Dependencies {
    static var current = DependencyValues(
        ethereum: EthereumService(rpc: EthereumRPC(rpcURL: "..."))
    )

    static func setRPCURL(_ url: String) {
        current.ethereum = EthereumService(rpc: EthereumRPC(rpcURL: url))
    }
    
    static func bootstrap() {
        let url = UserDefaults.standard.string(forKey: "rpc_url") ?? "https://rpc.sepolia.org"
        Dependencies.setRPCURL(url)
    }
}

