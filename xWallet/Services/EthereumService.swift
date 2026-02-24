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
    let provider: EthereumProvider
}

enum EthereumServiceError: Error {
    case invalidURL(String)
    case invalidNumber
}

extension EthereumService: DependencyKey {
    static var liveValue: EthereumService {
        let rpcURL = UserDefaults.standard.string(forKey: "rpc_url")
            ?? "https://rpc.sepolia.org"
        let url = URL(string: rpcURL) ?? URL(string: "https://rpc.sepolia.org")!
        let chain = Ethereum(rpcURL: url)
        let provider = EthereumProvider(chain: chain)
        return EthereumService(provider: provider)
    }
}

struct EvmRpcClient {
    var getChainId: (String) async throws -> Int
}

extension EvmRpcClient: DependencyKey {
    static var liveValue: EvmRpcClient {
        EvmRpcClient { url in
            let evm = Ethereum(rpcURL: URL(string: url)!)
            let provider = EthereumProvider(chain: evm)
            let result: String = try await provider.send(request: provider.chainIdRequest())
            let cleaned = result.lowercased().hasPrefix("0x")
                    ? String(result.dropFirst(2))
                    : result
            guard let chainId = Int(cleaned, radix: 16) else {
                throw EthereumServiceError.invalidURL(url)
            }
            return chainId
        }
    }
    
    static var testValue: EvmRpcClient {
        EvmRpcClient(
            getChainId: { _ in 1 }
        )
    }
}

extension DependencyValues {
    var ethereum: EthereumService {
        get { self[EthereumService.self] }
        set { self[EthereumService.self] = newValue }
    }
    var evmRpcClient: EvmRpcClient {
        get { self[EvmRpcClient.self] }
        set { self[EvmRpcClient.self] = newValue }
    }
}
