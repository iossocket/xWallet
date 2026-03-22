//
//  DashboardRingView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct DashboardRingView: View {
    var showBalance: Bool
    var isLoading: Bool = false
    var currentChainName: String = ""
    var totalUsdValue: String?
    var currentChainUsdValue: String?
    @State private var loadingRotation: Double = 0

    private var chainRatio: Double {
        let total = parseUsd(totalUsdValue ?? "0.00")
        guard total > 0 else { return 0 }
        return min(parseUsd(currentChainUsdValue ?? "0.00") / total, 1)
    }

    private var percentText: String {
        "\(Int(chainRatio * 100))%"
    }

    private var displayedPercentText: String {
        guard showBalance else { return "**%" }
        return isLoading ? "--%" : percentText
    }

    private var displayedChainValueText: String {
        guard showBalance else { return "****" }
        return isLoading ? "Loading..." : (currentChainUsdValue ?? "0.00")
    }

    var body: some View {
        ZStack {
            // Background ring (full circle)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 24)
                .frame(width: 280, height: 280)

            if isLoading {
                Circle()
                    .trim(from: 0.08, to: 0.34)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.xAccent.opacity(0.15),
                                Color.xAccentLight,
                                Color.xAccent
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(loadingRotation - 90))
                    .shadow(color: Color.xAccent.opacity(0.45), radius: 20)
            } else {
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
            }

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
                    Text(displayedPercentText)
                        .font(Font.xTitle1)
                        .foregroundStyle(Color.xTextPrimary)
                        .contentTransition(.numericText())
                        .animation(.xNumeric, value: displayedPercentText)

                    // Current chain USD value
                    Text(displayedChainValueText)
                        .font(Font.xCaption)
                        .foregroundStyle(Color.xTextSecondary)
                }
            }
        }
        .padding(.bottom, 40)
        .onAppear {
            updateLoadingAnimation()
        }
        .onChange(of: isLoading) { _, _ in
            updateLoadingAnimation()
        }
    }

    private func parseUsd(_ str: String) -> Double {
        Double(str.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) ?? 0
    }

    private func updateLoadingAnimation() {
        guard isLoading else {
            withAnimation(.easeOut(duration: 0.2)) {
                loadingRotation = 0
            }
            return
        }

        loadingRotation = 0
        withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
            loadingRotation = 360
        }
    }
}
