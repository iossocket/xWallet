//
//  BalanceClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation
import Dependencies
import StarknetKit

struct BalanceClient {
    var fetchBalances: @Sendable (_ identity: ActiveWalletIdentitySet, _ chains: [Chain]) async throws -> [ChainBalance]
}

extension BalanceClient: DependencyKey {
    static var liveValue: BalanceClient {
        let repository = BalanceRepository()

        return BalanceClient { identity, chains in
            var balances: [ChainBalance] = []
            if let evm = identity.evm {
                let evmBalances = try await repository.fetchBalances(identity: evm, chains: chains)
                balances.append(contentsOf: evmBalances)
            }
            if let starknet = identity.starknet {
                let starknetChain = starknet.chainId == StarknetChainId.mainnet.rawValue ? Starknet.mainnet : Starknet.sepolia
                let starknetBalances = try await repository.fetchBalances(identity: starknet, chains: [starknetChain.toChain()])
                balances.append(contentsOf: starknetBalances)
            }
            return balances
        }
    }

    static var testValue: BalanceClient {
        BalanceClient { _, _ in [] }
    }
}

extension DependencyValues {
    var balanceClient: BalanceClient {
        get { self[BalanceClient.self] }
        set { self[BalanceClient.self] = newValue }
    }
}
