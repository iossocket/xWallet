//
//  DashboardRingView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct DashboardRingView: View {
    var showBalance: Bool
    var currentChainName: String = ""
    var totalUsdValue: String?
    var currentChainUsdValue: String?

    private var chainRatio: Double {
        let total = parseUsd(totalUsdValue ?? "0.00")
        guard total > 0 else { return 0 }
        return min(parseUsd(currentChainUsdValue ?? "0.00") / total, 1)
    }

    private var percentText: String {
        "\(Int(chainRatio * 100))%"
    }

    var body: some View {
        ZStack {
            // Background ring (full circle)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 24)
                .frame(width: 280, height: 280)

            // Progress ring — trimmed to chainRatio
            Circle()
                .trim(from: 0, to: chainRatio)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.xAccent, .purple, Color.xAccent]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 24, lineCap: .round)
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.xAccent.opacity(0.4), radius: 20)
                .animation(.xNumeric, value: chainRatio)

            // Inner decorative light
            Circle()
                .fill(Color.xAccent.opacity(0.05))
                .frame(width: 200, height: 200)
                .blur(radius: 30)

            // Center content
            VStack(spacing: XSpacing.md) {
                // Current chain badge
                HStack(spacing: XSpacing.xs) {
                    Circle()
                        .fill(Color.xGreen)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.xGreen, radius: 4)

                    Text(currentChainName)
                        .font(Font.xMonoSm)
                        .foregroundStyle(Color.xTextSecondary)
                }
                .padding(.horizontal, XSpacing.sm)
                .padding(.vertical, XSpacing.xs)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())

                // Wallet icon
                ZStack {
                    RoundedRectangle(cornerRadius: XRadius.xl)
                        .fill(
                            LinearGradient(colors: [Color.xAccent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.xAccent.opacity(0.4), radius: 15, y: 8)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.xTextPrimary)
                }

                VStack(spacing: XSpacing.xs) {
                    // Chain ratio percentage
                    Text(showBalance ? percentText : "**%")
                        .font(Font.xTitle1)
                        .foregroundStyle(Color.xTextPrimary)
                        .contentTransition(.numericText())
                        .animation(.xNumeric, value: percentText)

                    // Current chain USD value
                    Text(showBalance ? currentChainUsdValue ?? "0.00" : "****")
                        .font(Font.xCaption)
                        .foregroundStyle(Color.xTextSecondary)
                }
            }
        }
        .padding(.bottom, 40)
    }

    private func parseUsd(_ str: String) -> Double {
        Double(str.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
    }
}
