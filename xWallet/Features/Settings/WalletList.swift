//
//  WalletList.swift
//  xWallet
//
//  Created by Xueliang Zhu on 19/3/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct WalletList {
    @ObservableState
    struct State: Equatable {
        var wallets: [WalletIdentity] = []
        var activeWalletId: UUID?
        var isLoading = false
    }

    enum Action {
        case onAppear
        case walletsResponse(Result<[WalletIdentity], Error>)
        case activeIdentityResponse(Result<WalletIdentity, Error>)
    }

    @Dependency(\.walletClient) var walletClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.walletsResponse(Result {
                        try await walletClient.listWallets()
                    }))
                    await send(.activeIdentityResponse(Result {
                        try await walletClient.activeIdentity()
                    }))
                }
            case .walletsResponse(.success(let wallets)):
                state.wallets = wallets
                state.isLoading = false
                return .none
            case .walletsResponse(.failure):
                state.isLoading = false
                return .none
            case .activeIdentityResponse(.success(let identity)):
                state.activeWalletId = identity.id
                return .none
            case .activeIdentityResponse(.failure):
                return .none
            }
        }
    }
}
