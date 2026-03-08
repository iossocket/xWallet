//
//  Wallet.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/2/26.
//

import Foundation
import ComposableArchitecture
import EthereumKit
import BigInt
import SwiftUI

enum ViewMode: Equatable {
    case singleChain
    case allChains
}

@Reducer
struct Wallet {
    @ObservableState
    struct State: Equatable {
        @Presents var receive: Receive.State?
        @Presents var send: Send.State?
        @Shared(.currentChain) var currentChain: EvmChainRecord
        @Shared(.activeIdentity) var activeIdentity: WalletIdentity?
        var assets: IdentifiedArrayOf<AssetItem> = []
        var chainBalances: [ChainBalance] = []
        var currentChainUsdValue: String?
        var errorMessage: String?
        var isLoadingAllChains = false
        var prices: [String: Double] = [:]
        var showBalance = true
        var totalUsdValue: String?
        var supportedChains: [EvmChainRecord] = []
        var viewMode: ViewMode = .allChains
    }

    enum Action {
        case allBalancesResponse(Result<[ChainBalance], Error>)
        case chainChanged(EvmChainRecord)
        case fetchAllBalances
        case fetchPrices
        case loadSupportedChainsResponse(Result<[EvmChainRecord], Error>)
        case onAppear
        case pricesResponse(Result<[String: Double], Error>)
        case receive(PresentationAction<Receive.Action>)
        case receiveButtonTapped
        case refreshButtonTapped
        case send(PresentationAction<Send.Action>)
        case sendButtonTapped
        case setShowBalance(Bool)
        case viewModeToggled
    }

    enum CancelID {
        case balanceRequest
    }

    @Dependency(\.evmProvider) var evmProvider
    @Dependency(\.erc20Client) var erc20Client
    @Dependency(\.chainRegistry) var chainRegistry
    @Dependency(\.priceClient) var priceClient

    // load supported chains -> batch fetch balance -> batch fetch prices -> calculate total value -> list all tokens

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .allBalancesResponse(.success(let balances)):
                state.isLoadingAllChains = false
                state.chainBalances = balances
                return .send(.fetchPrices)

            case .allBalancesResponse(.failure(let error)):
                state.isLoadingAllChains = false
                state.errorMessage = error.localizedDescription
                return .none

            case .fetchAllBalances:
                guard let address = state.activeIdentity?.primaryAddress else { return .none }
                state.isLoadingAllChains = true
                state.errorMessage = nil
                let chains = state.supportedChains
                return .run { [providerFactory = evmProvider.provider, erc20 = erc20Client] send in
                    var balances: [ChainBalance] = []
                    await withTaskGroup(of: ChainBalance?.self) { group in
                        for chain in chains {
                            group.addTask {
                                do {
                                    let provider = providerFactory(chain)
                                    guard let evmAddr = EthereumAddress(address) else { return nil }

                                    let ethHex: String = try await provider.send(
                                        request: provider.getBalanceRequest(address: evmAddr, block: .latest)
                                    )
                                    let cleaned = ethHex.lowercased().hasPrefix("0x")
                                        ? String(ethHex.dropFirst(2)) : ethHex
                                    let nativeWei = BigUInt(cleaned, radix: 16) ?? .zero

                                    let tokenList = ERC20TokenList.tokens(for: chain.chainId)
                                    var tokenBalances: [TokenBalance] = []
                                    for token in tokenList {
                                        if let bal = try? await erc20.balanceOf(address, token, chain), bal > .zero {
                                            tokenBalances.append(TokenBalance(
                                                chainId: chain.chainId,
                                                contractAddress: token.address,
                                                symbol: token.symbol,
                                                name: token.name,
                                                decimals: token.decimals,
                                                rawBalance: bal
                                            ))
                                        }
                                    }

                                    return ChainBalance(
                                        chainId: chain.chainId,
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
                    let chainOrder = chains.map(\.chainId)
                    balances.sort { chainOrder.firstIndex(of: $0.chainId) ?? 0 < chainOrder.firstIndex(of: $1.chainId) ?? 0 }
                    await send(.allBalancesResponse(.success(balances)))
                }.cancellable(id: CancelID.balanceRequest, cancelInFlight: true)

            case .fetchPrices:
                // Collect all unique symbols from chainBalances, grouped by chainId
                var symbolsByChain: [UInt64: [String]] = [:]
                for cb in state.chainBalances {
                    var symbols = [cb.symbol]
                    symbols += cb.tokens.map(\.symbol)
                    symbolsByChain[cb.chainId] = symbols
                }
                guard !symbolsByChain.isEmpty else { return .none }
                return .run { [priceClient, symbolsByChain] send in
                    var allPrices: [String: Double] = [:]
                    for (chainId, symbols) in symbolsByChain {
                        if let prices = try? await priceClient.fetchPrices(chainId, symbols) {
                            allPrices.merge(prices) { _, new in new }
                        }
                    }
                    await send(.pricesResponse(.success(allPrices)))
                }

            case .pricesResponse(.success(let prices)):
                state.prices = prices
                state.rebuildAssets()
                return .none

            case .pricesResponse(.failure):
                return .none

            case .onAppear:
                return .run { send in
                    await send(.loadSupportedChainsResponse(
                        Result { try await chainRegistry.listEnabledChains() }
                    ))
                }

            case .loadSupportedChainsResponse(.success(let chains)):
                state.supportedChains = chains.isEmpty ? [EvmChain.sepolia, EvmChain.mainnet].map {
                    $0.toRecord()
                } : chains
                return .send(.refreshButtonTapped)

            case .loadSupportedChainsResponse(.failure):
                state.supportedChains = [EvmChain.sepolia, EvmChain.mainnet].map { $0.toRecord() }
                return .send(.refreshButtonTapped)

            case .refreshButtonTapped:
                guard state.activeIdentity?.primaryAddress != nil else { return .none }
                return .send(.fetchAllBalances)

            case .chainChanged(let chain):
                state.$currentChain.withLock { $0 = chain }
                state.rebuildAssets()
                return .none

            case .setShowBalance(let isShowBalance):
                state.showBalance = isShowBalance
                return .none

            case .receiveButtonTapped:
                state.receive = Receive.State(address: state.activeIdentity!.primaryAddress!)
                return .none

            case .sendButtonTapped:
                let ethAsset = state.assets.first(where: { $0.id == "ETH" })
                state.send = Send.State(
                    chain: state.currentChain,
                    availableAssets: state.assets,
                    selectedAsset: ethAsset
                )
                return .none

            case .send:
                return .none

            case .receive:
                return .none

            case .viewModeToggled:
                state.viewMode = state.viewMode == .singleChain ? .allChains : .singleChain
                if state.viewMode == .allChains {
                    return .send(.fetchAllBalances)
                }
                state.rebuildAssets()
                return .none
            }
        }
        .ifLet(\.$receive, action: \.receive) { Receive() }
        .ifLet(\.$send, action: \.send) { Send() }
    }
}

// MARK: - State helpers

extension Wallet.State {
    /// Rebuild assets, totalUsdValue, currentChainUsdValue from chainBalances + prices.
    mutating func rebuildAssets() {
        let currentChainId = currentChain.chainId
        let visibleBalances = chainBalances.filter { $0.chainId == currentChainId }

        var items: [AssetItem] = []
        var totalUsd: Double = 0
        var currentChainUsd: Double = 0

        for cb in chainBalances {
            let nativeBal = cb.nativeFormatted
            let nativeAmount = Double(nativeBal.replacingOccurrences(of: ",", with: "")) ?? 0
            let nativeUsd = nativeAmount * (prices[cb.symbol] ?? 0)
            totalUsd += nativeUsd
            if cb.chainId == currentChainId { currentChainUsd += nativeUsd }

            for token in cb.tokens {
                let tokenBal = token.formatted
                let tokenAmount = Double(tokenBal.replacingOccurrences(of: ",", with: "")) ?? 0
                let tokenUsd = tokenAmount * (prices[token.symbol] ?? 0)
                totalUsd += tokenUsd
                if cb.chainId == currentChainId { currentChainUsd += tokenUsd }
            }
        }

        for cb in visibleBalances {
            let nativeBal = cb.nativeFormatted
            let nativeAmount = Double(nativeBal.replacingOccurrences(of: ",", with: "")) ?? 0
            let nativeUsd = nativeAmount * (prices[cb.symbol] ?? 0)

            items.append(AssetItem(
                id: "\(cb.chainId):\(cb.symbol)",
                symbol: cb.symbol,
                name: cb.chainName,
                balance: nativeBal,
                value: formatUsd(nativeUsd),
                change: "--",
                icon: "diamond.fill",
                color: .indigo
            ))

            for token in cb.tokens {
                let tokenBal = token.formatted
                let tokenAmount = Double(tokenBal.replacingOccurrences(of: ",", with: "")) ?? 0
                let tokenUsd = tokenAmount * (prices[token.symbol] ?? 0)

                items.append(AssetItem(
                    id: token.id,
                    symbol: token.symbol,
                    name: token.name,
                    balance: tokenBal,
                    value: formatUsd(tokenUsd),
                    change: "+0.00%",
                    icon: iconName(for: token.symbol),
                    color: iconColor(for: token.symbol)
                ))
            }
        }

        totalUsdValue = formatUsd(totalUsd)
        currentChainUsdValue = formatUsd(currentChainUsd)
        assets = IdentifiedArray(uniqueElements: items)
    }
}

private func iconName(for symbol: String) -> String {
    switch symbol.uppercased() {
    case "USDC", "USDT": return "dollarsign.circle.fill"
    case "LINK":         return "link.circle.fill"
    case "WETH":         return "diamond.fill"
    default:             return "circle.fill"
    }
}

private func iconColor(for symbol: String) -> Color {
    switch symbol.uppercased() {
    case "USDC":  return .blue
    case "USDT":  return .green
    case "LINK":  return .blue
    case "WETH":  return .indigo
    default:      return .gray
    }
}

private func formatUsd(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.locale = Locale(identifier: "en_US")
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
}

