//
//  ImportAccountView.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/1/26.
//

import SwiftUI

struct ImportAccountView: View {
    @ObservedObject var store: ScopedStore<AppReducer, AccountState, AccountAction>
    @State private var privateKeyHex: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Account")
                .font(.title2).fontWeight(.bold)

            Text("Paste a 64-char hex private key (no spaces).")
                .font(.footnote)
                .foregroundStyle(.gray)

            TextField("0x…", text: $privateKeyHex, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.footnote, design: .monospaced))
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                let input = privateKeyHex
                store.send(.importPrivateKeyTapped(input))
            } label: {
                HStack { Spacer(); Text("Import"); Spacer() }
                    .padding(.vertical, 12)
            }
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = store.state.errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let address = store.state.address, store.state.isUnlocked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
                        .font(.footnote).foregroundStyle(.gray)
                    Text(address)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.state.address) { _, newValue in
            if newValue != nil { privateKeyHex = "" }
        }
    }
}

