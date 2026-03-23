//
//  ChainManagementView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 5/3/26.
//

import SwiftUI
import ComposableArchitecture
import EthereumKit

struct ChainManagementView: View {
    @Bindable var store: StoreOf<ChainManagement>

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let error = store.errorMessage {
                        Text("Error: \(error)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                    } else {
                        chainList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "050505"))
        .preferredColorScheme(.dark)
        .navigationTitle("Manage Chains")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $store.scope(state: \.chainDetail, action: \.chainDetail)) { detailStore in
            NavigationStack {
                ChainDetailView(store: detailStore)
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var chainList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Chains")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            ForEach(store.chains, id: \.id) { chain in
                chainRow(chain)
            }
        }
    }

    private func chainRow(_ chain: Chain) -> some View {
        let isEnabled = chain.enabled

        return Button {
            store.send(.chainRowTapped(chain))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(chain.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        if chain.isTestnet {
                            Text("TESTNET")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    Text("Chain ID: \(chain.chainId)")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        store.send(.chainToggled(chain, newValue))
                    }
                ))
                .labelsHidden()
                .tint(Color.xAccent)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isEnabled ? Color.xAccent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ChainDetailView: View {
    @Bindable var store: StoreOf<ChainDetail>

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    chainInfoSection

                    rpcURLSection

                    connectionStatusSection

                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "050505"))
        .preferredColorScheme(.dark)
        .navigationTitle(store.chain.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chainInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chain Information")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Name", value: store.chain.name)
                infoRow(label: "Chain ID", value: "\(store.chain.chainId)")
                infoRow(label: "Symbol", value: store.chain.symbol)
                infoRow(label: "Decimals", value: "\(store.chain.decimals)")
                if let explorerURL = store.chain.explorerURL {
                    infoRow(label: "Explorer", value: explorerURL)
                }
            }
        }
        .cardStyle()
    }

    private var rpcURLSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RPC URL")
                .font(.headline)
                .foregroundStyle(.white)

            TextField(
                "https://...",
                text: $store.customRpcURL
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.URL)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .cardStyle()
    }

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if store.isTestingConnection {
                    ProgressView().scaleEffect(0.9)
                    Text("Testing connection...")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                } else {
                    switch store.connectionStatus {
                    case .idle:
                        Text("Not tested")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    case .connected:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connection successful")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    case .failed(let msg):
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Failed: \(msg)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
        }
        .cardStyle()
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.testConnectionTapped)
            } label: {
                HStack {
                    Spacer()
                    Text("Test Connection")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .disabled(store.isTestingConnection || store.customRpcURL.isEmpty)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                store.send(.saveButtonTapped)
            } label: {
                HStack {
                    Spacer()
                    if store.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .disabled(store.isSaving || store.connectionStatus != .connected)
            .foregroundStyle(.white)
            .background(store.connectionStatus == .connected ? Color.xAccent : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
