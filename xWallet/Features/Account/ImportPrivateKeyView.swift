//
//  ImportPrivateKeyView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 25/2/26.
//

import SwiftUI
import ComposableArchitecture

struct ImportPrivateKeyView: View {
    @Bindable var store: StoreOf<Account>
    
    var importButtonDisabled: Bool {
        if store.selectedChain == .evm {
            return store.isLoading || store.privateKeyInput.isEmpty
        } else {
            if store.selectedStarknetAccountType == nil || store.selectedStarknetChainId == nil {
                return true
            }
            return store.isLoading || store.privateKeyInput.isEmpty
        }
    }

    var body: some View {
        ZStack {
            Color.xBg0.ignoresSafeArea()
            ScrollView {
                VStack(spacing: XSpacing.xxl) {
                    Text("Import Private Key")
                        .font(.xTitle1)
                        .foregroundStyle(Color.xTextPrimary)

                    Text("Enter a private key in hexadecimal format")
                        .font(.xBody)
                        .foregroundStyle(Color.xTextSecondary)
                    
                    TextEditor(text: $store.privateKeyInput.sending(\.privateKeyInputChanged))
                        .font(.xMono)
                        .foregroundStyle(Color.xTextPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(XSpacing.sm)
                        .background(Color.xBg2)
                        .clipShape(RoundedRectangle(cornerRadius: XRadius.md))
                        .frame(height: 120)
                        .padding(.horizontal)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if let error = store.errorMessage {
                        Text(error)
                            .font(.xCaption)
                            .foregroundStyle(Color.xRed)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: XSpacing.xxl) {
                        VStack {
                            Image("evm")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                            Text("EVM")
                                .font(.xBody)
                                .foregroundStyle(store.selectedChain == .evm ? Color.xAccent : Color.xTextSecondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(store.selectedChain == .evm ? Color.xAccent : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.chainSelected(.evm))
                        }
                        
                        VStack {
                            Image("starknet")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                            Text("Starknet")
                                .font(.xBody)
                                .foregroundStyle(store.selectedChain == .starknet ? Color.xAccent : Color.xTextSecondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(store.selectedChain == .starknet ? Color.xAccent : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.chainSelected(.starknet))
                        }
                    }
                    
                    if store.selectedChain == .starknet {
                        VStack(spacing: XSpacing.xxl) {
                            HStack(spacing: XSpacing.xxl) {
                                VStack {
                                    Image("oz")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 64, height: 64)
                                    Text("OZ")
                                        .font(.xBody)
                                        .foregroundStyle(store.selectedStarknetAccountType == .oz ? Color.xAccent : Color.xTextSecondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(store.selectedStarknetAccountType == .oz ? Color.xAccent : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.starknetAccountTypeSelected(.oz))
                                }
                                
                                VStack {
                                    Image("argent")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 64, height: 64)
                                    Text("Argent")
                                        .font(.xBody)
                                        .foregroundStyle(store.selectedStarknetAccountType == .argent ? Color.xAccent : Color.xTextSecondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(store.selectedStarknetAccountType == .argent ? Color.xAccent : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.starknetAccountTypeSelected(.argent))
                                }
                            }
                            HStack(spacing: XSpacing.xxl) {
                                Text("mainnet")
                                    .font(.xBody)
                                    .frame(width: 64)
                                    .foregroundStyle(store.selectedStarknetChainId == .mainnet ? Color.xAccent : Color.xTextSecondary)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(store.selectedStarknetChainId == .mainnet ? Color.xAccent : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        store.send(.starknetChainIdSelected(.mainnet))
                                    }
                                
                                Text("sepolia")
                                    .font(.xBody)
                                    .frame(width: 64)
                                    .foregroundStyle(store.selectedStarknetChainId == .sepolia ? Color.xAccent : Color.xTextSecondary)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(store.selectedStarknetChainId == .sepolia ? Color.xAccent : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        store.send(.starknetChainIdSelected(.sepolia))
                                    }
                            }
                        }.transition(.opacity)
                    }
                    
                    
                    Spacer(minLength: XSpacing.xxl)
                    
                    Button {
                        store.send(.importPrivateKeyTapped)
                    } label: {
                        Text("Import Wallet")
                            .font(.xTitle2)
                            .foregroundStyle(Color.xBg0)
                            .opacity(store.isLoading ? 0 : 1)
                            .overlay {
                                if store.isLoading {
                                    ProgressView().tint(Color.xBg0)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(importButtonDisabled ? Color.xAccent.opacity(0.3) : Color.xAccent)
                            .clipShape(RoundedRectangle(cornerRadius: XRadius.lg))
                    }
                    .disabled(importButtonDisabled)
                    .padding(.horizontal)
                    
                    Button {
                        store.send(.backButtonTapped)
                    } label: {
                        Text("Back")
                            .font(.xTitle2)
                            .foregroundStyle(Color.xTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.xBg2)
                            .clipShape(RoundedRectangle(cornerRadius: XRadius.lg))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, XSpacing.xxxl)
                }
                .padding(.top, 40)
                .frame(minHeight: UIScreen.main.bounds.height - 100)
                .animation(.easeInOut, value: store.selectedChain)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    ImportPrivateKeyView(
        store: Store(
            initialState: Account.State(
                onboardingStep: .importPrivateKey,
                selectedChain: .evm
            )
        ) {
            Account()
        }
    )
}
