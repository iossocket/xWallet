//
//  WalletTabView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import SwiftUI
import ComposableArchitecture

struct WalletTabView: View {
    @Bindable var store: StoreOf<Wallet>
    
    private var showBalanceBinding: Binding<Bool> {
        $store.showBalance.sending(\.setShowBalance)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Global aurora background (Layer 0)
            AuroraBackground()
            
            // 2. Main scroll view (Layer 1)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        showBalance: showBalanceBinding,
                        totalBalance: store.totalUsdValue,
                        currentChain: store.currentChain,
                        supportedChains: store.supportedChains,
                        onChainChanged: { store.send(.chainChanged($0)) }
                    )
                        .padding(.top, 60) // Adapt to notch area at top
                        .padding(.horizontal)
                    
                    // Dashboard ring (Dashboard Core)
                    DashboardRingView(
                        showBalance: store.showBalance,
                        currentChainName: store.currentChain.name,
                        totalUsdValue: store.totalUsdValue,
                        currentChainUsdValue: store.currentChainUsdValue
                    )
                        .padding(.top, 20)
                        .zIndex(1) // Ensure layer is above elements below
                    
                    // Floating action console
                    // Use negative offset to achieve "overlapping" effect
                    ActionConsoleView(
                        sendButtonTapped: { [weak store] in
                            store?.send(.sendButtonTapped)
                        },
                        receiveButtonTapped: { [weak store] in
                            store?.send(.receiveButtonTapped)
                        }
                    )
                        .offset(y: -40)
                        .padding(.bottom, -20)
                        .zIndex(2)
                    
                    // Asset list (Asset Drawer)
                    AssetListView(showBalance: store.showBalance, assets: store.assets)
                        .padding(.bottom, 100) // Reserve space for bottom navigation bar
                }
            }
            // Key: Make ScrollView width adapt to screen, prevent being stretched by internal elements (though current internal elements are not oversized)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "050505")) // Dark background
        .ignoresSafeArea() // Let background fill entire screen
        .preferredColorScheme(.dark) // Force dark mode
        .sheet(item: $store.scope(state: \.receive, action: \.receive), content: { receiveStore in
            ReceiveView(store: receiveStore)
                .presentationDetents([.fraction(0.65)])
                .presentationCornerRadius(32)
        })
        .sheet(
            item: $store.scope(state: \.send, action: \.send)
        ) { sendStore in
            NavigationStack {
                SendView(store: sendStore)
            }
        }
        .task {
            store.send(.onAppear)
        }
    }
}
