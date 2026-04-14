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
        @Shared(.appStorage("lockTimeout")) var lockTimeout: Int = LockTimeout.fiveMinutes.rawValue
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case chainManagement(PresentationAction<ChainManagement.Action>)
        case importAccount(PresentationAction<Account.Action>)
        case walletList(PresentationAction<WalletList.Action>)
        case manageChainsTapped
        case importAccountTapped
        case walletListTapped
        case lockTimeoutChanged(Int)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .lockTimeoutChanged(let rawValue):
                state.$lockTimeout.withLock { $0 = rawValue }
                return .none
            case .manageChainsTapped:
                state.chainManagement = ChainManagement.State()
                return .none
            case .importAccountTapped:
                state.importAccount = Account.State()
                return .none
            case .walletListTapped:
                state.walletList = WalletList.State()
                return .none
            case .walletList(.presented(.addAccountTapped)):
                state.walletList = nil
                state.importAccount = Account.State()
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
