//
//  ImportMnemonicView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 25/2/26.
//

import SwiftUI
import ComposableArchitecture

struct ImportMnemonicView: View {
    @Bindable var store: StoreOf<Account>

    var body: some View {
        ZStack {
            Color(hex: "121212").ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Import Recovery Phrase")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Enter 12 or 24 words, separated by spaces")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                TextEditor(text: $store.mnemonicInput.sending(\.mnemonicInputChanged))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(height: 120)
                    .padding(.horizontal)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    store.send(.importMnemonicTapped)
                } label: {
                    Text("Import Wallet")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .opacity(store.isLoading ? 0 : 1)
                        .overlay {
                            if store.isLoading {
                                ProgressView().tint(.black)
                            }
                        }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(store.isLoading || store.mnemonicInput.isEmpty)
                .padding(.horizontal)
                Spacer()
                
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
        }
    }
}

#Preview {
    ImportMnemonicView(
        store: Store(
            initialState: Account.State(
                onboardingStep: .importMnemonic,
                selectedChain: .evm
            )
        ) {
            Account()
        }
    )
}
