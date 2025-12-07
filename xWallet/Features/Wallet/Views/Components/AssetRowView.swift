//
//  AssetRowView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI

struct AssetRow: View {
    let asset: AssetItem
    var showBalance: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(asset.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: asset.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(asset.color.opacity(0.9))
            }
            
            // 名称
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(asset.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // 价值
            VStack(alignment: .trailing, spacing: 4) {
                Text(showBalance ? "$\(asset.value)" : "****")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                
                Text(asset.change)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(asset.change.hasPrefix("+") ? .green : .red)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
