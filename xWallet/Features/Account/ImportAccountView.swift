//
//  ImportAccountView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/1/26.
//

import SwiftUI
import ComposableArchitecture

struct ImportAccountView: View {
    @Bindable var store: StoreOf<Account>

    var body: some View {
        Group {
            switch store.onboardingStep {
            case .landing:
                landingView
            case .selectChain:
                chainSelectionView
            case .showMnemonic:
                MnemonicDisplayView(store: store)
            case .verifyMnemonic:
                MnemonicDisplayView(store: store)
            case .importMnemonic:
                ImportMnemonicView(store: store)
            case .importPrivateKey:
                ImportPrivateKeyView(store: store)
            }
        }
        .sheet(item: $store.scope(state: \.accountDeploy, action: \.accountDeploy)) { accountDeployStore in
            NavigationStack {
                AccountDeployView(store: accountDeployStore)
            }
        }
    }

    // MARK: - Landing

    private var landingView: some View {
        ZStack {
            Color.xBg0.ignoresSafeArea()
            VStack(spacing: XSpacing.xl) {
                Spacer()
                Text("xWallet")
                    .font(.xDisplay)
                    .foregroundStyle(Color.xTextPrimary)
                Text("Secure & Private Multi-Chain Wallet")
                    .font(.xBody)
                    .foregroundStyle(Color.xTextSecondary)
                Spacer()

                Button {
                    store.send(.createWalletTapped)
                } label: {
                    Text("Create new wallet")
                        .font(Font.xTitle2)
                        .foregroundStyle(Color.xBg0)
                        .opacity(store.isLoading ? 0 : 1)
                        .overlay {
                            if store.isLoading {
                                ProgressView().tint(Color.xBg0)
                            }
                        }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.xAccent)
                    .clipShape(RoundedRectangle(cornerRadius: XRadius.lg))
                }
                .disabled(store.isLoading)
                .padding(.horizontal)

                Button {
                    store.send(.showImportMnemonicTapped)
                } label: {
                    Text("Import Recovery Phrase")
                        .font(.xTitle2)
                        .foregroundStyle(Color.xTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.xBg2)
                        .clipShape(RoundedRectangle(cornerRadius: XRadius.lg))
                }
                .padding(.horizontal)

                Button {
                    store.send(.showImportPrivateKeyTapped)
                } label: {
                    Text("Import Private Key")
                        .font(.xTitle2)
                        .foregroundStyle(Color.xTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.xBg2)
                        .clipShape(RoundedRectangle(cornerRadius: XRadius.lg))
                }
                .padding(.horizontal)
                .padding(.bottom, XSpacing.xxxl + XSpacing.lg)
            }
        }
    }

    // MARK: - Chain Selection

    private var chainSelectionView: some View {
        ZStack {
            Color.xBg0.ignoresSafeArea()
            VStack(spacing: XSpacing.xxl) {
                Text("Select Network")
                    .font(.xTitle1)
                    .foregroundStyle(Color.xTextPrimary)

                Text("Choose the blockchain network you want to use")
                    .font(.xBody)
                    .foregroundStyle(Color.xTextSecondary)

                VStack(spacing: XSpacing.md) {
                    chainButton(.evm, name: "EVM", description: "Ethereum, BSC, Polygon, Arbitrum...")
                    chainButton(.starknet, name: "Starknet", description: "Starknet L2")
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
        }
    }

    private func chainButton(_ chain: ChainType, name: String, description: String) -> some View {
        Button {
            store.send(.chainSelected(chain))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: XSpacing.xs) {
                    Text(name).font(.xTitle2).foregroundStyle(Color.xTextPrimary)
                    Text(description).font(.xCaption).foregroundStyle(Color.xTextTertiary)
                }
                Spacer()
                if store.selectedChain == chain {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.xGreen)
                }
            }
            .padding()
            .background(store.selectedChain == chain ? Color.xBg3 : Color.xBg2)
            .clipShape(RoundedRectangle(cornerRadius: XRadius.md))
        }
    }
}

#Preview {
    ImportAccountView(
        store: Store(initialState: Account.State()) {
            Account()
        }
    )
}
