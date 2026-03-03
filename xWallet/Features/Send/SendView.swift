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
            Color(hex: "121212").ignoresSafeArea()
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
                    Text("Asset").font(.caption).foregroundStyle(.white.opacity(0.6))
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
                                Text(selected.symbol).font(.body.bold())
                                Spacer()
                                Text(selected.balance).font(.caption).foregroundStyle(.white.opacity(0.6))
                            } else {
                                Text("Select asset").foregroundStyle(.white.opacity(0.6))
                                Spacer()
                            }
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("To address").font(.caption).foregroundStyle(.white.opacity(0.6))
                TextField("0x...", text: $store.toAddress)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.none)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Amount").font(.caption).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    if let selected = store.selectedAsset {
                        Text("Balance: \(selected.balance)").font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                }
                TextField("0.0", text: $store.amount)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Spacer()

            Button {
                store.send(.estimateGasTapped)
            } label: {
                Group {
                    if store.phase == .estimating {
                        ProgressView().tint(.black)
                    } else {
                        Text("Estimate Gas Fee")
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
            Text("Confirm transaction").font(.title2.bold()).foregroundStyle(.white)

            VStack(spacing: 12) {
                feeRow("To Address", store.toAddress)
                feeRow("Amount", "\(store.amount) \(store.selectedAsset?.symbol ?? store.chain.symbol)")
                feeRow("Gas Limit", store.gasEstimate)
                feeRow("Max Fee", store.maxFeePerGas)
                feeRow("Priority Fee", store.maxPriorityFeePerGas)
            }
            .padding()
            .background(.white.opacity(0.06))
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
                Text("Cancel").foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
    }

    private func feeRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var sendingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(.white)
            Text("Waiting...").foregroundStyle(.white.opacity(0.8))
        }
    }

    private func resultView(hash: String, isSuccess: Bool) -> some View {
        VStack(spacing: 20) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 64))
                .foregroundStyle(isSuccess ? .green : .yellow)

            Text(isSuccess ? "Confirmed" : "Pending")
                .font(.title2.bold()).foregroundStyle(.white)

            Text(hash)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !isSuccess {
                ProgressView().tint(.white)
                Text("Confirming...").font(.caption).foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.red)
            Text("Transaction failed").font(.title2.bold()).foregroundStyle(.white)
            Text(message).font(.subheadline).foregroundStyle(.white.opacity(0.6))
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
