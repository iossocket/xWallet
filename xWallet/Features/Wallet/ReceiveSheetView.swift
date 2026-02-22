//
//  Receive.swift
//  xWallet
//
//  Created by Xueliang Zhu on 30/11/25.
//

import SwiftUI
import ComposableArchitecture

@Reducer 
struct Receive {
    @ObservableState
    struct State: Equatable {
        var address: String
        var showCopiedToast = false
    }
    
    enum Action {
        case copyAddress
        case shareAddress
        case copiedToastDismissed
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .copyAddress:
                UIPasteboard.general.string = state.address
                return .none
            case .shareAddress:
                return .none
            case .copiedToastDismissed:
                return .none
            }
        }
    }
}

struct ReceiveView: View {
    var store: StoreOf<Receive>
    
    var body: some View {
        ZStack {
            Color(hex: "121212").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Handle
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                
                Text("Receive ETH")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                // QR Code Area
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .frame(width: 240, height: 240)
                        .shadow(color: .white.opacity(0.1), radius: 20)
                    
                    Image(systemName: "qrcode")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .foregroundStyle(.black)
                }
                .padding(.vertical, 10)
                
                // Address Box
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WALLET ADDRESS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                        
                        Text(store.address)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        store.send(.copyAddress)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(Color(hex: "1c1c1e"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Button(action: {
                    store.send(.shareAddress)
                }) {
                    Text("Share Address")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
        }
    }
}
