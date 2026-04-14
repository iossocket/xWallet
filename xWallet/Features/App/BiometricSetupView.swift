//
//  BiometricSetupView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/4/26.
//

import SwiftUI
import ComposableArchitecture

struct BiometricSetupView: View {
    let store: StoreOf<AppFeature>

    private var isNoPasscode: Bool {
        store.biometricStatus == .unavailable(.noPasscode)
    }

    private var biometricLabel: String {
        switch store.biometricStatus {
        case .available(.faceID): return "Face ID"
        case .available(.touchID): return "Touch ID"
        case .available(.opticID): return "Optic ID"
        default: return "Passcode"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.xBg0, Color.xBg1, Color.xBg0],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: XSpacing.xxxl) {
                Spacer()

                VStack(spacing: XSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.xAccentGlow)
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.xAccent, Color.xAccentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)

                        Image(systemName: isNoPasscode ? "lock.slash" : "faceid")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }

                    Text(isNoPasscode ? "Device Passcode Required" : "Secure Your Wallet")
                        .font(.xTitle1)
                        .foregroundColor(.xTextPrimary)

                    Text(isNoPasscode
                         ? "xWallet requires a device passcode to protect your assets. Please set one in Settings > Face ID & Passcode."
                         : "xWallet uses \(biometricLabel) to keep your wallet safe. Verify your identity to continue.")
                        .font(.xBody)
                        .foregroundColor(.xTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, XSpacing.xxxl)
                }

                Spacer()

                if !isNoPasscode {
                    Button {
                        store.send(.authenticate)
                    } label: {
                        Text("Verify with \(biometricLabel)")
                            .font(.xBodyMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, XSpacing.md)
                    }
                    .background(Color.xAccent)
                    .clipShape(RoundedRectangle(cornerRadius: XRadius.md))
                    .xAccentGlow()
                    .padding(.horizontal, XSpacing.xxl)
                }

                Spacer()
                    .frame(height: XSpacing.xxxl)
            }
        }
        .preferredColorScheme(.dark)
    }
}
