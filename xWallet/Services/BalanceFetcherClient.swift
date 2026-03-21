//
//  BalanceFetcherClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/3/26.
//

import Foundation
import Dependencies
import EthereumKit
import MultiChainKit
import MultiChainCore
import BigInt

struct BalanceFetcherClient {
    var fetchBalances: @Sendable (_ identity: WalletIdentity, _ evmChains: [EvmChainRecord]) async throws -> [ChainBalance]
}

extension BalanceFetcherClient: DependencyKey {
    static var liveValue: BalanceFetcherClient {
        let evmFetcher = EvmBalanceFetcher()
        let starknetFetcher = StarknetBalanceFetcher()

        return BalanceFetcherClient { identity, evmChains in
            guard let address = identity.primaryAddress else { return [] }

            switch identity.chainType {
            case .evm:
                return try await evmFetcher.fetchBalances(address: address, chains: evmChains)
            case .starknet:
                return try await starknetFetcher.fetchBalances(address: address)
            }
        }
    }

    static var testValue: BalanceFetcherClient {
        BalanceFetcherClient { _, _ in [] }
    }
}

extension DependencyValues {
    var balanceFetcher: BalanceFetcherClient {
        get { self[BalanceFetcherClient.self] }
        set { self[BalanceFetcherClient.self] = newValue }
    }
}

// MARK: - EVM Balance Fetcher

private struct EvmBalanceFetcher: Sendable {
    func fetchBalances(address: String, chains: [EvmChainRecord]) async throws -> [ChainBalance] {
        var balances: [ChainBalance] = []
        await withTaskGroup(of: ChainBalance?.self) { group in
            for chain in chains {
                group.addTask {
                    do {
                        let provider = EthereumProvider(chain: chain.toChain())
                        guard let evmAddr = EthereumAddress(address) else { return nil }

                        let ethHex: String = try await provider.send(
                            request: EthereumRequestBuilder.getBalanceRequest(address: evmAddr, block: .latest)
                        )
                        let cleaned = ethHex.lowercased().hasPrefix("0x")
                            ? String(ethHex.dropFirst(2)) : ethHex
                        let nativeWei = BigUInt(cleaned, radix: 16) ?? .zero

                        let tokenList = ERC20TokenList.tokens(for: String(chain.chainId))
                        var tokenBalances: [TokenBalance] = []
                        for token in tokenList {
                            guard let contractAddr = EthereumAddress(token.address),
                                  let owner = EthereumAddress(address) else { continue }
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
                                    chainId: String(chain.chainId),
                                    contractAddress: token.address,
                                    symbol: token.symbol,
                                    name: token.name,
                                    decimals: token.decimals,
                                    rawBalance: bal
                                ))
                            }
                        }

                        return ChainBalance(
                            chainId: String(chain.chainId),
                            chainType: .evm,
                            chainName: chain.name,
                            symbol: chain.symbol,
                            decimals: chain.decimals,
                            nativeBalance: nativeWei,
                            tokens: tokenBalances
                        )
                    } catch {
                        return nil
                    }
                }
            }
            for await result in group {
                if let balance = result { balances.append(balance) }
            }
        }
        let chainOrder = chains.map { String($0.chainId) }
        balances.sort { chainOrder.firstIndex(of: $0.chainId) ?? 0 < chainOrder.firstIndex(of: $1.chainId) ?? 0 }
        return balances
    }
}

// MARK: - Starknet Balance Fetcher

private struct StarknetBalanceFetcher: Sendable {
    func fetchBalances(address: String) async throws -> [ChainBalance] {
        let provider = StarknetProvider(chain: .sepolia)
        let ethContract = StarknetTokenContracts.eth
        let strkContract = StarknetTokenContracts.strk

        guard let accountAddress = Felt(address) else { return [] }

        async let ethResult = callBalanceOf(provider: provider, token: ethContract, account: accountAddress)
        async let strkResult = callBalanceOf(provider: provider, token: strkContract, account: accountAddress)

        let (eth, strk) = try await (ethResult, strkResult)

        var tokens: [TokenBalance] = []
        if eth > .zero {
            tokens.append(TokenBalance(
                chainId: "starknet",
                contractAddress: ethContract.hexString,
                symbol: "ETH",
                name: "Ether",
                decimals: 18,
                rawBalance: eth
            ))
        }

        return [
            ChainBalance(
                chainId: "starknet",
                chainType: .starknet,
                chainName: "Starknet",
                symbol: "STRK",
                decimals: 18,
                nativeBalance: strk,
                tokens: tokens
            )
        ]
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
