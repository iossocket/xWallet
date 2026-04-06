//
//  BalanceRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import Foundation

struct BalanceRepository {
    private let evmProvider: EvmBalanceProvider
    private let starknetProvider: StarknetBalanceProvider

    init(evmProvider: EvmBalanceProvider = EvmBalanceProvider(),
         starknetProvider: StarknetBalanceProvider = StarknetBalanceProvider()) {
        self.evmProvider = evmProvider
        self.starknetProvider = starknetProvider
    }

    func fetchBalances(identity: WalletIdentity, chains: [Chain]) async throws -> [ChainBalance] {
        guard let address = identity.primaryAddress else { return [] }

        switch identity.accountType.chainType {
        case .evm:
            return try await evmProvider.batchFetchTokenBalances(address: address, chains: chains)
        case .starknet:
            return try await starknetProvider.batchFetchTokenBalances(address: address, chains: chains)
        }
    }
}
