//
//  EvmProviderClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 24/2/26.
//

import Foundation
import Dependencies
import EthereumKit
import MultiChainCore

protocol EvmProviderProtocol: Sendable {
    func send<R: Decodable>(request: ChainRequest) async throws -> R
    func getBalanceRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest
    func sendRawTransactionRequest(_ raw: String) -> ChainRequest
    func chainIdRequest() -> ChainRequest
    func waitForTransaction(hash: String) async throws -> EthereumReceipt

    var chainId: UInt64 { get }
}

struct EvmProviderWrapper: EvmProviderProtocol {
    let chain: EvmChainRecord
    let provider: EthereumProvider

    init(chain: EvmChainRecord) {
        self.chain = chain
        self.provider = EthereumProvider(chain: chain.toChain())
    }

    var chainId: UInt64 { chain.chainId }

    func send<R: Decodable>(request: ChainRequest) async throws -> R {
        try await provider.send(request: request)
    }

    func getBalanceRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
        provider.getBalanceRequest(address: address, block: block)
    }

    func sendRawTransactionRequest(_ raw: String) -> ChainRequest {
        provider.sendRawTransactionRequest(raw)
    }

    func chainIdRequest() -> ChainRequest {
        provider.chainIdRequest()
    }

    func waitForTransaction(hash: String) async throws -> EthereumReceipt {
        try await provider.waitForTransaction(hash: hash)
    }
}

struct EvmProviderClient {
    var provider: @Sendable (EvmChainRecord) -> any EvmProviderProtocol
}

extension EvmProviderClient: DependencyKey {
    static var liveValue: EvmProviderClient {
        EvmProviderClient { chain in
            EvmProviderWrapper(chain: chain)
        }
    }

    static var testValue: EvmProviderClient {
        EvmProviderClient { chain in
            MockEvmProvider(chainId: chain.chainId)
        }
    }
}

extension DependencyValues {
    var evmProvider: EvmProviderClient {
        get { self[EvmProviderClient.self] }
        set { self[EvmProviderClient.self] = newValue }
    }
}

struct MockEvmProvider: EvmProviderProtocol {
    let chainId: UInt64

    func send<R: Decodable>(request: ChainRequest) async throws -> R {
        throw MockEvmProviderError.notOverridden
    }

    func getBalanceRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
        ChainRequest(method: "eth_getBalance", params: [])
    }

    func sendRawTransactionRequest(_ raw: String) -> ChainRequest {
        ChainRequest(method: "eth_sendRawTransaction", params: [])
    }

    func chainIdRequest() -> ChainRequest {
        ChainRequest(method: "eth_chainId", params: [])
    }

    func waitForTransaction(hash: String) async throws -> EthereumReceipt {
        throw MockEvmProviderError.notOverridden
    }
}

enum MockEvmProviderError: Error {
    case notOverridden
}
