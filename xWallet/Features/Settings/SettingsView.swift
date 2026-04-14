//
//  SettingsView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/1/26.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    securitySection
                    accountSection
                    walletListSection
                    chainManagementSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "050505"))
        .preferredColorScheme(.dark)
        .sheet(item: $store.scope(state: \.chainManagement, action: \.chainManagement)) { chainStore in
            NavigationStack {
                ChainManagementView(store: chainStore)
            }
        }
        .sheet(item: $store.scope(state: \.importAccount, action: \.importAccount)) { accountStore in
            NavigationStack {
                ImportAccountView(store: accountStore)
            }
        }
        .sheet(item: $store.scope(state: \.walletList, action: \.walletList)) { walletListStore in
            NavigationStack {
                WalletListView(store: walletListStore)
            }
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Security")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: XSpacing.sm) {
                Text("Auto-Lock")
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .semibold))
                Text("Require authentication after being in background")
                    .foregroundStyle(.gray)
                    .font(.system(size: 12))

                HStack(spacing: XSpacing.sm) {
                    ForEach(LockTimeout.allCases, id: \.rawValue) { timeout in
                        let isSelected = store.lockTimeout == timeout.rawValue
                        Button {
                            store.send(.lockTimeoutChanged(timeout.rawValue))
                        } label: {
                            Text(timeout.displayName)
                                .font(.xCaptionBold)
                                .foregroundColor(isSelected ? .white : .xTextSecondary)
                                .padding(.horizontal, XSpacing.md)
                                .padding(.vertical, XSpacing.sm)
                                .background(isSelected ? Color.xAccent : Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: XRadius.sm))
                        }
                    }
                    Spacer()
                }
                .padding(.top, XSpacing.xs)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .cardStyle()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.headline)
                .foregroundStyle(.white)

            Button {
                store.send(.importAccountTapped)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Account")
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Import via recovery phrase or private key")
                            .foregroundStyle(.gray)
                            .font(.system(size: 12))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .cardStyle()
    }

    private var walletListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wallets")
                .font(.headline)
                .foregroundStyle(.white)

            Button {
                store.send(.walletListTapped)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("View All Wallets")
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Browse all wallet identities in database")
                            .foregroundStyle(.gray)
                            .font(.system(size: 12))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .cardStyle()
    }

    private var chainManagementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chain Management")
                .font(.headline)
                .foregroundStyle(.white)

            Button {
                store.send(.manageChainsTapped)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Chains")
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Select and configure EVM chains")
                            .foregroundStyle(.gray)
                            .font(.system(size: 12))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.gray)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .cardStyle()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
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
