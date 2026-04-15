//
//  RootView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 14/1/26.
//

import SwiftUI
import ComposableArchitecture

struct RootView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        root.task {
            store.send(.initializeChains)
            store.send(.checkBiometric)
        }
    }

    @ViewBuilder
    private var root: some View {
        switch store.launchPhase {
        case .launching:
            Color.xBg0.ignoresSafeArea()
        case .biometricSetup:
            BiometricSetupView(store: store)
        case .needsOnboarding:
            ImportAccountView(
                store: store.scope(state: \.account, action: \.account)
            )
        case .ready:
            ContentView(store: store)
                .overlay {
                    if store.showPrivacyOverlay {
                        PrivacyOverlayView(store: store)
                            .opacity(store.showPrivacyOverlay ? 1 : 0)
                            .animation(.xTransition, value: store.showPrivacyOverlay)
                    }
                }
        }
    }
}

// Preview
#Preview {
    RootView(
        store: Store(initialState: AppFeature.State(), reducer: {
            AppFeature()
        })
    )
}
