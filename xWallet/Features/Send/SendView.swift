//
//  SendView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 26/2/26.
//

import SwiftUI
import ComposableArchitecture

struct SendView: View {
    @Bindable var store: StoreOf<Send>

    var body: some View {
        ZStack {
            Color.xBg0.ignoresSafeArea()
            switch store.phase {
            case .input, .estimating:
                inputView
            case .confirm:
                confirmView
            case .sending:
                sendingView
            case .pending(let hash), .success(let hash):
                resultView(hash: hash, isSuccess: store.phase != .pending(hash))
            case .failure(let msg):
                failureView(message: msg)
            }
        }
        .navigationTitle("Send \(store.selectedAsset?.symbol ?? store.chain.symbol)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputView: some View {
        VStack(spacing: 20) {
            if !store.availableAssets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Asset").font(.xCaption).foregroundStyle(Color.xTextSecondary)
                    Menu {
                        ForEach(store.availableAssets) { asset in
                            Button {
                                store.send(.assetSelected(asset))
                            } label: {
                                HStack {
                                    Text(asset.symbol)
                                    Spacer()
                                    Text(asset.balance)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let selected = store.selectedAsset {
                                Text(selected.symbol).font(.xBodyMedium)
                                Spacer()
                                Text(selected.balance).font(.xCaption).foregroundStyle(Color.xTextSecondary)
                            } else {
                                Text("Select asset").foregroundStyle(Color.xTextSecondary)
                                Spacer()
                            }
                            Image(systemName: "chevron.down").font(.xCaption)
                        }
                        .foregroundStyle(Color.xTextPrimary)
                        .padding()
                        .background(Color.xBg2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("To address").font(.xCaption).foregroundStyle(Color.xTextSecondary)
                TextField("0x...", text: $store.toAddress)
                    .font(.xMono)
                    .foregroundStyle(Color.xTextPrimary)
                    .padding()
                    .background(Color.xBg2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.none)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Amount").font(.xCaption).foregroundStyle(Color.xTextSecondary)
                    Spacer()
                    if let selected = store.selectedAsset {
                        Text("Balance: \(selected.balance)").font(.xCaption).foregroundStyle(Color.xTextSecondary)
                    }
                }
                TextField("0.0", text: $store.amount)
                    .font(.xDisplaySm)
                    .foregroundStyle(Color.xTextPrimary)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(Color.xBg2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = store.errorMessage {
                Text(error).font(.xCaption).foregroundStyle(.red)
            }

            Spacer()

            Button {
                store.send(.estimateFeeTapped)
            } label: {
                Group {
                    if store.phase == .estimating {
                        ProgressView().tint(.black)
                    } else {
                        Text("Estimate Fee")
                            .font(.headline).foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity).padding()
                .background(canProceed ? .white : .white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(store.phase == .estimating || !canProceed)
        }
        .padding()
    }

    private var canProceed: Bool {
        guard !store.toAddress.isEmpty, !store.amount.isEmpty else { return false }
        guard let selected = store.selectedAsset else { return false }

        let balanceStr = selected.balance.replacingOccurrences(of: " \(selected.symbol)", with: "").trimmingCharacters(in: .whitespaces)
        guard let balance = Double(balanceStr), let amount = Double(store.amount) else { return false }

        return amount > 0 && amount <= balance
    }

    private var confirmView: some View {
        VStack(spacing: 16) {
            Text("Confirm transaction").font(.xTitle2.bold()).foregroundStyle(Color.xTextPrimary)

            VStack(spacing: 12) {
                feeRow("To Address", store.toAddress)
                feeRow("Amount", "\(store.amount) \(store.selectedAsset?.symbol ?? store.chain.symbol)")
                if let fee = store.feeEstimate {
                    switch fee {
                    case .evm(let tx):
                        feeRow("Gas Limit", "\(tx.gasLimit)")
                        feeRow("Max Fee", "\(tx.maxFeePerGas?.description ?? "—") Gwei")
                        feeRow("Priority Fee", "\(tx.maxPriorityFeePerGas?.description ?? "—") Gwei")
                    case .starknet(let estimate):
                        feeRow("Overall Fee", "\(estimate.overallFee) \(estimate.feeUnit)")
                        if let l2Gas = estimate.l2GasConsumed {
                            feeRow("L2 Gas", l2Gas)
                        } else if let gas = estimate.gasConsumed {
                            feeRow("Gas", gas)
                        }
                    }
                }
            }
            .padding()
            .background(Color.xBg2)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()

            Button {
                store.send(.confirmSendTapped)
            } label: {
                Text("Confirm")
                    .font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button { store.send(.dismissError) } label: {
                Text("Cancel").foregroundStyle(Color.xTextSecondary)
            }
        }
        .padding()
    }

    private func feeRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.xBody).foregroundStyle(Color.xTextSecondary)
            Spacer()
            Text(value)
                .font(.xMono)
                .foregroundStyle(Color.xTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var sendingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(.white)
            Text("Waiting...").foregroundStyle(Color.xTextSecondary)
        }
    }

    private func resultView(hash: String, isSuccess: Bool) -> some View {
        VStack(spacing: 20) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 64))
                .foregroundStyle(isSuccess ? .green : .yellow)

            Text(isSuccess ? "Confirmed" : "Pending")
                .font(.xTitle2.bold()).foregroundStyle(Color.xTextPrimary)

            Text(hash)
                .font(.xMonoSm)
                .foregroundStyle(Color.xTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !isSuccess {
                ProgressView().tint(.white)
                Text("Confirming...").font(.xCaption).foregroundStyle(Color.xTextSecondary)
            }
        }
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.red)
            Text("Transaction failed").font(.xTitle2.bold()).foregroundStyle(Color.xTextPrimary)
            Text(message).font(.subheadline).foregroundStyle(Color.xTextSecondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button { store.send(.dismissError) } label: {
                Text("Retry").font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        }
    }
}
