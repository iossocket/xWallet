//
//  EvmProviderClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 24/2/26.
//

import Foundation
import Dependencies
import EthereumKit

struct EvmProviderClient {
    var provider: @Sendable (EvmChainRecord) -> EthereumProvider
}

extension EvmProviderClient: DependencyKey {
    static var liveValue: EvmProviderClient {
        EvmProviderClient { chain in
            EthereumProvider(chain: chain.toChain())
        }
    }

    static var testValue: EvmProviderClient {
        EvmProviderClient { chain in
            EthereumProvider(chain: chain.toChain())
        }
    }
}


extension DependencyValues {
    var evmProvider: EvmProviderClient {
        get { self[EvmProviderClient.self] }
        set { self[EvmProviderClient.self] = newValue }
    }
}

enum EvmProviderClientError: Error {
    case invalidNumber
}
