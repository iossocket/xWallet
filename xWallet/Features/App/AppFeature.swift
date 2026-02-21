//
//  AppFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import Foundation

enum LaunchPhase: Equatable {
    case booting
    case needsOnboarding
    case ready
}

enum Tab: String, Equatable {
    case wallet, market, discover, profile
}

struct AppState: Equatable {
    var launchPhase: LaunchPhase = .booting
    var selectedTab: Tab = .wallet
    var wallet: WalletState = .init()
}

enum AppAction: Equatable {
    case appLaunched
    case tabSelected(Tab)
    case wallet(WalletAction)
}

struct AppReducer: Reducer {
    typealias State = AppState
    typealias Action = AppAction
    
    let walletReducer = WalletReducer()
    
    @MainActor
    func reduce(into state: inout AppState, action: AppAction, send: @escaping (Action) -> Void) -> Task<Void, Never>? {
        switch action {
        case .appLaunched:
            state.launchPhase = .needsOnboarding
            return nil
        case .tabSelected(let tab):
            state.selectedTab = tab
            return nil
        case .wallet(let walletAction):
            return walletReducer.reduce(into: &state.wallet, action: walletAction, send: {
                send(.wallet($0))
            })
        }
    }
}
