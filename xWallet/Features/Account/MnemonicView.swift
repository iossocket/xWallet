//
//  MnemonicView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 25/2/26.
//

import SwiftUI
import ComposableArchitecture

struct MnemonicDisplayView: View {
    let store: StoreOf<Account>

    private var words: [String] {
        store.generatedMnemonic.split(separator: " ").map(String.init)
    }

    var body: some View {
        ZStack {
            Color(hex: "121212").ignoresSafeArea()
            VStack(spacing: 24) {
                Text("backup mnemonic")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Please carefully write down the following 12 words in the correct order on paper. Do not take a screenshot or store them online.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        HStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                                .frame(width: 20)
                            Text(word)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    store.send(.mnemonicBackupConfirmed)
                } label: {
                    Text("Confirm")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top, 40)
        }
    }
}
