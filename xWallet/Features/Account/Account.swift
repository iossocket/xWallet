//
//  Account.swift
//  xWallet
//
//  Created by Xueliang Zhu on 20/2/26.
//

import ComposableArchitecture
import EthereumKit
import MultiChainKit

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
        @Presents var accountDeploy: AccountDeploy.State?
        
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
        case accountDeploy(PresentationAction<AccountDeploy.Action>)
        case checkDeployStatusResponse(AccountDeploy.State, Result<Bool, Error>)
        case switchWalletResponse(Result<WalletIdentity?, Error>)
    }
    
    @Dependency(\.walletClient) var walletClient
    @Dependency(\.starknetRPCService) var starknetRPCService
    
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
                guard let accountType = AccountType(rawValue: chain.rawValue, subtype: state.selectedStarknetAccountType?.rawValue) else {
                    return .none
                }
                return .run { [walletClient] send in
                    await send(.createWalletResponse(
                        Result { try await walletClient.createWallet(name, accountType) }
                    ))
                }
            case .createWalletResponse(.success(let identity)):
                state.isLoading = false
                if identity?.sourceType == .mnemonic && !state.generatedMnemonic.isEmpty {
                    state.onboardingStep = .showMnemonic
                } else {
                    state.isUnlocked = true
                }
                guard let identity else { return .none }
                guard let deployState = makeAccountDeployState(identity: identity) else {
                    state.accountDeploy = nil
                    return .run { [walletClient] send in
                        await send(.switchWalletResponse(Result { try await walletClient.switchWallet(identity.id) }))
                    }
                }
                return .run { [deployState, starknetRPCService] send in
                    let deployed = try await starknetRPCService.isAccountDeployed(deployState.address, deployState.starknet)
                    await send(.checkDeployStatusResponse(deployState, .success(deployed)))
                } catch: { error, send in
                    await send(.checkDeployStatusResponse(deployState, .failure(error)))
                }
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
                guard let accountType = AccountType(rawValue: chain.rawValue, subtype: state.selectedStarknetAccountType?.rawValue) else {
                    return .none
                }
                return .run { [walletClient] send in
                    await send(.importMnemonicResponse(
                        Result { try await walletClient.importMnemonic(mnemonic, name, accountType) }
                    ))
                }
            case .importMnemonicResponse(.success(let identity)):
                state.isLoading = false
                state.isUnlocked = true
                state.errorMessage = nil
                guard let identity else { return .none }
                guard let deployState = makeAccountDeployState(identity: identity) else {
                    state.accountDeploy = nil
                    return .run { [walletClient] send in
                        await send(.switchWalletResponse(Result { try await walletClient.switchWallet(identity.id) }))
                    }
                }
                return .run { [deployState, starknetRPCService] send in
                    let deployed = try await starknetRPCService.isAccountDeployed(deployState.address, deployState.starknet)
                    await send(.checkDeployStatusResponse(deployState, .success(deployed)))
                } catch: { error, send in
                    await send(.checkDeployStatusResponse(deployState, .failure(error)))
                }
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
                state.isUnlocked = true
                state.errorMessage = nil
                guard let identity else { return .none }
                guard let deployState = makeAccountDeployState(identity: identity) else {
                    state.accountDeploy = nil
                    return .run { [walletClient] send in
                        await send(.switchWalletResponse(Result { try await walletClient.switchWallet(identity.id) }))
                    }
                }
                return .run { [deployState, starknetRPCService] send in
                    let deployed = try await starknetRPCService.isAccountDeployed(deployState.address, deployState.starknet)
                    await send(.checkDeployStatusResponse(deployState, .success(deployed)))
                } catch: { error, send in
                    await send(.checkDeployStatusResponse(deployState, .failure(error)))
                }
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
            case .accountDeploy(.presented(.pollStatusResponse(.success(true)))):
                guard let deployState = state.accountDeploy else {
                    return .none
                }
                return .run { [walletClient] send in
                    await send(.switchWalletResponse(Result { try await walletClient.switchWallet(deployState.identityId) }))
                }
            case .accountDeploy:
                return .none
            case .switchWalletResponse(.success(let identity)):
                state.$activeIdentitySet.withLock {
                    $0.updateIdentity(identity: identity)
                }
                state.errorMessage = nil
                state.accountDeploy = nil
                return .none
            case .switchWalletResponse(.failure(let error)):
                state.errorMessage = error.localizedDescription
                return .none
            case .checkDeployStatusResponse(let deployState, let result):
                switch result {
                case .success(let isDeployed):
                    if isDeployed {
                        state.accountDeploy = nil
                        return .run { [walletClient] send in
                            await send(.switchWalletResponse(Result { try await walletClient.switchWallet(deployState.identityId) }))
                        }
                    }
                    state.accountDeploy = deployState
                case .failure:
                    // Fallback to showing deploy flow if status check fails.
                    state.accountDeploy = deployState
                }
                return .none
            }
        }
        .ifLet(\.$accountDeploy, action: \.accountDeploy) {
            AccountDeploy()
        }
    }
}

private func makeAccountDeployState(identity: WalletIdentity?) -> AccountDeploy.State? {
    guard let identity else { return nil }
    guard identity.accountType.chainType == .starknet else { return nil }
    guard let address = identity.primaryAddress else { return nil }
    guard let starknetAccountType = identity.accountType.starknetAccountType else { return nil }
    let starknet: Starknet = identity.chainId == StarknetChainId.mainnet.rawValue ? .mainnet : .sepolia
    return AccountDeploy.State(
        identityId: identity.id,
        address: address,
        starknet: starknet,
        starknetAccountType: starknetAccountType
    )
}
