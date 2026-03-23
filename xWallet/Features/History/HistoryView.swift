//
//  HistoryView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/3/26.
//

import ComposableArchitecture
import SwiftUI

struct HistoryView: View {
    @Bindable var store: StoreOf<History>
    @State private var selectedTransaction: HistoryTransaction?

    private var isInitialLoading: Bool {
        store.isLoading && store.transactions.isEmpty
    }

    var body: some View {
        ZStack {
            if isInitialLoading {
                ProgressView()
                    .tint(Color.xTextTertiary)
                    .scaleEffect(1.2)
            } else {
                ScrollView {
                    LazyVStack(spacing: XSpacing.sm) {
                        ForEach(store.transactions) { tx in
                            Button {
                                selectedTransaction = tx
                            } label: {
                                txRow(tx)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if shouldLoadMore(currentId: tx.id) {
                                    store.send(.loadMore)
                                }
                            }
                        }

                        if store.isLoading && !store.transactions.isEmpty {
                            ProgressView()
                                .tint(Color.xTextTertiary)
                                .padding()
                        }

                        if let error = store.errorMessage {
                            Text(error)
                                .font(Font.xCaption)
                                .foregroundStyle(Color.xRed)
                                .padding()
                        }

                        if !store.isLoading && store.transactions.isEmpty && store.errorMessage == nil {
                            Text("No transactions yet")
                                .font(Font.xBody)
                                .foregroundStyle(Color.xTextTertiary)
                                .padding(.vertical, XSpacing.xxl)
                        }
                    }
                    .padding(.horizontal, XSpacing.md)
                }
                .refreshable { await store.send(.refresh).finish() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.xBg0)
        .navigationDestination(item: $selectedTransaction) { tx in
            HistoryDetailView(tx: tx, chain: store.chain)
        }
        .onAppear { store.send(.onAppear) }
        .toolbar(.hidden, for: .tabBar)
    }

    private func shouldLoadMore(currentId: String) -> Bool {
        let txs = store.transactions
        guard txs.count >= 3 else { return currentId == txs.last?.id }
        return currentId == txs[txs.count - 3].id
    }

    private func txRow(_ tx: HistoryTransaction) -> some View {
        HStack(spacing: XSpacing.md) {
            Image(systemName: tx.isOutgoing ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tx.isOutgoing ? Color.xAccent : Color.xGreen)
                .frame(width: 32, height: 32)
                .background(
                    (tx.isOutgoing ? Color.xAccent : Color.xGreen).opacity(0.12)
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.isOutgoing ? "Sent" : "Received")
                    .font(Font.xBody)
                    .foregroundStyle(Color.xTextPrimary)

                let counterparty = tx.isOutgoing
                    ? (tx.toEns ?? shortAddress(tx.to))
                    : (tx.fromEns ?? shortAddress(tx.from))
                let hasEns = tx.isOutgoing ? tx.toEns != nil : tx.fromEns != nil

                Text(counterparty)
                    .font(hasEns ? Font.xCaption : Font.xMonoSm)
                    .foregroundStyle(Color.xTextTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tx.isOutgoing ? "-" : "+")\(tx.value)")
                    .font(Font.xMono)
                    .foregroundStyle(tx.isOutgoing ? Color.xTextPrimary : Color.xGreen)
                Text(tx.timestamp, style: .relative)
                    .font(Font.xCaption)
                    .foregroundStyle(Color.xTextTertiary)
            }
        }
        .padding(XSpacing.md)
        .xCard()
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
}
