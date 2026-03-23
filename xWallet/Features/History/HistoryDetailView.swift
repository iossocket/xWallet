//
//  HistoryDetailView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/3/26.
//

import SwiftUI

struct HistoryDetailView: View {
    let tx: HistoryTransaction
    let chain: Chain

    @Environment(\.openURL) private var openURL
    @State private var copiedField: String?

    var body: some View {
        ScrollView {
            VStack(spacing: XSpacing.xl) {
                heroSection
                addressSection
                hashSection
                infoSection
                explorerButton
            }
            .padding(.horizontal, XSpacing.lg)
            .padding(.vertical, XSpacing.xl)
        }
        .background(Color.xBg0)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: XSpacing.md) {
            Image(systemName: tx.isOutgoing ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(tx.isOutgoing ? Color.xAccent : Color.xGreen)

            Text("\(tx.isOutgoing ? "-" : "+")\(tx.value)")
                .font(Font.xDisplaySm)
                .foregroundStyle(Color.xTextPrimary)

            statusBadge
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, XSpacing.xl)
    }

    private var statusBadge: some View {
        HStack(spacing: XSpacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(Font.xCaptionBold)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, XSpacing.md)
        .padding(.vertical, XSpacing.xs)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch tx.status {
        case .success: return Color.xGreen
        case .failed: return Color.xRed
        case .pending: return Color.xYellow
        }
    }

    private var statusText: String {
        switch tx.status {
        case .success: return "Success"
        case .failed: return "Failed"
        case .pending: return "Pending"
        }
    }

    // MARK: - Addresses

    private var addressSection: some View {
        VStack(spacing: XSpacing.sm) {
            addressRow(label: "From", address: tx.from, ens: tx.fromEns)
            addressRow(label: "To", address: tx.to, ens: tx.toEns)
        }
    }

    private func addressRow(label: String, address: String, ens: String?) -> some View {
        VStack(alignment: .leading, spacing: XSpacing.xs) {
            Text(label)
                .font(Font.xCaption)
                .foregroundStyle(Color.xTextTertiary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let ens {
                        Text(ens)
                            .font(Font.xBody)
                            .foregroundStyle(Color.xTextPrimary)
                    }
                    Text(address)
                        .font(Font.xMonoSm)
                        .foregroundStyle(Color.xTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                copyButton(value: address, field: label)
            }
        }
        .padding(XSpacing.md)
        .xCard()
    }

    // MARK: - Hash

    private var hashSection: some View {
        VStack(alignment: .leading, spacing: XSpacing.xs) {
            Text("Transaction Hash")
                .font(Font.xCaption)
                .foregroundStyle(Color.xTextTertiary)

            HStack {
                Text(tx.hash)
                    .font(Font.xMonoSm)
                    .foregroundStyle(Color.xTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                copyButton(value: tx.hash, field: "Hash")
            }
        }
        .padding(XSpacing.md)
        .xCard()
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(label: "Block", value: "\(tx.blockNumber)")
            Divider().overlay(Color.xBorder)
            infoRow(label: "Time", value: tx.timestamp.formatted(date: .abbreviated, time: .shortened))
            if let method = tx.method {
                Divider().overlay(Color.xBorder)
                infoRow(label: "Method", value: method)
            }
            Divider().overlay(Color.xBorder)
            infoRow(label: "Network", value: chain.name)
        }
        .padding(XSpacing.md)
        .xCard()
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Font.xCaption)
                .foregroundStyle(Color.xTextTertiary)
            Spacer()
            Text(value)
                .font(Font.xCaption)
                .foregroundStyle(Color.xTextPrimary)
        }
        .padding(.vertical, XSpacing.sm)
    }

    // MARK: - Explorer

    private var explorerButton: some View {
        Button {
            guard let domain = blockscoutDomain(forChainId: chain.chainId),
                  let txURL = URL(string: "https://\(domain)/tx/\(tx.hash)") else { return }
            if true {
                openURL(txURL)
            }
        } label: {
            HStack(spacing: XSpacing.sm) {
                Image(systemName: "arrow.up.right.square")
                Text("View on Blockscout")
            }
            .font(Font.xBodyMedium)
            .foregroundStyle(Color.xAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, XSpacing.md)
            .overlay(
                RoundedRectangle(cornerRadius: XRadius.xl)
                    .stroke(Color.xAccent.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Copy

    private func copyButton(value: String, field: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copiedField = field
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == field { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14))
                .foregroundStyle(copiedField == field ? Color.xGreen : Color.xTextTertiary)
                .frame(width: 32, height: 32)
                .background(Color.xBg2)
                .clipShape(Circle())
        }
    }
}
