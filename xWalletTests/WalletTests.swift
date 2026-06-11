//
//  WalletTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 23/2/26.
//

import ComposableArchitecture
import Testing
import BigInt
import EthereumKit
import Foundation
import SwiftUI

@testable import xWallet

@MainActor
struct WalletTests {

    private static let testIdentity = WalletIdentity(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Test Wallet",
        sourceType: .mnemonic,
        accountType: .evm,
        createdAt: Date(),
        derivedAddresses: [
            DerivedAddress(
                chain: .evm,
                path: "m/44'/60'/0'/0/0",
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            )
        ]
    )

    private static let starknetIdentity = WalletIdentity(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
        name: "Starknet Wallet",
        sourceType: .mnemonic,
        accountType: .starknet(.oz),
        createdAt: Date(),
        chainId: StarknetChainId.sepolia.rawValue,
        derivedAddresses: [
            DerivedAddress(
                chain: .starknet,
                path: "m/44'/9004'/0'/0/0",
                address: "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            )
        ]
    )

    @Test
    func toggleShowBalance() async {
        let state = Wallet.State(showBalance: true)
        let store = TestStore(initialState: state) {
            Wallet()
        }

        await store.send(.setShowBalance(false)) {
            $0.showBalance = false
        }
    }

    @Test
    func receiveButtonPresentsSheet() async {
        @Shared(.activeIdentitySet) var activeIdentitySet = ActiveWalletIdentitySet(evm: Self.testIdentity)

        let state = Wallet.State()
        let store = TestStore(initialState: state) {
            Wallet()
        }

        await store.send(.receiveButtonTapped) {
            $0.receive = Receive.State(address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
        }
    }

    @Test
    func refreshWithoutAddressDoesNothing() async {
        let state = Wallet.State()
        let store = TestStore(initialState: state) {
            Wallet()
        }

        await store.send(.refreshButtonTapped)
    }

    // MARK: - onAppear

    @Test
    func onAppearLoadsChainsAndRefreshes() async {
        @Shared(.activeIdentitySet) var activeIdentitySet = ActiveWalletIdentitySet(evm: Self.testIdentity)

        let sepoliaRecord = Chain(
            id: "sepolia", chainId: "11155111", name: "Sepolia",
            rpcURL: "https://rpc.sepolia.org", isTestnet: true,
            symbol: "ETH", decimals: 18, explorerURL: nil, enabled: true
        )

        let store = TestStore(initialState: Wallet.State()) {
            Wallet()
        } withDependencies: {
            $0.chainRegistry.listEnabledChains = { [sepoliaRecord] }
            $0.balanceClient.fetchBalances = { _, _ in
                [ChainBalance(
                    chainId: "11155111", chainType: .evm, chainName: "Sepolia",
                    symbol: "ETH", decimals: 18,
                    nativeBalance: BigUInt("1000000000000000000"), tokens: []
                )]
            }
            $0.priceClient.fetchPrices = { _, symbols in
                Dictionary(uniqueKeysWithValues: symbols.map { ($0, 2000.0) })
            }
        }

        await store.send(.onAppear)

        await store.receive(\.loadSupportedChainsResponse.success) {
            $0.supportedChains = [sepoliaRecord]
        }

        await store.receive(\.refreshButtonTapped)

        await store.receive(\.fetchAllBalances) {
            $0.isLoadingAllChains = true
        }

        await store.receive(\.allBalancesResponse.success) {
            $0.isLoadingAllChains = false
            $0.chainBalances = [
                ChainBalance(
                    chainId: "11155111",
                    chainType: .evm,
                    chainName: "Sepolia",
                    symbol: "ETH",
                    decimals: 18,
                    nativeBalance: BigUInt("1000000000000000000"),
                    tokens: []
                )
            ]
        }

        await store.receive(\.fetchPrices)

        await store.receive(\.pricesResponse.success) {
            $0.prices = ["ETH": 2000.0]
            $0.assets = IdentifiedArray(uniqueElements: [
                AssetItem(
                    id: "11155111:ETH", symbol: "ETH", name: "Sepolia",
                    balance: "1", value: "$2,000.00", change: "--",
                    icon: "diamond.fill", color: .indigo
                )
            ])
            $0.totalUsdValue = "$2,000.00"
            $0.currentChainUsdValue = "$2,000.00"
        }
    }

    @Test
    func onAppearLoadChainsFailureFallsBackAndRefreshes() async {
        @Shared(.activeIdentitySet) var activeIdentitySet = ActiveWalletIdentitySet(evm: Self.testIdentity)

        let fallbackChains = [EvmChain.sepolia, EvmChain.mainnet].map { $0.toChain() }

        let store = TestStore(initialState: Wallet.State()) {
            Wallet()
        } withDependencies: {
            $0.chainRegistry.listEnabledChains = { throw NSError(domain: "test", code: 1) }
            $0.balanceClient.fetchBalances = { _, _ in
                [
                    ChainBalance(
                        chainId: "11155111", chainType: .evm, chainName: "Sepolia",
                        symbol: "ETH", decimals: 18, nativeBalance: BigUInt(0), tokens: []
                    ),
                    ChainBalance(
                        chainId: "1", chainType: .evm, chainName: "Ethereum Mainnet",
                        symbol: "ETH", decimals: 18, nativeBalance: BigUInt(0), tokens: []
                    ),
                ]
            }
            $0.priceClient.fetchPrices = { _, symbols in
                Dictionary(uniqueKeysWithValues: symbols.map { ($0, 0.0) })
            }
        }

        await store.send(.onAppear)

        await store.receive(\.loadSupportedChainsResponse.failure) {
            $0.supportedChains = fallbackChains
        }

        await store.receive(\.refreshButtonTapped)

        await store.receive(\.fetchAllBalances) {
            $0.isLoadingAllChains = true
        }

        await store.receive(\.allBalancesResponse.success) {
            $0.isLoadingAllChains = false
            $0.chainBalances = [
                ChainBalance(
                    chainId: "11155111",
                    chainType: .evm,
                    chainName: "Sepolia",
                    symbol: "ETH",
                    decimals: 18,
                    nativeBalance: BigUInt(0),
                    tokens: []
                ),
                ChainBalance(
                    chainId: "1",
                    chainType: .evm,
                    chainName: "Ethereum Mainnet",
                    symbol: "ETH",
                    decimals: 18,
                    nativeBalance: BigUInt(0),
                    tokens: []
                ),
            ]
        }

        await store.receive(\.fetchPrices)

        await store.receive(\.pricesResponse.success) {
            $0.prices = ["ETH": 0.0]
            $0.assets = IdentifiedArray(uniqueElements: [
                AssetItem(
                    id: "11155111:ETH", symbol: "ETH", name: "Sepolia",
                    balance: "0", value: "$0.00", change: "--",
                    icon: "diamond.fill", color: .indigo
                ),
            ])
            $0.totalUsdValue = "$0.00"
            $0.currentChainUsdValue = "$0.00"
        }
    }

    // MARK: - ViewMode

    @Test
    func viewModeToggledToSingleChainFromAllChains() async {
        // Default is .allChains, toggle to .singleChain — rebuilds assets (empty since no data)
        let store = TestStore(initialState: Wallet.State()) {
            Wallet()
        }

        await store.send(.viewModeToggled) {
            $0.viewMode = .singleChain
            $0.totalUsdValue = "$0.00"
            $0.currentChainUsdValue = "$0.00"
        }
    }

    @Test
    func viewModeToggledBackToAllChainsTriggersFetch() async {
        @Shared(.activeIdentitySet) var activeIdentitySet = ActiveWalletIdentitySet(evm: Self.testIdentity)

        let sepoliaRecord = Chain(
            id: "sepolia", chainId: "11155111", name: "Sepolia",
            rpcURL: "https://rpc.sepolia.org", isTestnet: true,
            symbol: "ETH", decimals: 18, explorerURL: nil, enabled: true
        )

        var state = Wallet.State(supportedChains: [sepoliaRecord])
        state.viewMode = .singleChain

        let store = TestStore(initialState: state) {
            Wallet()
        } withDependencies: {
            $0.balanceClient.fetchBalances = { _, _ in
                [ChainBalance(
                    chainId: "11155111", chainType: .evm, chainName: "Sepolia",
                    symbol: "ETH", decimals: 18,
                    nativeBalance: BigUInt("1000000000000000000"), tokens: []
                )]
            }
            $0.priceClient.fetchPrices = { _, symbols in
                Dictionary(uniqueKeysWithValues: symbols.map { ($0, 2000.0) })
            }
        }

        await store.send(.viewModeToggled) {
            $0.viewMode = .allChains
        }

        await store.receive(\.fetchAllBalances) {
            $0.isLoadingAllChains = true
        }

        await store.receive(\.allBalancesResponse.success) {
            $0.isLoadingAllChains = false
            $0.chainBalances = [
                ChainBalance(
                    chainId: "11155111",
                    chainType: .evm,
                    chainName: "Sepolia",
                    symbol: "ETH",
                    decimals: 18,
                    nativeBalance: BigUInt("1000000000000000000"),
                    tokens: []
                )
            ]
        }

        await store.receive(\.fetchPrices)

        await store.receive(\.pricesResponse.success) {
            $0.prices = ["ETH": 2000.0]
            $0.assets = IdentifiedArray(uniqueElements: [
                AssetItem(
                    id: "11155111:ETH", symbol: "ETH", name: "Sepolia",
                    balance: "1", value: "$2,000.00", change: "--",
                    icon: "diamond.fill", color: .indigo
                )
            ])
            $0.totalUsdValue = "$2,000.00"
            $0.currentChainUsdValue = "$2,000.00"
        }
    }

    @Test
    func fetchAllBalancesWithoutAddressDoesNothing() async {
        let store = TestStore(initialState: Wallet.State()) {
            Wallet()
        }

        await store.send(.fetchAllBalances)
    }

    // MARK: - Prices

    @Test
    func chainChangedRebuildsAssetsForSingleChain() async {
        @Shared(.activeIdentitySet) var activeIdentitySet = ActiveWalletIdentitySet(evm: Self.testIdentity)

        let sepoliaBalance = ChainBalance(
            chainId: "11155111", chainType: .evm, chainName: "Sepolia", symbol: "ETH",
            decimals: 18, nativeBalance: BigUInt("1000000000000000000"), tokens: []
        )
        let mainnetBalance = ChainBalance(
            chainId: "1", chainType: .evm, chainName: "Ethereum Mainnet", symbol: "ETH",
            decimals: 18, nativeBalance: BigUInt("2000000000000000000"), tokens: []
        )

        let mainnetRecord = Chain(
            id: "mainnet", chainId: "1", name: "Ethereum Mainnet",
            rpcURL: "https://rpc.mainnet.org", isTestnet: false,
            symbol: "ETH", decimals: 18, explorerURL: nil, enabled: true
        )

        var state = Wallet.State()
        state.viewMode = .singleChain
        state.chainBalances = [sepoliaBalance, mainnetBalance]
        state.prices = ["ETH": 2000.0]
        // Pre-populate assets for sepolia (current default chain)
        state.assets = IdentifiedArray(uniqueElements: [
            AssetItem(
                id: "11155111:ETH", symbol: "ETH", name: "Sepolia",
                balance: "1", value: "$2,000.00", change: "--",
                icon: "diamond.fill", color: .indigo
            )
        ])
        state.totalUsdValue = "$6,000.00"
        state.currentChainUsdValue = "$2,000.00"

        let store = TestStore(initialState: state) {
            Wallet()
        }

        // Switch to mainnet — should rebuild assets showing only mainnet
        await store.send(.chainChanged(mainnetRecord)) {
            $0.$currentChain.withLock { $0 = mainnetRecord }
            $0.assets = IdentifiedArray(uniqueElements: [
                AssetItem(
                    id: "1:ETH", symbol: "ETH", name: "Ethereum Mainnet",
                    balance: "2", value: "$4,000.00", change: "--",
                    icon: "diamond.fill", color: .indigo
                )
            ])
            $0.totalUsdValue = "$6,000.00"
            $0.currentChainUsdValue = "$4,000.00"
        }
    }

    @Test
    func pricesResponseBuildsAssetsFromChainBalances() async {
        var state = Wallet.State()
        state.chainBalances = [
            ChainBalance(
                chainId: "11155111",
                chainType: .evm,
                chainName: "Sepolia",
                symbol: "ETH",
                decimals: 18,
                nativeBalance: BigUInt("1500000000000000000"),
                tokens: [
                    TokenBalance(
                        chainId: "11155111",
                        contractAddress: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
                        symbol: "USDC",
                        name: "USD Coin",
                        decimals: 6,
                        rawBalance: BigUInt("1000000000")
                    )
                ]
            )
        ]

        let store = TestStore(initialState: state) {
            Wallet()
        }

        let prices: [String: Double] = ["ETH": 2000.0, "USDC": 1.0]
        await store.send(.pricesResponse(.success(prices))) {
            $0.prices = prices
            $0.assets = IdentifiedArray(uniqueElements: [
                AssetItem(
                    id: "11155111:ETH", symbol: "ETH", name: "Sepolia",
                    balance: "1.5", value: "$3,000.00", change: "--",
                    icon: "diamond.fill", color: .indigo
                ),
                AssetItem(
                    id: "11155111:0x1c7d4b196cb0c7b01d743fbc6116a902379c7238",
                    symbol: "USDC", name: "USD Coin",
                    balance: "1000", value: "$1,000.00", change: "+0.00%",
                    icon: "dollarsign.circle.fill", color: .blue
                ),
            ])
            $0.totalUsdValue = "$4,000.00"
            $0.currentChainUsdValue = "$4,000.00"
        }
    }

    @Test
    func pricesResponseFailureDoesNothing() async {
        let store = TestStore(initialState: Wallet.State()) {
            Wallet()
        }

        await store.send(.pricesResponse(.failure(PriceError.httpError)))
    }

    @Test
    func onAppearStarknetUndeployedSetsFalse() async {
        @Shared(.activeIdentitySet) var activeIdentitySet = ActiveWalletIdentitySet(starknet: Self.starknetIdentity)

        let store = TestStore(initialState: Wallet.State()) {
            Wallet()
        } withDependencies: {
            $0.chainRegistry.listEnabledChains = { [] }
            $0.balanceClient.fetchBalances = { _, _ in [] }
            $0.starknetRPCService.isAccountDeployed = { _, _ in false }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.checkDeployStatusResponse.success) {
            $0.isStarknetDeployed = false
        }
    }
}
