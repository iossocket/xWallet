//
//  AssetListView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI

struct AssetListView: View {
    var showBalance: Bool
    
    // Mock Data
    let assets = [
        AssetItem(symbol: "ETH", name: "Ethereum", balance: "1.45", value: "4,125.71", change: "+2.4%", icon: "diamond.fill", color: .indigo),
        AssetItem(symbol: "USDT", name: "Tether", balance: "1,240.50", value: "1,240.50", change: "+0.01%", icon: "dollarsign.circle.fill", color: .green),
        AssetItem(symbol: "BTC", name: "Bitcoin", balance: "0.045", value: "2,890.35", change: "-1.2%", icon: "bitcoinsign.circle.fill", color: .orange),
        AssetItem(symbol: "SOL", name: "Solana", balance: "45.20", value: "6,563.04", change: "+8.5%", icon: "s.circle.fill", color: .cyan),
        AssetItem(symbol: "DOGE", name: "Dogecoin", balance: "12,000", value: "1,440.00", change: "+1.5%", icon: "pawprint.fill", color: .yellow)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 列表标题
            HStack(alignment: .lastTextBaseline) {
                Text("Assets")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 20) {
                    Text("Tokens")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .overlay(Rectangle().frame(height: 2).foregroundColor(.blue).offset(y: 4), alignment: .bottom)
                    Text("NFTs")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Text("DeFi")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal)
            
            // 列表项
            VStack(spacing: 12) {
                ForEach(assets) { asset in
                    AssetRow(asset: asset, showBalance: showBalance)
                }
                
                // More 按钮
                HStack {
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.gray)
                        .padding()
                    Spacer()
                }
            }
        }
        .padding(.top, 20)
        // 列表背景：上淡下深
        .background(
            LinearGradient(colors: [Color.white.opacity(0.02), Color.black], startPoint: .top, endPoint: .bottom)
        )
        // 顶部圆角
        .clipShape(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]))
        // 顶部光泽边框
        .overlay(
            RoundedCorner(radius: 32, corners: [.topLeft, .topRight])
                .stroke(LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
    }
}
