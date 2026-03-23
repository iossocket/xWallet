//
//  StarknetBalanceProvider.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import StarknetKit
import MultiChainCore
import BigInt

struct StarknetBalanceProvider: Sendable {

    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance {
        let provider = StarknetProvider(chain: chain.toStrkChain())
        guard let accountAddress = Felt(address) else {
            throw ChainError.invalidAddress
        }

        let ethContract = StarknetTokenContracts.eth
        let strkContract = StarknetTokenContracts.strk

        async let ethResult = callBalanceOf(provider: provider, token: ethContract, account: accountAddress)
        async let strkResult = callBalanceOf(provider: provider, token: strkContract, account: accountAddress)

        let (eth, strk) = try await (ethResult, strkResult)

        var tokens: [TokenBalance] = []
        if eth > .zero {
            tokens.append(TokenBalance(
                chainId: chain.chainId,
                contractAddress: ethContract.hexString,
                symbol: "ETH",
                name: "Ether",
                decimals: 18,
                rawBalance: eth
            ))
        }

        return ChainBalance(
            chainId: chain.chainId,
            chainType: .starknet,
            chainName: chain.name,
            symbol: chain.symbol,
            decimals: chain.decimals,
            nativeBalance: strk,
            tokens: tokens
        )
    }

    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance] {
        var balances: [ChainBalance] = []
        await withTaskGroup(of: ChainBalance?.self) { group in
            for chain in chains {
                group.addTask {
                    try? await fetchTokenBalances(address: address, chain: chain)
                }
            }
            for await result in group {
                if let balance = result { balances.append(balance) }
            }
        }
        return balances
    }

    private func callBalanceOf(provider: StarknetProvider, token: Felt, account: Felt) async throws -> BigUInt {
        let call = StarknetCall(contractAddress: token, entrypoint: "balance_of", calldata: [account])
        let request = StarknetRequestBuilder.callRequest(call: call, block: .latest)
        let result: [String] = try await provider.send(request: request)
        guard result.count >= 2, let low = Felt(result[0]), let high = Felt(result[1]) else {
            return .zero
        }
        return low.bigUIntValue + high.bigUIntValue * (BigUInt(1) << 128)
    }
}
