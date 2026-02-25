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
        }
    }
    
    
    @ViewBuilder
    private var root: some View {
        switch store.launchPhase {
        case .booting, .needsOnboarding:
            ImportAccountView(
                store: store.scope(state: \.account, action: \.account)
            )
        case .ready:
            ContentView(store: store)
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

