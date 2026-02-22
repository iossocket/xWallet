//
//  AppFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import Foundation
import ComposableArchitecture

enum LaunchPhase: Equatable {
    case booting
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
        var launchPhase: LaunchPhase = .booting
        var selectedTab: Tab = .wallet
        var settings = Settings.State()
        var wallet = Wallet.State()
    }
    
    enum Action {
        case account(Account.Action)
        case appLaunched
        case settings(Settings.Action)
        case tabSelected(Tab)
        case wallet(Wallet.Action)
    }
    
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
        Reduce { state, action in
            switch action {
            case .appLaunched:
                state.launchPhase = .needsOnboarding
                return .none
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
            case .account(.importResponse(.success(let address))):
                state.wallet.address = address
                state.launchPhase = .ready
                return .none
            case .account(.onAppear):
                if let addr = state.account.address {
                    state.wallet.address = addr
                    state.launchPhase = .ready
                }
                return .none
            case .settings(.saveButtonTapped):
                if case .connected = state.settings.connectionStatus, state.settings.isValid {
                    return .send(.wallet(.refreshButtonTapped))
                }
                return .none
            case .account, .settings, .wallet:
                return .none
            }
        }
    }
}
