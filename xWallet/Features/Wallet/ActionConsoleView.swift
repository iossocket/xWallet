//
//  ActionConsoleView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//
import SwiftUI

struct ActionConsoleView: View {
    var sendButtonTapped: () -> Void
    var receiveButtonTapped: () -> Void
    var historyButtonTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ActionButton(icon: "arrow.up.right", label: "Send", isActive: true) {
                sendButtonTapped()
            }
            ActionButton(icon: "arrow.down.left", label: "Receive", isActive: true) {
                receiveButtonTapped()
            }
            ActionButton(icon: "clock.arrow.circlepath", label: "History", isActive: true) {
                historyButtonTapped()
            }
            ActionButton(icon: "plus", label: "Buy")
        }
        .padding(12)
        .background(.ultraThinMaterial) // Key: Frosted glass background
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding(.horizontal, 30)
    }
}
