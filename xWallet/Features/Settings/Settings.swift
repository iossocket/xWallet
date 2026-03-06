//
//  Settings.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/2/26.
//

import ComposableArchitecture
import EthereumKit
import Foundation

@Reducer
struct Settings {
    @ObservableState
    struct State: Equatable {
        @Presents var chainManagement: ChainManagement.State?
    }

    enum Action {
        case chainManagement(PresentationAction<ChainManagement.Action>)
        case manageChainsTapped
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .manageChainsTapped:
                state.chainManagement = ChainManagement.State()
                return .none
            case .chainManagement:
                return .none
            }
        }
        .ifLet(\.$chainManagement, action: \.chainManagement) {
            ChainManagement()
        }
    }
}
