//
//  SettingsView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/1/26.
//

import SwiftUI

struct SettingsView: View {
    let state: SettingsState
    let send: (SettingsAction) -> Void

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    rpcSection

                    presetsSection

                    saveSection

                    if let hint = hintText {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "050505"))
        .preferredColorScheme(.dark)
        .onAppear {
            send(.onAppear)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Configure RPC endpoint for Ethereum JSON-RPC.")
                .font(.subheadline)
                .noteStyle()
        }
        .padding(.top, 8)
    }

    private var rpcSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RPC URL")
                .font(.headline)
                .foregroundStyle(.white)

            TextField(
                "https://rpc.sepolia.org",
                text: Binding(
                    get: { state.rpcURL },
                    set: { send(.rpcURLChanged($0)) }
                )
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.URL)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(state.isValid ? Color.white.opacity(0.10) : Color.red.opacity(0.7), lineWidth: 1)
            )

            HStack(spacing: 8) {
                Image(systemName: state.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(state.isValid ? .green : .red)

                Text(state.isValid ? "Looks good" : "Please enter a valid http(s) URL")
                    .font(.footnote)
                    .foregroundStyle(state.isValid ? .gray : .red)
            }
            
            Button {
                send(.checkTapped)
            } label: {
                HStack {
                    Spacer()
                    Text("Check Connection")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .disabled(!state.isValid || state.isChecking)
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            statusRow
        }
        .cardStyle()
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if state.isChecking {
                ProgressView().scaleEffect(0.9)
                Text("Checking...")
                    .font(.footnote)
                    .foregroundStyle(.gray)
            } else {
                switch state.connectionStatus {
                case .idle:
                    Text("Not verified")
                        .font(.footnote)
                        .foregroundStyle(.gray)
                case .connected:
                    let name = chainName(state.chainId)
                    Text("Connected • \(name)")
                        .font(.footnote)
                        .foregroundStyle(.green)
                case .failed(let msg):
                    Text("Failed • \(msg)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                presetButton(title: "Sepolia (public)", url: "https://rpc.sepolia.org")
                presetButton(title: "Ethereum Mainnet (example)", url: "https://cloudflare-eth.com")
            }
        }
        .cardStyle()
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                send(.saveTapped(state.rpcURL))
            } label: {
                HStack {
                    Spacer()
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .disabled(!(state.isValid && state.connectionStatus == .connected))
            .foregroundStyle(.white)
            .background(state.isValid ? Color.blue : Color.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("Saved value is stored locally (UserDefaults).")
                .font(.footnote)
                .foregroundStyle(.gray)
        }
        .cardStyle()
    }

    private func presetButton(title: String, url: String) -> some View {
        Button {
            send(.rpcURLChanged(url))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                    Text(url)
                        .foregroundStyle(.gray)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var hintText: String? {
        // 你也可以展示当前网络/chainId（S3.3 我们会加）
        nil
    }
    
    private func chainName(_ id: Int?) -> String {
        switch id {
        case 1: return "Ethereum Mainnet (1)"
        case 11155111: return "Sepolia (11155111)"
        default: return id.map { "Chain \($0)" } ?? "Unknown"
        }
    }

}

// MARK: - Small styling helpers

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

private extension Text {
    func noteStyle() -> some View {
        self
            .foregroundStyle(.gray)
    }
}

