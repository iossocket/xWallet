//
//  AppFeatureTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 6/3/26.
//

import ComposableArchitecture
import Testing
import EthereumKit
import SwiftUI

@testable import xWallet

@MainActor
@Suite(.serialized)
struct AppFeatureTests {

    // MARK: - Biometric Setup

    @Test
    func firstLaunchBiometricSetupSuccess() async {
        var state = AppFeature.State()
        state.$biometricSetupCompleted.withLock { $0 = false }

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        } withDependencies: {
            $0.defaultAppStorage = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
            $0.biometricService.checkAvailability = { .available(.faceID) }
            $0.biometricService.authenticate = { _ in }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.checkBiometric)

        await store.receive(\.biometricStatusChecked) {
            $0.biometricStatus = .available(.faceID)
            $0.launchPhase = .biometricSetup
            $0.$biometricSetupCompleted.withLock { $0 = true }
        }

        await store.receive(\.authenticate)

        await store.receive(\.authenticateResponse)

        await store.receive(\.activeIdentityCheck)

        await store.receive(\.activeIdentityResponse) {
            $0.launchPhase = .needsOnboarding
        }
    }

    @Test
    func firstLaunchNoPasscodeBlocksApp() async {
        let store = TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.biometricService.checkAvailability = { .unavailable(.noPasscode) }
        }

        await store.send(.checkBiometric)

        await store.receive(\.biometricStatusChecked) {
            $0.biometricStatus = .unavailable(.noPasscode)
            $0.launchPhase = .biometricSetup
        }
    }

    @Test
    func subsequentLaunchSkipsBiometricSetup() async {
        var state = AppFeature.State()
        state.$biometricSetupCompleted.withLock { $0 = true }

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        } withDependencies: {
            $0.biometricService.checkAvailability = { .available(.faceID) }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.checkBiometric)

        await store.receive(\.biometricStatusChecked) {
            $0.biometricStatus = .available(.faceID)
        }

        await store.receive(\.activeIdentityCheck)

        await store.receive(\.activeIdentityResponse) {
            $0.launchPhase = .needsOnboarding
        }
    }

    // MARK: - Scene Phase & Lock

    @Test
    func backgroundSetsOverlay() async {
        var state = AppFeature.State()
        state.launchPhase = .ready

        let now = Date(timeIntervalSince1970: 1000)

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        } withDependencies: {
            $0.date = .constant(now)
        }

        await store.send(.scenePhaseChanged(.background)) {
            $0.backgroundedAt = now
            $0.showPrivacyOverlay = true
        }
    }

    @Test
    func foregroundWithinTimeoutUnlocks() async {
        let bgTime = Date(timeIntervalSince1970: 1000)
        let fgTime = Date(timeIntervalSince1970: 1060) // 60s later

        var state = AppFeature.State()
        state.launchPhase = .ready
        state.backgroundedAt = bgTime
        state.showPrivacyOverlay = true
        // default timeout is 300s (5 min), 60s < 300s

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        } withDependencies: {
            $0.date = .constant(fgTime)
        }

        await store.send(.scenePhaseChanged(.active)) {
            $0.showPrivacyOverlay = false
            $0.backgroundedAt = nil
        }
    }

    @Test
    func foregroundExceedingTimeoutLocks() async {
        let bgTime = Date(timeIntervalSince1970: 1000)
        let fgTime = Date(timeIntervalSince1970: 1400) // 400s later

        var state = AppFeature.State()
        state.launchPhase = .ready
        state.backgroundedAt = bgTime
        state.showPrivacyOverlay = true

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        } withDependencies: {
            $0.date = .constant(fgTime)
            $0.biometricService.authenticate = { _ in }
        }

        await store.send(.scenePhaseChanged(.active)) {
            $0.needsAuth = true
            $0.backgroundedAt = nil
        }

        await store.receive(\.authenticate)

        await store.receive(\.authenticateResponse) {
            $0.showPrivacyOverlay = false
            $0.needsAuth = false
        }
    }

    @Test
    func authFailureKeepsOverlay() async {
        var state = AppFeature.State()
        state.launchPhase = .ready
        state.showPrivacyOverlay = true
        state.needsAuth = false

        enum AuthError: Error { case denied }

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        } withDependencies: {
            $0.biometricService.authenticate = { _ in throw AuthError.denied }
        }

        await store.send(.authenticate)

        await store.receive(\.authenticateResponse) {
            $0.needsAuth = true
        }
    }

    @Test
    func onboardingPhaseIgnoresSceneChange() async {
        var state = AppFeature.State()
        state.launchPhase = .needsOnboarding

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        }

        await store.send(.scenePhaseChanged(.active))
    }

    @Test
    func inactiveSetsOverlay() async {
        var state = AppFeature.State()
        state.launchPhase = .ready

        let store = TestStore(
            initialState: state
        ) {
            AppFeature()
        }

        await store.send(.scenePhaseChanged(.inactive)) {
            $0.showPrivacyOverlay = true
        }
    }
    @Test
    func initializeChainsWhenDatabaseEmpty() async {
        let presetChains = ChainPresets.presetsWithEnabledStatus()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { [] }  // Empty database
            $0.chainRegistry.batchInsertChains = { chains in
                return presetChains
            }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.initializeChains)

        await store.receive(\.initializeChainsResponse)
    }

    @Test
    func initializeChainsWhenDatabaseNotEmpty() async {
        let existingChains = [EvmChain.sepolia, EvmChain.mainnet].map { $0.toChain() }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { existingChains }  // Database has chains
            $0.chainRegistry.batchInsertChains = { chains in
                return chains  // Starknet chains still need inserting
            }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.initializeChains)

        await store.receive(\.initializeChainsResponse)
    }

    @Test
    func initializeChainsHandlesError() async {
        enum DummyError: Error {
            case databaseError
        }

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.chainRegistry.listAllChains = { throw DummyError.databaseError }
            $0.walletClient.activeIdentitySet = { throw WalletError.noActiveIdentity }
        }

        await store.send(.initializeChains)

        await store.receive(\.initializeChainsResponse)
    }
}
