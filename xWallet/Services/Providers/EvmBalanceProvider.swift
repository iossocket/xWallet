//
//  EvmBalanceProvider.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/3/26.
//

import EthereumKit
import MultiChainCore
import BigInt

struct EvmBalanceProvider: Sendable {

    func fetchTokenBalances(address: String, chain: Chain) async throws -> ChainBalance {
        let provider = EthereumProvider(chain: chain.toEvmChain())
        guard let evmAddr = EthereumAddress(address) else {
            throw ChainError.invalidAddress
        }

        let ethHex: String = try await provider.send(
            request: EthereumRequestBuilder.getBalanceRequest(address: evmAddr, block: .latest)
        )
        let cleaned = ethHex.lowercased().hasPrefix("0x")
            ? String(ethHex.dropFirst(2)) : ethHex
        let nativeWei = BigUInt(cleaned, radix: 16) ?? .zero

        let tokenList = ERC20TokenList.tokens(for: chain.chainId)
        var tokenBalances: [TokenBalance] = []
        for token in tokenList {
            guard let contractAddr = EthereumAddress(token.address),
                  let owner = EthereumAddress(address) else { continue }
            do {
                let contract = try EthereumContract(
                    address: contractAddr,
                    abiJson: ERC20ABI.evm,
                    provider: provider
                )
                let bal: BigUInt = try await contract.readSingle(
                    functionName: "balanceOf",
                    args: [.address(owner)]
                )
                if bal > .zero {
                    tokenBalances.append(TokenBalance(
                        chainId: chain.chainId,
                        contractAddress: token.address,
                        symbol: token.symbol,
                        name: token.name,
                        decimals: token.decimals,
                        rawBalance: bal
                    ))
                }
            } catch {
                continue
            }
        }

        return ChainBalance(
            chainId: chain.chainId,
            chainType: .evm,
            chainName: chain.name,
            symbol: chain.symbol,
            decimals: chain.decimals,
            nativeBalance: nativeWei,
            tokens: tokenBalances
        )
    }

    func batchFetchTokenBalances(address: String, chains: [Chain]) async throws -> [ChainBalance] {
        var balances: [ChainBalance] = []
        let chains = chains.filter { $0.chainType() == .evm }
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
        let chainOrder = chains.map { $0.chainId }
        balances.sort { chainOrder.firstIndex(of: $0.chainId) ?? 0 < chainOrder.firstIndex(of: $1.chainId) ?? 0 }
        return balances
    }
}
