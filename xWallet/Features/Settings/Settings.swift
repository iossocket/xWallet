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
        @Presents var importAccount: Account.State?
        @Presents var walletList: WalletList.State?
    }

    enum Action {
        case chainManagement(PresentationAction<ChainManagement.Action>)
        case importAccount(PresentationAction<Account.Action>)
        case walletList(PresentationAction<WalletList.Action>)
        case manageChainsTapped
        case importAccountTapped
        case walletListTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .manageChainsTapped:
                state.chainManagement = ChainManagement.State()
                return .none
            case .importAccountTapped:
                state.importAccount = Account.State()
                return .none
            case .walletListTapped:
                state.walletList = WalletList.State()
                return .none
            case .importAccount(.presented(.createWalletResponse(.success))),
                 .importAccount(.presented(.importMnemonicResponse(.success))),
                 .importAccount(.presented(.importPrivateKeyResponse(.success))):
                state.importAccount = nil
                return .none
            case .chainManagement, .importAccount, .walletList:
                return .none
            }
        }
        .ifLet(\.$chainManagement, action: \.chainManagement) {
            ChainManagement()
        }
        .ifLet(\.$importAccount, action: \.importAccount) {
            Account()
        }
        .ifLet(\.$walletList, action: \.walletList) {
            WalletList()
        }
    }
}
