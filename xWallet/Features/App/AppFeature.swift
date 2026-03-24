//
//  AppFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import Foundation
import ComposableArchitecture
import EthereumKit
import StarknetKit

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
        @Shared(.activeIdentitySet) var activeIdentitySet: ActiveWalletIdentitySet
    }
    
    enum Action {
        case account(Account.Action)
        case settings(Settings.Action)
        case tabSelected(Tab)
        case wallet(Wallet.Action)
        case activeIdentityCheck
        case activeIdentityResponse(Result<ActiveWalletIdentitySet, Error>)
        case initializeChains
        case initializeChainsResponse(Result<[Chain], Error>)
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

            case .settings(.importAccount(.presented(.createWalletResponse(.success)))),
                 .settings(.importAccount(.presented(.importMnemonicResponse(.success)))),
                 .settings(.importAccount(.presented(.importPrivateKeyResponse(.success)))):
                return .send(.activeIdentityCheck)

            case .account(.onAppear):
                if state.account.activeIdentitySet.isEmpty {
                    return .none
                }
                state.launchPhase = .ready
                return .none
            case .activeIdentityCheck:
                return .run { send in
                    await send(.activeIdentityResponse(
                        Result { try await walletClient.activeIdentitySet() }
                    ))
                }
            case .activeIdentityResponse(.success(let identity)):
                state.$activeIdentitySet.withLock { $0 = identity }
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
                            let existingChains: [Chain] = try await chainRegistry.listAllChains()
                            if existingChains.isEmpty {
                                // Insert preset chains with enabled status
                                let presetChains = ChainPresets.presetsWithEnabledStatus()
                                _ = try await chainRegistry.batchInsertChains(presetChains)
                            }
                            let existingStarknet = existingChains.filter { chain in
                                chain.chainId == Starknet.mainnet.chainId.description || chain.chainId == Starknet.sepolia.chainId.description
                            }
                            if existingStarknet.isEmpty {
                                _ = try await chainRegistry.batchInsertChains([Starknet.mainnet, Starknet.sepolia].map { chain in
                                    chain.toChain()
                                })
                            }
                            return try await chainRegistry.listAllChains()
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

extension SharedKey where Self == InMemoryKey<Chain>.Default {
    static var currentChain: Self {
        Self[.inMemory("currentChain"), default: EvmChain.sepolia.toChain()]
    }
}

extension SharedKey where Self == InMemoryKey<ActiveWalletIdentitySet>.Default {
    static var activeIdentitySet: Self {
        Self[.inMemory("activeIdentitySet"), default: ActiveWalletIdentitySet()]
    }
}
