//
//  AppFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import Foundation

enum Tab: String, Equatable {
    case wallet, market, discover, profile
}

struct AppState: Equatable {
    var selectedTab: Tab = .wallet
    var wallet: WalletState = .init() // ?
}

enum AppAction: Equatable {
    case tabSelected(Tab)
    case wallet(WalletAction)
}

struct AppReducer: Reducer {
    typealias State = AppState
    typealias Action = AppAction
    
    @MainActor
    func reduce(into state: inout AppState, action: AppAction, send: @escaping (Action) -> Void) -> Task<Void, Never>? {
        switch action {
        case .tabSelected(let tab):
            state.selectedTab = tab
            return nil
        case .wallet(let walletAction):
            return WalletReducer().reduce(into: &state.wallet, action: walletAction, send: {
                send(.wallet($0))
            })
        }
    }
}
