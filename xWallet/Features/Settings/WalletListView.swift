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
    
    var evmWallets: [WalletIdentity] {
        store.wallets.filter { $0.chainType == .evm }
    }
    var starknetWallets: [WalletIdentity] {
        store.wallets.filter { $0.chainType == .starknet }
    }

    var body: some View {
        List {
            chainSection(title: "EVM", wallets: evmWallets)
            chainSection(title: "Starknet", wallets: starknetWallets)
        }
        .scrollContentBackground(.hidden)
        .background(Color.xBg0)
        .navigationTitle("Wallets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addAccountTapped)
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.xAccent)
                }
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private func chainSection(title: String, wallets: [WalletIdentity]) -> some View {
        Section {
            if wallets.isEmpty {
                emptyPlaceholder(chain: title)
            } else {
                ForEach(wallets) { wallet in
                    walletRow(wallet: wallet)
                }
            }
        } header: {
            Text(title)
                .font(.xCaption)
                .foregroundStyle(Color.xTextSecondary)
        }
    }

    private func emptyPlaceholder(chain: String) -> some View {
        VStack(spacing: XSpacing.md) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 36))
                .foregroundStyle(Color.xTextSecondary.opacity(0.4))
            Text("No \(chain) wallets yet")
                .font(.xBody)
                .foregroundStyle(Color.xTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, XSpacing.xxl)
        .listRowBackground(Color.clear)
    }

    private func walletRow(wallet: WalletIdentity) -> some View {
        let isActive = wallet.id == store.activeWalletId
        return HStack(spacing: XSpacing.md) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.xAccent : Color.xTextSecondary)
                .font(.xTitle2)

            VStack(alignment: .leading, spacing: XSpacing.xs) {
                Text(wallet.name)
                    .font(.xTitle3)
                    .foregroundStyle(Color.xTextPrimary)

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
        }
        .padding(.vertical, XSpacing.xs)
        .listRowBackground(isActive ? Color.xAccent.opacity(0.08) : Color.xBg1)
        .contentShape(Rectangle())
        .onTapGesture {
            store.send(.walletTapped(wallet.id))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isActive {
                Button(role: .destructive) {
                    store.send(.deleteWalletSwiped(wallet.id))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
