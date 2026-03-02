//
//  AppFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import Foundation
import ComposableArchitecture
import EthereumKit

enum LaunchPhase: Equatable {
    case splashScreen
    case needsOnboarding
    case ready
}

enum Tab: String, Equatable {
    case wallet, market, discover, profile
}

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var account = Account.State()
        var launchPhase: LaunchPhase = .splashScreen
        var selectedTab: Tab = .wallet
        var settings = Settings.State()
        var wallet = Wallet.State()
    }
    
    enum Action {
        case account(Account.Action)
        case settings(Settings.Action)
        case tabSelected(Tab)
        case wallet(Wallet.Action)
        case activeIdentityCheck
        case activeIdentityResponse(Result<WalletIdentity, Error>)
    }
    
    @Dependency(\.walletClient) var walletClient
    
    var body: some ReducerOf<Self> {
        Scope(state: \.account, action: \.account) {
            Account()
        }
        Scope(state: \.settings, action: \.settings) {
            Settings()
        }
        Scope(state: \.wallet, action: \.wallet) {
            Wallet()
        }
        Reduce { [walletClient] state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
            case .account(.createWalletResponse(.success)),
                 .account(.importMnemonicResponse(.success)),
                 .account(.importPrivateKeyResponse(.success)):
                state.launchPhase = .ready
                return .none

            case .account(.onAppear):
                if let _ = state.account.activeIdentity {
                    state.launchPhase = .ready
                }
                return .none

            case .settings(.saveButtonTapped):
                if case .connected = state.settings.connectionStatus, state.settings.isValid {
                    return .send(.wallet(.refreshButtonTapped))
                }
                return .none
            case .activeIdentityCheck:
                return .run { send in
                    await send(.activeIdentityResponse(
                        Result { try await walletClient.activeIdentity() }
                    ))
                }
            case .activeIdentityResponse(.success):
                state.launchPhase = .ready
                return .none
            case .activeIdentityResponse(.failure):
                state.launchPhase = .needsOnboarding
                return .none
            case .account, .settings, .wallet:
                return .none
            }
        }
        #if DEBUG
        ._printChanges()
        #endif
    }
}
