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
        @Shared(.activeIdentitySet) var activeIdentitySet: ActiveWalletIdentitySet
        var isLoading = false
    }

    enum Action {
        case onAppear
        case walletTapped(UUID)
        case deleteWalletSwiped(UUID)
        case addAccountTapped
        case switchWalletResponse(Result<WalletIdentity?, Error>)
        case deleteWalletResponse(Result<UUID, Error>)
        case walletsResponse(Result<[WalletIdentity], Error>)
    }

    @Dependency(\.walletClient) var walletClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .walletTapped(let id):
                if state.activeIdentitySet.contains(identityId: id) {
                    return .none
                }
                return .run { send in
                    let identity = try await walletClient.switchWallet(id)
                    await send(.switchWalletResponse(.success(identity)))
                } catch: { error, send in
                    await send(.switchWalletResponse(.failure(error)))
                }
            case .switchWalletResponse(.success(let identity)):
                state.$activeIdentitySet.withLock {
                    $0.updateIdentity(identity: identity)
                }
                return .none
            case .switchWalletResponse(.failure):
                return .none
            case .deleteWalletSwiped(let id):
                if state.activeIdentitySet.contains(identityId: id) {
                    return .none
                }
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
                }
            case .walletsResponse(.success(let wallets)):
                state.wallets = wallets
                state.isLoading = false
                return .none
            case .walletsResponse(.failure(_)):
                state.isLoading = false
                return .none
            }
        }
    }
}
