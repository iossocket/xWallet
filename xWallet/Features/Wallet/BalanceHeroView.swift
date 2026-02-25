//
//  BalanceHeroView.swift
//  xWallet
//
//  Replaces DashboardRingView. Shows total balance, daily change,
//  and a chain distribution pill row. Much higher information density.
//

import SwiftUI

struct BalanceHeroView: View {
    let totalBalance: String
    let showBalance: Bool
    let dailyChange: String
    let dailyChangePct: String
    let isPositive: Bool
    let chains: [ChainPill]

    struct ChainPill: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: XSpacing.xl) {
            // Balance block
            VStack(alignment: .leading, spacing: XSpacing.sm) {
                Text("TOTAL BALANCE")
                    .font(.xLabel)
                    .foregroundStyle(Color.xTextTertiary)
                    .tracking(1.5)

                if showBalance {
                    Text("$\(totalBalance)")
                        .font(.xDisplay)
                        .foregroundStyle(Color.xTextPrimary)
                        .contentTransition(.numericText())
                        .animation(.xNumeric, value: totalBalance)
                } else {
                    Text("$••••••")
                        .font(.xDisplay)
                        .foregroundStyle(Color.xTextSecondary)
                }

                // Daily change
                HStack(spacing: XSpacing.xs) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.xCaptionBold)
                    Text(showBalance ? "\(dailyChange)  \(dailyChangePct) today" : "••••")
                        .font(.xCaptionBold)
                }
                .foregroundStyle(isPositive ? Color.xGreen : Color.xRed)
                .padding(.horizontal, XSpacing.md)
                .padding(.vertical, XSpacing.xs)
                .background((isPositive ? Color.xGreen : Color.xRed).opacity(0.12))
                .clipShape(Capsule())
            }

            // Chain distribution pills
            HStack(spacing: XSpacing.sm) {
                ForEach(chains) { chain in
                    HStack(spacing: XSpacing.xs) {
                        Circle()
                            .fill(chain.color)
                            .frame(width: 6, height: 6)
                            .shadow(color: chain.color.opacity(0.8), radius: 3)
                        Text(chain.name)
                            .font(.xLabel)
                            .foregroundStyle(Color.xTextSecondary)
                    }
                    .padding(.horizontal, XSpacing.md)
                    .padding(.vertical, XSpacing.sm)
                    .background(Color.xBg2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.xBorder, lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, XSpacing.xxxl)
        .padding(.vertical, XSpacing.xxl)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.xBg0.ignoresSafeArea()
        BalanceHeroView(
            totalBalance: "12,483.20",
            showBalance: true,
            dailyChange: "+$234.50",
            dailyChangePct: "+1.92%",
            isPositive: true,
            chains: [
                .init(name: "Ethereum", color: Color(hex: "627EEA")),
                .init(name: "Starknet", color: Color(hex: "EC796B")),
                .init(name: "+2 more", color: Color.xTextTertiary),
            ]
        )
    }
}
