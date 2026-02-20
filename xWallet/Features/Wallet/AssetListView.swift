//
//  AssetListView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI

struct AssetListView: View {
    var showBalance: Bool
    var assets: [AssetItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // List title
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
            
            // List items
            VStack(spacing: 12) {
                ForEach(assets) { asset in
                    AssetRow(asset: asset, showBalance: showBalance)
                }
                
                // More button
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
        // List background: light at top, dark at bottom
        .background(
            LinearGradient(colors: [Color.white.opacity(0.02), Color.black], startPoint: .top, endPoint: .bottom)
        )
        // Top rounded corners
        .clipShape(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]))
        // Top glossy border
        .overlay(
            RoundedCorner(radius: 32, corners: [.topLeft, .topRight])
                .stroke(LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
    }
}
