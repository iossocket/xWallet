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

    var body: some View {
        ZStack {
            Color.xBg0.ignoresSafeArea()
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

                Spacer()

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
                    .background(Color.xAccent)
                    .clipShape(RoundedRectangle(cornerRadius: XRadius.lg))
                }
                .disabled(store.isLoading || store.privateKeyInput.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, XSpacing.xxxl)
            }
            .padding(.top, 40)
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
