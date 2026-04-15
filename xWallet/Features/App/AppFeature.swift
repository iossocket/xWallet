//
//  AppFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import EthereumKit
import StarknetKit

enum LaunchPhase: Equatable {
    case launching
    case biometricSetup
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
        var launchPhase: LaunchPhase = .launching
        var selectedTab: Tab = .wallet
        var settings = Settings.State()
        var wallet = Wallet.State()
        @Shared(.activeIdentitySet) var activeIdentitySet: ActiveWalletIdentitySet

        // Biometric lock
        var showPrivacyOverlay: Bool = false
        var needsAuth: Bool = false
        var backgroundedAt: Date? = nil
        var biometricStatus: BiometricStatus = .unknown
        @Shared(.appStorage("lockTimeout")) var lockTimeout: Int = LockTimeout.immediate.rawValue
        @Shared(.appStorage("biometricSetupCompleted")) var biometricSetupCompleted: Bool = false
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

        // Biometric lock
        case scenePhaseChanged(ScenePhase)
        case checkBiometric
        case biometricStatusChecked(BiometricStatus)
        case authenticate
        case authenticateResponse(Result<Void, Error>)
    }

    @Dependency(\.walletClient) var walletClient
    @Dependency(\.chainRegistry) var chainRegistry
    @Dependency(\.biometricClient) var biometricClient
    @Dependency(\.date.now) var now
    
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
        Reduce { [walletClient, chainRegistry, biometricClient, now] state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
            case .account(.switchWalletResponse(.success)):
                state.launchPhase = .ready
                return .none

            case .settings(.importAccount(.presented(.switchWalletResponse(.success)))):
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
            // MARK: - Biometric Lock

            case .scenePhaseChanged(.background):
                state.backgroundedAt = now
                state.showPrivacyOverlay = true
                state.needsAuth = false
                return .none

            case .scenePhaseChanged(.inactive):
                state.showPrivacyOverlay = true
                return .none

            case .scenePhaseChanged(.active):
                guard state.launchPhase == .ready else {
                    return .none
                }
                guard !state.needsAuth else {
                    return .none
                }
                if let bg = state.backgroundedAt,
                   now.timeIntervalSince(bg) > TimeInterval(state.lockTimeout) {
                    state.needsAuth = true
                    state.backgroundedAt = nil
                    return .send(.authenticate)
                } else {
                    state.showPrivacyOverlay = false
                    state.backgroundedAt = nil
                    return .none
                }

            case .scenePhaseChanged:
                return .none

            case .checkBiometric:
                return .run { send in
                    let status = biometricClient.checkAvailability()
                    await send(.biometricStatusChecked(status))
                }

            case .biometricStatusChecked(let status):
                state.biometricStatus = status
                if case .unavailable(.noPasscode) = status {
                    state.launchPhase = .biometricSetup
                    return .none
                }
                if !state.biometricSetupCompleted {
                    state.launchPhase = .biometricSetup
                    return .send(.authenticate)
                }
                return .send(.activeIdentityCheck)

            case .authenticate:
                return .run { send in
                    try await biometricClient.authenticate("Verify identity to continue")
                    await send(.authenticateResponse(.success(())))
                } catch: { error, send in
                    await send(.authenticateResponse(.failure(error)))
                }

            case .authenticateResponse(.success):
                if state.launchPhase == .biometricSetup {
                    state.$biometricSetupCompleted.withLock { $0 = true }
                    state.showPrivacyOverlay = false
                    state.needsAuth = false
                    return .send(.activeIdentityCheck)
                }
                state.showPrivacyOverlay = false
                state.needsAuth = false
                return .none

            case .authenticateResponse(.failure):
                state.needsAuth = true
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
