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

@Reducer
struct Wallet {
    @ObservableState
    struct State: Equatable {
        @Presents var receive: Receive.State?
        var address: String?
        var assets: IdentifiedArrayOf<AssetItem> = []
        var errorMessage: String?
        var ethBalance: String?
        var isLoading = false
        var showBalance = true
        var totalBalance = "1,161,2.0"
    }
    
    enum Action {
        case receive(PresentationAction<Receive.Action>)
        case balanceResponse(Result<BigUInt, Error>)
        case refreshButtonTapped
        case receiveButtonTapped
        case setShowBalance(Bool)
    }
    
    enum CancelID {
        case balanceRequest
    }
    
    @Dependency(\.ethereum) var ethereum
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                state.assets = AssetItem.preset
                guard let address = state.address else { return .none }
                return .run { [provider = ethereum.provider] send in
                    do {
                        guard let evmAddr = EthereumAddress(address) else {
                            return
                        }
                        let request = provider.getBalanceRequest(address: evmAddr, block: BlockTag.latest)
                        let result: String = try await provider.send(request: request)
                        let cleaned = result.lowercased().hasPrefix("0x")
                                ? String(result.dropFirst(2))
                                : result
                        guard let balance = BigUInt(cleaned, radix: 16) else {
                            await send(.balanceResponse(.failure(EthereumServiceError.invalidNumber)))
                            return
                        }
                        await send(.balanceResponse(.success(balance)))
                    } catch {
                        await send(.balanceResponse(.failure(error)))
                    }
                }.cancellable(id: CancelID.balanceRequest, cancelInFlight: true)

            case .balanceResponse(.success(let balance)):
                state.isLoading = false
                state.ethBalance = balance.description
                return .none

            case .balanceResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .setShowBalance(let isShowBalance):
                state.showBalance = isShowBalance
                return .none
            case .receiveButtonTapped:
                state.receive = Receive.State(address: state.address!)
                return .none
            case .receive:
                return .none
            }
        }.ifLet(\.$receive, action: \.receive) {
            Receive()
        }
    }
}
