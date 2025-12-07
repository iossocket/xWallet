//
//  ActionButton.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI

struct ActionButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action?()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.05))
                        .frame(width: 50, height: 50)
                        .shadow(color: isActive ? .white.opacity(0.2) : .clear, radius: 10)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isActive ? .black : .white)
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? .white : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
