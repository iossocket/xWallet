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
        let url = URL(string: "http://127.0.0.1:8545")!
        let ethereumProvider = EthereumProvider(chain: Ethereum(chainId: 31337, name: "anvil", rpcURL: url, isTestnet: true))
        return EthereumService(provider: ethereumProvider)
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
