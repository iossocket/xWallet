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
    var wallet: WalletState = .init()
    var settings: SettingsState = .init()
}

enum AppAction: Equatable {
    case tabSelected(Tab)
    case wallet(WalletAction)
    case settings(SettingsAction)
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
        case .settings(let settingsAction):
            let task = SettingsReducer().reduce( into: &state.settings, action: settingsAction, send: { send(.settings($0)) } )
            if case .saveTapped(let url) = settingsAction, case .connected = state.settings.connectionStatus {
                let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
                guard state.settings.isValid else { return task }
                
                Dependencies.setRPCURL(url)
                send(.wallet(.refreshTapped))
            }
            return task
        }
    }
}
