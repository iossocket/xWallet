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
            // 1. 全局极光背景 (Layer 0)
            AuroraBackground()
            
            // 2. 主滚动视图 (Layer 1)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 头部 (Header)
                    HeaderView(showBalance: $showBalance, totalBalance: totalBalance)
                        .padding(.top, 60) // 适配刘海屏顶部
                        .padding(.horizontal)
                    
                    // 仪表盘圆环 (Dashboard Core)
                    DashboardRingView(showBalance: showBalance)
                        .padding(.top, 20)
                        .zIndex(1) // 确保层级高于下方元素
                    
                    // 悬浮控制台 (Action Console)
                    // 使用负偏移量实现 "层叠" 效果
                    ActionConsoleView(showReceiveSheet: $showReceiveSheet)
                        .offset(y: -40)
                        .padding(.bottom, -20)
                        .zIndex(2)
                    
                    // 资产列表 (Asset Drawer)
                    AssetListView(showBalance: showBalance)
                        .padding(.bottom, 100) // 为底部导航栏留出空间
                }
            }
            // 关键：让 ScrollView 宽度自适应屏幕，防止被内部元素撑开（虽然目前内部元素没有超宽的）
            .frame(maxWidth: .infinity)
            
            // 3. 悬浮底部导航 (Layer 2)
            FloatingTabBar(activeTab: $activeTab)
                .padding(.bottom, 20)
        }
        .background(Color(hex: "050505")) // 深色底色
        .ignoresSafeArea() // 让背景铺满全屏
        .preferredColorScheme(.dark) // 强制深色模式
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveView()
                .presentationDetents([.fraction(0.65)]) // 半屏抽屉
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
    }
}

// Preview
#Preview {
    ContentView()
}
