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
        case walletTapped(UUID)
        case deleteWalletSwiped(UUID)
        case addAccountTapped
        case switchWalletResponse(Result<UUID, Error>)
        case deleteWalletResponse(Result<UUID, Error>)
        case walletsResponse(Result<[WalletIdentity], Error>)
        case activeIdentityResponse(Result<WalletIdentity, Error>)
    }

    @Dependency(\.walletClient) var walletClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .walletTapped(let id):
                guard id != state.activeWalletId else { return .none }
                return .run { send in
                    try await walletClient.switchWallet(id)
                    await send(.switchWalletResponse(.success(id)))
                } catch: { error, send in
                    await send(.switchWalletResponse(.failure(error)))
                }
            case .switchWalletResponse(.success(let id)):
                state.activeWalletId = id
                return .none
            case .switchWalletResponse(.failure):
                return .none
            case .deleteWalletSwiped(let id):
                guard id != state.activeWalletId else { return .none }
                return .run { send in
                    try await walletClient.deleteWallet(id)
                    await send(.deleteWalletResponse(.success(id)))
                } catch: { error, send in
                    await send(.deleteWalletResponse(.failure(error)))
                }
            case .deleteWalletResponse(.success(let id)):
                state.wallets.removeAll { $0.id == id }
                return .none
            case .deleteWalletResponse(.failure):
                return .none
            case .addAccountTapped:
                return .none
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
