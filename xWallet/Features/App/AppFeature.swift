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
        @Shared(.activeIdentity) var activeIdentity: WalletIdentity?
    }
    
    enum Action {
        case account(Account.Action)
        case settings(Settings.Action)
        case tabSelected(Tab)
        case wallet(Wallet.Action)
        case activeIdentityCheck
        case activeIdentityResponse(Result<WalletIdentity, Error>)
        case initializeChains
        case initializeChainsResponse(Result<[EvmChainRecord], Error>)
    }

    @Dependency(\.walletClient) var walletClient
    @Dependency(\.chainRegistry) var chainRegistry
    
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
        Reduce { [walletClient, chainRegistry] state, action in
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
            case .activeIdentityCheck:
                return .run { send in
                    await send(.activeIdentityResponse(
                        Result { try await walletClient.activeIdentity() }
                    ))
                }
            case .activeIdentityResponse(.success(let identity)):
                state.$activeIdentity.withLock { $0 = identity }
                state.launchPhase = .ready
                return .none
            case .activeIdentityResponse(.failure):
                state.launchPhase = .needsOnboarding
                return .none
            case .initializeChains:
                return .run { send in
                    await send(.initializeChainsResponse(
                        Result {
                            // Check if database is empty
                            let existingChains = try await chainRegistry.listAllChains()
                            if existingChains.isEmpty {
                                // Insert preset chains with enabled status
                                let presetChains = ChainPresets.presetsWithEnabledStatus()
                                return try await chainRegistry.batchInsertChains(presetChains)
                            }
                            return existingChains
                        }
                    ))
                }
            case .initializeChainsResponse(.success):
                // Chains initialized successfully, continue with app launch
                return .none
            case .initializeChainsResponse(.failure(let error)):
                // Log error but don't block app launch
                print("Failed to initialize chains: \(error)")
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

extension SharedKey where Self == InMemoryKey<EvmChainRecord>.Default {
    static var currentChain: Self {
        Self[.inMemory("currentChain"), default: EvmChain.sepolia.toRecord()]
    }
}

extension SharedKey where Self == InMemoryKey<WalletIdentity?>.Default {
    static var activeIdentity: Self {
        Self[.inMemory("activeIdentity"), default: nil]
    }
}
