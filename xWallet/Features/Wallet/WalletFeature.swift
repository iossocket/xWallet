//
//  WalletFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation
import SwiftUI

struct WalletState: Equatable {
    var address: String = ""
    var ethBalance: Decimal? = nil
    var assets: [AssetItem] = []
    var totalBalance: String = "1,161,2.0"
    var showBalance: Bool = true
    
    var isReceiveSheetPresented: Bool = false
    
    var isLoading: Bool = false
    var errorMessage: String? = nil
}

enum WalletError: Error, Equatable {
    case message(String)
    
    var message: String {
        switch self {
        case .message(let msg):
            return msg
        }
    }
}

enum WalletAction: Equatable {
    case onAppear
    case refreshTapped
    case toggleShowBalance
    case receiveTapped
    case receiveSheetDismissed
    case balanceResponse(Result<Decimal, WalletError>)
}

struct WalletReducer: Reducer {
    typealias State = WalletState
    typealias Action = WalletAction
    
    @MainActor
    func reduce(into state: inout WalletState, action: WalletAction, send: @escaping (Action) -> Void) -> Task<Void, Never>? {
        switch action {
        case .onAppear, .refreshTapped:
            state.isLoading = true
            state.errorMessage = nil
            state.assets = AssetItem.preset
            
            let address = state.address
            let ethereum = Dependencies.current.ethereum
            return Task { @MainActor in
                do {
                    let eth = try await ethereum.rpc.getBalanceETH(address: address)
                    send(.balanceResponse(.success(eth)))
                } catch {
                    send(.balanceResponse(.failure(.message(error.localizedDescription))))
                }
            }
        case .toggleShowBalance:
            state.showBalance.toggle()
            return nil
        case .receiveSheetDismissed:
            state.isReceiveSheetPresented = false
            return nil
        case .receiveTapped:
            state.isReceiveSheetPresented = true
            return nil
        case .balanceResponse(let result):
            state.isLoading = false
            switch result {
            case .success(let ethBalance):
                state.ethBalance = ethBalance
            case .failure(let error):
                state.errorMessage = "\(error.localizedDescription)"
            }
            return nil
        }
    }
}
