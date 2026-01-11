//
//  AssetItem.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI

struct AssetItem: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let name: String
    let balance: String
    let value: String
    let change: String
    let icon: String
    let color: Color
}


extension AssetItem {
    static let preset: [AssetItem] = [
        AssetItem(symbol: "ETH", name: "Ethereum", balance: "1.45", value: "4,125.71", change: "+2.4%", icon: "diamond.fill", color: .indigo),
        AssetItem(symbol: "USDT", name: "Tether", balance: "1,240.50", value: "1,240.50", change: "+0.01%", icon: "dollarsign.circle.fill", color: .green),
        AssetItem(symbol: "BTC", name: "Bitcoin", balance: "0.045", value: "2,890.35", change: "-1.2%", icon: "bitcoinsign.circle.fill", color: .orange),
        AssetItem(symbol: "SOL", name: "Solana", balance: "45.20", value: "6,563.04", change: "+8.5%", icon: "s.circle.fill", color: .cyan),
        AssetItem(symbol: "DOGE", name: "Dogecoin", balance: "12,000", value: "1,440.00", change: "+1.5%", icon: "pawprint.fill", color: .yellow)
    ]
}
