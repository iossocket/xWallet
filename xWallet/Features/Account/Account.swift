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
    case selectChain
    case showMnemonic
    case verifyMnemonic
    case importMnemonic
    case importPrivateKey
}

@Reducer
struct Account {
    @ObservableState
    struct State: Equatable {
        var errorMessage: String?
        var isUnlocked: Bool = false

        var onboardingStep: OnboardingStep = .landing
        var selectedChain: ChainType = .evm
        var selectedStarknetAccountType: StarknetAccountType? = nil
        var selectedStarknetChainId: StarknetChainId? = nil
        var generatedMnemonic: String = ""
        var mnemonicInput: String = ""
        var privateKeyInput: String = ""
        var walletNameInput: String = ""
        var isLoading: Bool = false
        
        @Shared(.activeIdentitySet) var activeIdentitySet: ActiveWalletIdentitySet
    }
    
    enum Action {
        case onAppear
        case didLoadIdentity(ActiveWalletIdentitySet)
        case lockButtonTapped
        case chainSelected(ChainType)
        case starknetAccountTypeSelected(StarknetAccountType?)
        case starknetChainIdSelected(StarknetChainId?)

        // new wallet
        case createWalletTapped
        case createWalletResponse(Result<WalletIdentity?, Error>)
        case mnemonicBackupConfirmed

        // import mnemonic
        case showImportMnemonicTapped
        case mnemonicInputChanged(String)
        case importMnemonicTapped
        case importMnemonicResponse(Result<WalletIdentity?, Error>)

        // import private key
        case showImportPrivateKeyTapped
        case privateKeyInputChanged(String)
        case importPrivateKeyTapped
        case importPrivateKeyResponse(Result<WalletIdentity?, Error>)

        case walletNameChanged(String)
        case backButtonTapped
    }
    
    @Dependency(\.walletClient) var walletClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [walletClient] send in
                    if let identity = try? await walletClient.activeIdentitySet() {
                        await send(.didLoadIdentity(identity))
                    }
                }
            case .didLoadIdentity(let identitySet):
                state.isLoading = false
                state.$activeIdentitySet.withLock {
                    $0 = identitySet
                }
                state.isUnlocked = true
                return .none
            case .chainSelected(let chain):
                state.selectedChain = chain
                if chain == .evm {
                    state.selectedStarknetAccountType = nil
                    state.selectedStarknetChainId = nil
                }
                return .none
            case .starknetAccountTypeSelected(let type):
                state.selectedStarknetAccountType = type
                return .none
            case .starknetChainIdSelected(let chainId):
                state.selectedStarknetChainId = chainId
                return .none
            
            case .createWalletTapped:
                state.isLoading = true
                state.errorMessage = nil
                let chain = state.selectedChain
                let name = state.walletNameInput.isEmpty ? nil : state.walletNameInput
                return .run { [walletClient] send in
                    await send(.createWalletResponse(
                        Result { try await walletClient.createWallet(name, chain) }
                    ))
                }
            case .createWalletResponse(.success(let identity)):
                state.isLoading = false
                state.$activeIdentitySet.withLock {
                    $0.updateIdentity(identity: identity)
                }
                if identity?.sourceType == .mnemonic && !state.generatedMnemonic.isEmpty {
                    state.onboardingStep = .showMnemonic
                } else {
                    state.isUnlocked = true
                }
                return .none
            case .createWalletResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .mnemonicBackupConfirmed:
                state.isUnlocked = true
                state.generatedMnemonic = ""
                return .none
            case .showImportMnemonicTapped:
                state.onboardingStep = .importMnemonic
                return .none
            case .mnemonicInputChanged(let input):
                state.mnemonicInput = input
                return .none
            case .importMnemonicTapped:
                state.isLoading = true
                state.errorMessage = nil
                let mnemonic = state.mnemonicInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let chain = state.selectedChain
                let name = state.walletNameInput.isEmpty ? nil : state.walletNameInput
                return .run { [walletClient] send in
                    await send(.importMnemonicResponse(
                        Result { try await walletClient.importMnemonic(mnemonic, name, chain) }
                    ))
                }
            case .importMnemonicResponse(.success(let identity)):
                state.isLoading = false
                state.$activeIdentitySet.withLock {
                    $0.updateIdentity(identity: identity)
                }
                state.isUnlocked = true
                state.errorMessage = nil
                return .none
            case .importMnemonicResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .showImportPrivateKeyTapped:
                state.onboardingStep = .importPrivateKey
                return .none
            case .privateKeyInputChanged(let input):
                state.privateKeyInput = input
                return .none
            case .importPrivateKeyTapped:
                state.isLoading = true
                state.errorMessage = nil
                let hex = state.privateKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let chain = state.selectedChain
                let name = state.walletNameInput.isEmpty ? nil : state.walletNameInput
                let accountType = state.selectedStarknetAccountType
                let chainId = state.selectedStarknetChainId
                let config = chain == .evm ? ChainConfig.evm : ChainConfig.starknet(accountType: accountType ?? StarknetAccountType.argent, chainId: chainId ?? StarknetChainId.mainnet)
                return .run { [walletClient] send in
                    await send(.importPrivateKeyResponse(
                        Result { try await walletClient.importPrivateKey(hex, name, config) }
                    ))
                }
            case .importPrivateKeyResponse(.success(let identity)):
                state.isLoading = false
                state.$activeIdentitySet.withLock {
                    $0.updateIdentity(identity: identity)
                }
                state.isUnlocked = true
                state.errorMessage = nil
                return .none
            case .importPrivateKeyResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case .walletNameChanged(let name):
                state.walletNameInput = name
                return .none
            case .lockButtonTapped:
                state.isUnlocked = false
                state.$activeIdentitySet.withLock {
                    $0.clear()
                }
                return .none
            case .backButtonTapped:
                state.onboardingStep = .landing
                return .none
            }
        }
    }
}
