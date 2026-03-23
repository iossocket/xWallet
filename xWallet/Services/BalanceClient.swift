//
//  BalanceClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation
import Dependencies

struct BalanceClient {
    var fetchBalances: @Sendable (_ identity: WalletIdentity, _ chains: [Chain]) async throws -> [ChainBalance]
}

extension BalanceClient: DependencyKey {
    static var liveValue: BalanceClient {
        let repository = BalanceRepository()

        return BalanceClient { identity, chains in
            try await repository.fetchBalances(identity: identity, chains: chains)
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
