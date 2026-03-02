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

@Reducer
struct Wallet {
    @ObservableState
    struct State: Equatable {
        @Presents var receive: Receive.State?
        @Presents var send: Send.State?
        @Shared(.currentChain) var currentChain: EvmChain
        @Shared(.activeIdentity) var activeIdentity: WalletIdentity?
        var assets: IdentifiedArrayOf<AssetItem> = []
        var tokens: [ERC20Token] = []
        var errorMessage: String?
        var ethBalance: String?
        var isLoading = false
        var showBalance = true
        var totalBalance = "1,161,2.0"
    }
    
    enum Action {
        case receive(PresentationAction<Receive.Action>)
        case send(PresentationAction<Send.Action>)
        case balanceResponse(Result<[AssetItem], Error>)
        case chainChanged(EvmChain)
        case refreshButtonTapped
        case receiveButtonTapped
        case setShowBalance(Bool)
        case sendButtonTapped
    }
    
    enum CancelID {
        case balanceRequest
    }
    
    @Dependency(\.evmProvider) var evmProvider
    @Dependency(\.erc20Client) var erc20Client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshButtonTapped:
                guard let address = state.activeIdentity?.primaryAddress else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                let chain = state.currentChain
                return .run { [providerFactory = evmProvider.provider, erc20 = erc20Client] send in
                    do {
                        guard let evmAddr = EthereumAddress(address) else { return }
                        let provider = providerFactory(chain)
                        let tokens = ERC20TokenList.tokens(for: chain.chainId)

                        // ETH balance + all ERC20 balances in parallel
                        async let ethHex: String = provider.send(
                            request: provider.getBalanceRequest(address: evmAddr, block: .latest)
                        )
                        async let tokenPairs: [(ERC20Token, BigUInt)] = {
                            var results: [(ERC20Token, BigUInt)] = []
                            try await withThrowingTaskGroup(of: (ERC20Token, BigUInt).self) { group in
                                for token in tokens {
                                    group.addTask {
                                        let bal = try await erc20.balanceOf(address, token, provider)
                                        return (token, bal)
                                    }
                                }
                                for try await pair in group { results.append(pair) }
                            }
                            return results
                        }()

                        let (hexStr, pairs) = try await (ethHex, tokenPairs)

                        // Parse ETH
                        let cleaned = hexStr.lowercased().hasPrefix("0x") ? String(hexStr.dropFirst(2)) : hexStr
                        let ethWei = BigUInt(cleaned, radix: 16) ?? .zero
                        var items: [AssetItem] = [
                            AssetItem(
                                id: "ETH",
                                symbol: "ETH",
                                name: "Ethereum",
                                balance: formatWei(ethWei, decimals: 18),
                                value: "--",
                                change: "--",
                                icon: "diamond.fill",
                                color: .indigo
                            )
                        ]

                        // Preserve token list order
                        for token in tokens {
                            guard let (_, bal) = pairs.first(where: { $0.0.id == token.id }) else { continue }
                            items.append(AssetItem(
                                id: token.id,
                                symbol: token.symbol,
                                name: token.name,
                                balance: formatWei(bal, decimals: token.decimals),
                                value: "--",
                                change: "+0.00%",
                                icon: iconName(for: token.symbol),
                                color: iconColor(for: token.symbol)
                            ))
                        }

                        await send(.balanceResponse(.success(items)))
                    } catch {
                        await send(.balanceResponse(.failure(error)))
                    }
                }.cancellable(id: CancelID.balanceRequest, cancelInFlight: true)

            case .balanceResponse(.success(let items)):
                state.isLoading = false
                state.assets = IdentifiedArray(uniqueElements: items)
                state.ethBalance = items.first(where: { $0.id == "ETH" })?.balance
                return .none

            case .balanceResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .chainChanged(let chain):
                state.$currentChain.withLock { $0 = chain }
                return .send(.refreshButtonTapped)

            case .setShowBalance(let isShowBalance):
                state.showBalance = isShowBalance
                return .none

            case .receiveButtonTapped:
                state.receive = Receive.State(address: state.activeIdentity!.primaryAddress!)
                return .none

            case .sendButtonTapped:
                state.send = Send.State(chain: state.currentChain)
                return .none

            case .send:
                return .none

            case .receive:
                return .none
            }
        }
        .ifLet(\.$receive, action: \.receive) { Receive() }
        .ifLet(\.$send, action: \.send) { Send() }
    }
}

// MARK: - Private helpers

private func formatWei(_ wei: BigUInt, decimals: UInt8) -> String {
    guard wei > 0 else { return "0" }
    let divisor = BigUInt(10).power(Int(decimals))
    let whole = wei / divisor
    let remainder = wei % divisor
    guard remainder > 0 else { return whole.description }
    let padded = String(remainder).leftPadded(toLength: Int(decimals), with: "0")
    let frac = String(padded.prefix(6).reversed().drop(while: { $0 == "0" }).reversed())
    return frac.isEmpty ? whole.description : "\(whole).\(frac)"
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

private extension String {
    func leftPadded(toLength length: Int, with char: Character) -> String {
        guard count < length else { return self }
        return String(repeating: char, count: length - count) + self
    }
}
