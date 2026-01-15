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
    var settings: SettingsState = .init()
    var account: AccountState = .init()
}

enum AppAction: Equatable {
    case appLaunched
    case tabSelected(Tab)
    case wallet(WalletAction)
    case settings(SettingsAction)
    case account(AccountAction)
}

struct AppReducer: Reducer {
    typealias State = AppState
    typealias Action = AppAction
    
    let walletReducer = WalletReducer(ethereum: Dependencies.current.ethereum)
    let settingsReducer = SettingsReducer()
    let accountReducer = AccountReducer()
    
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
        case .settings(let settingsAction):
            let task = settingsReducer.reduce( into: &state.settings, action: settingsAction, send: { send(.settings($0)) } )
            if case .saveTapped(let url) = settingsAction, case .connected = state.settings.connectionStatus {
                let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
                guard state.settings.isValid else { return task }
                
                Dependencies.setRPCURL(url)
                send(.wallet(.refreshTapped))
            }
            return task
        case .account(let action):
            let task = accountReducer.reduce(
                into: &state.account,
                action: action,
                send: { send(.account($0)) }
            )

            if case .importResult(.success(let addr)) = action {
                state.wallet.address = addr
            }
            if case .onAppear = action, let addr = state.account.address {
                state.wallet.address = addr
            }

            return task
        }
    }
}
