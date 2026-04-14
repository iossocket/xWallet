//
//  PrivacyOverlayView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/4/26.
//

import SwiftUI
import ComposableArchitecture

struct PrivacyOverlayView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: XSpacing.xxl) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.xAccent, Color.xAccentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "faceid")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }

                if store.needsAuth {
                    Button {
                        store.send(.authenticate)
                    } label: {
                        Text("Unlock")
                            .font(.xBodyMedium)
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding(.vertical, XSpacing.md)
                    }
                    .background(Color.xAccent)
                    .clipShape(RoundedRectangle(cornerRadius: XRadius.md))
                    .xAccentGlow()
                    .transition(.opacity)
                }
            }
        }
    }
}

