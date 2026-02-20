//
//  DashboardRingView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct DashboardRingView: View {
    var showBalance: Bool
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 24)
                .frame(width: 280, height: 280)
            
            // Progress ring (gradient)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .blue]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .shadow(color: .blue.opacity(0.4), radius: 20, x: 0, y: 0) // Glow effect
            
            // Inner decorative light
            Circle()
                .fill(Color.blue.opacity(0.05))
                .frame(width: 200, height: 200)
                .blur(radius: 30)
            
            // Center content
            VStack(spacing: 12) {
                Text("Main Portfolio")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.gray)
                    .textCase(.uppercase)
                
                // Wallet icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
                    
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                
                VStack(spacing: 4) {
                    Text("Wallet 01")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: .green, radius: 4)
                        
                        Text("Ethereum Mainnet")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.bottom, 40) // Reserve space for console below
    }
}
