//
//  EvmProviderFactory.swift
//  xWallet
//
//  Created by Xueliang Zhu on 24/2/26.
//

import Foundation
import ComposableArchitecture
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
    let chain: Chain
    let provider: EthereumProvider

    init(chain: Chain) {
        self.chain = chain
        self.provider = EthereumProvider(chain: chain.toEvmChain())
    }

    var chainId: UInt64 { chain.numericChainId ?? 0 }

    func send<R: Decodable>(request: ChainRequest) async throws -> R {
        try await provider.send(request: request)
    }

    func getBalanceRequest(address: EthereumAddress, block: BlockTag) -> ChainRequest {
        EthereumRequestBuilder.getBalanceRequest(address: address, block: block)
    }

    func sendRawTransactionRequest(_ raw: String) -> ChainRequest {
        EthereumRequestBuilder.sendRawTransactionRequest(raw)
    }

    func chainIdRequest() -> ChainRequest {
        EthereumRequestBuilder.chainIdRequest()
    }

    func waitForTransaction(hash: String) async throws -> EthereumReceipt {
        try await provider.waitForTransaction(hash: hash)
    }
}

struct EvmProviderFactory {
    var provider: @Sendable (Chain) -> any EvmProviderProtocol
}

extension EvmProviderFactory: DependencyKey {
    static var liveValue: EvmProviderFactory {
        EvmProviderFactory { chain in
            EvmProviderWrapper(chain: chain)
        }
    }

    static var testValue: EvmProviderFactory {
        EvmProviderFactory { chain in
            MockEvmProvider(chainId: UInt64(chain.chainId)!)
        }
    }
}

extension DependencyValues {
    var evmProviderFactory: EvmProviderFactory {
        get { self[EvmProviderFactory.self] }
        set { self[EvmProviderFactory.self] = newValue }
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
