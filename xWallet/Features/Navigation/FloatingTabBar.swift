//
//  FloatingTabBar.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var activeTab: String
    
    let tabs = [
        ("wallet.pass.fill", "wallet"),
        ("chart.bar.fill", "market"),
        ("safari.fill", "discover"),
        ("person.crop.circle.fill", "profile")
    ]
    
    var body: some View {
        HStack(spacing: 32) {
            ForEach(tabs, id: \.1) { icon, id in
                Button(action: {
                    withAnimation(.spring()) {
                        activeTab = id
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(activeTab == id ? .white : .gray)
                            .scaleEffect(activeTab == id ? 1.1 : 1.0)
                        
                        if activeTab == id {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                                .transition(.scale)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 32)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 5)
    }
}
