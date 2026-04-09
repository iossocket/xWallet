//
//  AccountDeployView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 8/4/26.
//

import SwiftUI
import ComposableArchitecture
import BigInt
import UIKit
import Foundation
import StarknetKit

struct AccountDeployView: View {
    @Bindable var store: StoreOf<AccountDeploy>

    var body: some View {
        ZStack {
            Color.xBg0.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: XSpacing.xl) {
                    header
                    phaseContent
                }
                .padding(XSpacing.lg)
            }
        }
        .onAppear { store.send(.onAppear) }
        .navigationTitle("Activate Starknet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: XSpacing.md) {
            Text("Activate your account")
                .font(.xTitle1)
                .foregroundStyle(Color.xTextPrimary)
            Text("Your address needs on-chain activation before sending transactions.")
                .font(.xBody)
                .foregroundStyle(Color.xTextSecondary)
            addressCard
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: XSpacing.sm) {
            Text("Address")
                .font(.xCaption)
                .foregroundStyle(Color.xTextSecondary)
            Text(store.address)
                .font(.xMono)
                .foregroundStyle(Color.xTextPrimary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(XSpacing.lg)
        .xSolidCard()
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch store.phase {
        case .checkBalance:
            loadingCard(title: "Checking balance", subtitle: "Checking whether this address has enough STRK for deployment.")
        case .estimating:
            loadingCard(title: "Estimating deployment fee", subtitle: "Preparing and estimating the fee required for activation.")
        case .insufficientFunds:
            insufficientFundsCard
        case .readyToDeploy:
            readyCard
        case .deploying:
            loadingCard(title: "Deploying account", subtitle: "Sending deploy transaction to Starknet.")
        case .pending(let txHash):
            pendingCard(txHash: txHash)
        case .success:
            successCard
        case .failure:
            failureCard
        }
    }

    private func loadingCard(title: String, subtitle: String) -> some View {
        VStack(spacing: XSpacing.lg) {
            ProgressView()
                .tint(Color.xTextPrimary)
                .scaleEffect(1.2)
            Text(title)
                .font(.xTitle2)
                .foregroundStyle(Color.xTextPrimary)
            Text(subtitle)
                .font(.xBody)
                .foregroundStyle(Color.xTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(XSpacing.xxl)
        .xSolidCard()
    }

    private var insufficientFundsCard: some View {
        VStack(alignment: .leading, spacing: XSpacing.lg) {
            Text("Insufficient STRK")
                .font(.xTitle2)
                .foregroundStyle(Color.xYellow)
            Text("Please transfer STRK to this address, then re-check your balance.")
                .font(.xBody)
                .foregroundStyle(Color.xTextSecondary)

            if let balance = store.balance {
                balanceRow(label: "Current Balance", value: "\(balance) WEI")
            }

            HStack(spacing: XSpacing.md) {
                Button("Copy Address") {
                    UIPasteboard.general.string = store.address
                }
                .font(.xBodyMedium)
                .foregroundStyle(Color.xTextPrimary)
                .padding(.vertical, XSpacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.xBg2)
                .clipShape(RoundedRectangle(cornerRadius: XRadius.md))

                Button("Recheck") {
                    store.send(.retryTapped)
                }
                .font(.xBodyMedium)
                .foregroundStyle(.black)
                .padding(.vertical, XSpacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.xTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: XRadius.md))
            }
        }
        .padding(XSpacing.lg)
        .xSolidCard()
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: XSpacing.lg) {
            Text("Ready to deploy")
                .font(.xTitle2)
                .foregroundStyle(Color.xTextPrimary)

            if let fee = store.estimatedFee {
                balanceRow(label: "Estimated Fee", value: "\(fee.overallFee) \(fee.feeUnit)")
            }

            ActionButton(icon: "bolt.fill", label: "Deploy", isActive: true) {
                store.send(.deployTapped)
            }
        }
        .padding(XSpacing.lg)
        .xSolidCard()
    }

    private func pendingCard(txHash: String) -> some View {
        VStack(alignment: .leading, spacing: XSpacing.lg) {
            HStack(spacing: XSpacing.md) {
                ProgressView().tint(Color.xTextPrimary)
                Text("Waiting for confirmation")
                    .font(.xTitle2)
                    .foregroundStyle(Color.xTextPrimary)
            }
            Text("Transaction Hash")
                .font(.xCaption)
                .foregroundStyle(Color.xTextSecondary)
            Text(txHash)
                .font(.xMonoSm)
                .foregroundStyle(Color.xTextPrimary)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
        }
        .padding(XSpacing.lg)
        .xSolidCard()
    }

    private var successCard: some View {
        VStack(spacing: XSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.xGreen)
            Text("Account activated")
                .font(.xTitle1)
                .foregroundStyle(Color.xTextPrimary)
            Text("Your Starknet account is ready to use.")
                .font(.xBody)
                .foregroundStyle(Color.xTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(XSpacing.xxl)
        .xSolidCard()
    }

    private var failureCard: some View {
        VStack(alignment: .leading, spacing: XSpacing.lg) {
            Text("Activation failed")
                .font(.xTitle2)
                .foregroundStyle(Color.xRed)
            if let message = store.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.xBody)
                    .foregroundStyle(Color.xTextSecondary)
            }
            Button("Retry") {
                store.send(.retryTapped)
            }
            .font(.xBodyMedium)
            .foregroundStyle(.black)
            .padding(.vertical, XSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.xTextPrimary)
            .clipShape(RoundedRectangle(cornerRadius: XRadius.md))
        }
        .padding(XSpacing.lg)
        .xSolidCard()
    }

    private func balanceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.xBody)
                .foregroundStyle(Color.xTextSecondary)
            Spacer()
            Text(value)
                .font(.xMono)
                .foregroundStyle(Color.xTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
