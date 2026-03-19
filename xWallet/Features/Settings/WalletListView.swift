//
//  WalletListView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 19/3/26.
//

import SwiftUI
import ComposableArchitecture

struct WalletListView: View {
    let store: StoreOf<WalletList>

    var body: some View {
        List {
            if store.wallets.isEmpty && !store.isLoading {
                Text("No wallets found")
                    .font(.xBody)
                    .foregroundStyle(Color.xTextSecondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(store.wallets) { wallet in
                let isActive = wallet.id == store.activeWalletId
                VStack(alignment: .leading, spacing: XSpacing.xs) {
                    HStack {
                        Text(wallet.name)
                            .font(.xTitle3)
                            .foregroundStyle(Color.xTextPrimary)
                        if isActive {
                            Text("Active")
                                .font(.xCaption)
                                .foregroundStyle(Color.xBg0)
                                .padding(.horizontal, XSpacing.sm)
                                .padding(.vertical, 2)
                                .background(Color.xAccent)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text(wallet.chainType.rawValue.uppercased())
                            .font(.xCaption)
                            .foregroundStyle(Color.xAccent)
                            .padding(.horizontal, XSpacing.sm)
                            .padding(.vertical, 4)
                            .background(Color.xAccent.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if let address = wallet.primaryAddress {
                        Text(address)
                            .font(.xMonoSm)
                            .foregroundStyle(Color.xTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: XSpacing.md) {
                        Label(wallet.sourceType.rawValue, systemImage: wallet.sourceType == .mnemonic ? "key.fill" : "lock.fill")
                            .font(.xCaption)
                            .foregroundStyle(Color.xTextSecondary)

                        if let chainId = wallet.chainId {
                            Text(chainId)
                                .font(.xCaption)
                                .foregroundStyle(Color.xTextSecondary)
                        }

                        Spacer()

                        Text(wallet.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.xCaption)
                            .foregroundStyle(Color.xTextSecondary)
                    }
                }
                .padding(.vertical, XSpacing.xs)
                .listRowBackground(Color.xBg1)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.xBg0)
        .navigationTitle("Wallets")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}
