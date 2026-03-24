//
//  Wallet.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/2/26.
//

import Foundation
import ComposableArchitecture
import EthereumKit
import SwiftUI

enum ViewMode: Equatable {
    case singleChain
    case allChains
}

@Reducer
struct Wallet {
    @ObservableState
    struct State: Equatable {
        @Presents var history: History.State?
        @Presents var receive: Receive.State?
        @Presents var send: Send.State?
        @Shared(.currentChain) var currentChain: Chain
        @Shared(.activeIdentitySet) var activeIdentitySet: ActiveWalletIdentitySet
        var assets: IdentifiedArrayOf<AssetItem> = []
        var chainBalances: [ChainBalance] = []
        var currentChainUsdValue: String?
        var errorMessage: String?
        var isLoadingAllChains = false
        var prices: [String: Double] = [:]
        var showBalance = true
        var totalUsdValue: String?
        var supportedChains: [Chain] = []
        var viewMode: ViewMode = .allChains
    }

    enum Action {
        case allBalancesResponse(Result<[ChainBalance], Error>)
        case chainChanged(Chain)
        case fetchAllBalances
        case fetchPrices
        case history(PresentationAction<History.Action>)
        case historyButtonTapped
        case loadSupportedChainsResponse(Result<[Chain], Error>)
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

    @Dependency(\.balanceClient) var balanceClient
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
                if state.activeIdentitySet.isEmpty {
                    return .none
                }
                state.isLoadingAllChains = true
                state.errorMessage = nil
                let active = state.activeIdentitySet
                let chains = state.supportedChains
                return .run { [balanceClient] send in
                    await send(.allBalancesResponse(
                        Result { try await balanceClient.fetchBalances(active, chains) }
                    ))
                }.cancellable(id: CancelID.balanceRequest, cancelInFlight: true)

            case .fetchPrices:
                // Collect all unique symbols from chainBalances, grouped by chainId
                var symbolsByChain: [String: [String]] = [:]
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
                    $0.toChain()
                } : chains
                return .send(.refreshButtonTapped)

            case .loadSupportedChainsResponse(.failure):
                state.supportedChains = [EvmChain.sepolia, EvmChain.mainnet].map { $0.toChain() }
                return .send(.refreshButtonTapped)

            case .refreshButtonTapped:
                if state.activeIdentitySet.isEmpty { return .none }
                return .send(.fetchAllBalances)

            case .chainChanged(let chain):
                state.$currentChain.withLock { $0 = chain }
                state.rebuildAssets()
                return .none

            case .setShowBalance(let isShowBalance):
                state.showBalance = isShowBalance
                return .none

            case .receiveButtonTapped:
                state.receive = Receive.State(address: state.activeIdentitySet.evm!.primaryAddress!)
                return .none

            case .sendButtonTapped:
                let ethAsset = state.assets.first(where: { $0.id == "ETH" })
                state.send = Send.State(
                    chain: state.currentChain,
                    availableAssets: state.assets,
                    selectedAsset: ethAsset
                )
                return .none

            case .history:
                return .none

            case .historyButtonTapped:
                state.history = History.State(
                    address: state.activeIdentitySet.evm?.primaryAddress,
                    chain: state.currentChain
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
        .ifLet(\.$history, action: \.history) { History() }
        .ifLet(\.$receive, action: \.receive) { Receive() }
        .ifLet(\.$send, action: \.send) { Send() }
    }
}

// MARK: - State helpers

extension Wallet.State {
    var isDashboardLoading: Bool {
        if activeIdentitySet.isEmpty { return false }
        guard errorMessage == nil else { return false }
        return isLoadingAllChains || totalUsdValue == nil || currentChainUsdValue == nil
    }

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
