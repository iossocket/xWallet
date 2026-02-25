//
//  Account.swift
//  xWallet
//
//  Created by Xueliang Zhu on 20/2/26.
//

import ComposableArchitecture
import EthereumKit

enum OnboardingStep: Equatable {
    case landing
    case showMnemonic
    case verifyMnemonic
    case importMnemonic
    case importPrivateKey
}

@Reducer
struct Account {
    @ObservableState
    struct State: Equatable {
        var address: String?
        var errorMessage: String?
        var isUnlocked: Bool = false
//        var onboardingStep: OnboardingStep = .landing
//        var generatedMnemonic: String = ""
//        var mnemonicInput: String = ""
//        var mnemonicConfirmWords: [String] = []
//        var isLoading: Bool = false
    }
    
    enum Action {
        case importButtonTapped(String)
        case importResponse(Result<String, Error>)
        case lockButtonTapped
        case onAppear
        
//        case createWalletTapped
//        case createWalletResponse(Result<WalletSnapshot, Error>)
//        case showImportMnemonicTapped
//        case mnemonicInputChanged(String)
//        case importMnemonicTapped
//        case importMnemonicResponse(Result<WalletSnapshot, Error>)
//        case mnemonicBackupConfirmed
    }
    
    @Dependency(\.keychain) var keychain
    
    private let keyPrivateKey = "evm_private_key"
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                do {
                    let pkData = try keychain.loadData(keyPrivateKey)
                    if let address = try? Secp256k1.ethereumAddress(fromPrivateKey: pkData) {
                        state.address = address.checksummed
                        state.isUnlocked = true
                    }
                } catch {
                    
                }
                return .none
            case .importButtonTapped(let hex):
                state.errorMessage = nil
                return .run { [keychain = self.keychain, key = self.keyPrivateKey] send in
                    do {
                        let pkData = try PrivateKeyUtils.normalizePrivateKey(hex: hex)
                        let address = try Secp256k1.ethereumAddress(fromPrivateKey: pkData)
                        try keychain.saveData(pkData, key)
                        await send(.importResponse(.success(address.checksummed)))
                    } catch {
                        await send(.importResponse(.failure(error)))
                    }
                }
            case .importResponse(.success(let address)):
                state.address = address
                state.isUnlocked = true
                state.errorMessage = nil
                return .none

            case .importResponse(.failure(let error)):
                state.errorMessage = error.localizedDescription
                state.isUnlocked = false
                return .none

            case .lockButtonTapped:
                state.isUnlocked = false
                state.address = nil
                return .none
            }
        }
    }
}
