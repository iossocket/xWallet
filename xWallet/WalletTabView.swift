//
//  WalletTabView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/1/26.
//

import SwiftUI

struct WalletTabView: View {
    let state: WalletState
    let send: (WalletAction) -> Void
    
    private var showBallanceBinding: Binding<Bool> {
        Binding(
            get: { state.showBalance },
            set: { _ in send(.toggleShowBalance) }
        )
    }
    
    private var receiveSheetBinding: Binding<Bool> {
        Binding(
            get: { state.isReceiveSheetPresented },
            set: { newValue in
                if newValue == false {
                    send(.receiveSheetDismissed)
                }
            }
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Global aurora background (Layer 0)
            AuroraBackground()
            
            // 2. Main scroll view (Layer 1)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HeaderView(showBalance: showBallanceBinding, totalBalance: state.totalBalance)
                        .padding(.top, 60) // Adapt to notch area at top
                        .padding(.horizontal)
                    
                    // Dashboard ring (Dashboard Core)
                    DashboardRingView(showBalance: state.showBalance)
                        .padding(.top, 20)
                        .zIndex(1) // Ensure layer is above elements below
                    
                    // Floating action console
                    // Use negative offset to achieve "overlapping" effect
                    ActionConsoleView(showReceiveSheet: showBallanceBinding)
                        .offset(y: -40)
                        .padding(.bottom, -20)
                        .zIndex(2)
                    
                    // Asset list (Asset Drawer)
                    AssetListView(showBalance: state.showBalance, assets: state.assets)
                        .padding(.bottom, 100) // Reserve space for bottom navigation bar
                }
            }
            // Key: Make ScrollView width adapt to screen, prevent being stretched by internal elements (though current internal elements are not oversized)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "050505")) // Dark background
        .ignoresSafeArea() // Let background fill entire screen
        .preferredColorScheme(.dark) // Force dark mode
        .sheet(isPresented: receiveSheetBinding) {
            ReceiveView()
                .presentationDetents([.fraction(0.65)]) // Half-screen drawer
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .onAppear {
            send(.refreshTapped)
        }
    }
}
