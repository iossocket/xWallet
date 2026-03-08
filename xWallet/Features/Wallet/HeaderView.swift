//
//  HeaderView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI
import EthereumKit

struct HeaderView: View {
    @Binding var showBalance: Bool
    let totalBalance: String?
    let currentChain: EvmChainRecord
    let supportedChains: [EvmChainRecord]
    let onChainChanged: (EvmChainRecord) -> Void

    var body: some View {
        HStack {
            // Left side user info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color(white: 0.2), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                    Image(systemName: "person.fill")
                        .foregroundStyle(.gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL NET WORTH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                        .tracking(1)

                    HStack(spacing: 6) {
                        Text(showBalance ? "$\(totalBalance ?? "--")" : "****")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())

                        Image(systemName: showBalance ? "chevron.down" : "eye.slash.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showBalance.toggle()
                        }
                    }
                }
            }

            Spacer()

            // Right side: chain selector
            Menu {
                ForEach(supportedChains, id: \.chainId) { chain in
                    Button {
                        onChainChanged(chain)
                    } label: {
                        HStack {
                            Text(chain.name)
                            if chain == currentChain {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(currentChain.isTestnet ? Color.yellow : Color.xAccent)
                        .frame(width: 6, height: 6)
                    Text(currentChain.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(minWidth: 120, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
}
