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
                    chainManagementSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "050505"))
        .preferredColorScheme(.dark)
        .onShake {
            print("shaked")
        }
        .sheet(item: $store.scope(state: \.chainManagement, action: \.chainManagement)) { chainStore in
            NavigationStack {
                ChainManagementView(store: chainStore)
            }
        }
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
