//
//  WalletFeature.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/1/26.
//

import Foundation
import SwiftUI

struct WalletState: Equatable {
    var assets: [AssetItem] = []
    var totalBalance: String = "1,161,2.0"
    var showBalance: Bool = true
    
    var isReceiveSheetPresented: Bool = false
    
    var isLoading: Bool = false
    var errorMessage: String? = nil
}

enum WalletAction: Equatable {
    case onAppear
    case refreshTapped
    case toggleShowBalance
    case receiveTapped
    case receiveSheetDismissed
}

struct WalletReducer: Reducer {
    typealias State = WalletState
    typealias Action = WalletAction
    
    @MainActor
    func reduce(into state: inout WalletState, action: WalletAction) -> Task<Void, Never>? {
        switch action {
        case .onAppear, .refreshTapped:
            state.isLoading = false
            state.errorMessage = nil
            state.assets = AssetItem.preset
            return nil
        case .toggleShowBalance:
            state.showBalance.toggle()
            return nil
        case .receiveSheetDismissed:
            state.isReceiveSheetPresented = false
            return nil
        case .receiveTapped:
            state.isReceiveSheetPresented = true
            return nil
        }
    }
}
