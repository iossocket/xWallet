import SwiftUI

// MARK: - Main View
struct ContentView: View {
    // UI State
    @State private var activeTab: String = "wallet"
    @State private var showBalance: Bool = true
    @State private var showReceiveSheet: Bool = false
    
    // Mock Data
    let totalBalance = "16,819.60"
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Global aurora background (Layer 0)
            AuroraBackground()
            
            // 2. Main scroll view (Layer 1)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HeaderView(showBalance: $showBalance, totalBalance: totalBalance)
                        .padding(.top, 60) // Adapt to notch area at top
                        .padding(.horizontal)
                    
                    // Dashboard ring (Dashboard Core)
                    DashboardRingView(showBalance: showBalance)
                        .padding(.top, 20)
                        .zIndex(1) // Ensure layer is above elements below
                    
                    // Floating action console
                    // Use negative offset to achieve "overlapping" effect
                    ActionConsoleView(showReceiveSheet: $showReceiveSheet)
                        .offset(y: -40)
                        .padding(.bottom, -20)
                        .zIndex(2)
                    
                    // Asset list (Asset Drawer)
                    AssetListView(showBalance: showBalance)
                        .padding(.bottom, 100) // Reserve space for bottom navigation bar
                }
            }
            // Key: Make ScrollView width adapt to screen, prevent being stretched by internal elements (though current internal elements are not oversized)
            .frame(maxWidth: .infinity)
            
            // 3. Floating bottom navigation (Layer 2)
            FloatingTabBar(activeTab: $activeTab)
                .padding(.bottom, 20)
        }
        .background(Color(hex: "050505")) // Dark background
        .ignoresSafeArea() // Let background fill entire screen
        .preferredColorScheme(.dark) // Force dark mode
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveView()
                .presentationDetents([.fraction(0.65)]) // Half-screen drawer
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
    }
}

// Preview
#Preview {
    ContentView()
}
