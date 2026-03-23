//
//  HistoryTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 9/3/26.
//

import ComposableArchitecture
import Testing
import Foundation

@testable import xWallet

@MainActor
struct HistoryTests {

    private static let testChain = Chain(
        id: "sepolia", chainId: "11155111", name: "Sepolia",
        rpcURL: "https://rpc.sepolia.org", isTestnet: true,
        symbol: "ETH", decimals: 18,
        explorerURL: "https://sepolia.etherscan.io", enabled: true
    )

    private static let testTx = HistoryTransaction(
        id: "0xabc123",
        hash: "0xabc123",
        from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        fromEns: nil,
        to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        toEns: "vitalik.eth",
        value: "0.05 ETH",
        symbol: "ETH",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        isOutgoing: true,
        status: .success,
        chainId: "11155111",
        blockNumber: 100,
        method: nil
    )

    @Test
    func onAppearFetchesFirstPage() async {
        let store = TestStore(
            initialState: History.State(
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                chain: Self.testChain
            )
        ) {
            History()
        } withDependencies: {
            $0.transactionHistory.fetchHistory = { _, _, _ in
                await HistoryPage(
                    transactions: [Self.testTx],
                    nextPageParams: ["block_number": "99"]
                )
            }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.historyResponse.success) {
            $0.isLoading = false
            $0.transactions = [Self.testTx]
            $0.nextPageParams = ["block_number": "99"]
            $0.hasMore = true
        }
    }

    @Test
    func onAppearWithoutAddressDoesNothing() async {
        let store = TestStore(
            initialState: History.State(address: nil, chain: Self.testChain)
        ) {
            History()
        }

        await store.send(.onAppear)
        // No effect, no state change
    }

    @Test
    func loadMoreAppendsTransactions() async {
        let secondTx = HistoryTransaction(
            id: "0xdef456",
            hash: "0xdef456",
            from: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
            fromEns: nil,
            to: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            toEns: nil,
            value: "1.0 ETH",
            symbol: "ETH",
            timestamp: Date(timeIntervalSince1970: 1_699_999_000),
            isOutgoing: false,
            status: .success,
            chainId: "11155111",
            blockNumber: 98,
            method: nil
        )

        let store = TestStore(
            initialState: History.State(
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                chain: Self.testChain,
                hasMore: true,
                nextPageParams: ["block_number": "99"],
                transactions: [Self.testTx]
            )
        ) {
            History()
        } withDependencies: {
            $0.transactionHistory.fetchHistory = { _, _, _ in
                HistoryPage(transactions: [secondTx], nextPageParams: nil)
            }
        }

        await store.send(.loadMore) {
            $0.isLoading = true
        }
        await store.receive(\.historyResponse.success) {
            $0.isLoading = false
            $0.transactions = [Self.testTx, secondTx]
            $0.nextPageParams = nil
            $0.hasMore = false
        }
    }

    @Test
    func loadMoreWhenNoMoreDoesNothing() async {
        let store = TestStore(
            initialState: History.State(
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                chain: Self.testChain,
                hasMore: false,
                transactions: [Self.testTx]
            )
        ) {
            History()
        }

        await store.send(.loadMore)
    }

    @Test
    func fetchFailureSetsErrorMessage() async {
        let store = TestStore(
            initialState: History.State(
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                chain: Self.testChain
            )
        ) {
            History()
        } withDependencies: {
            $0.transactionHistory.fetchHistory = { _, _, _ in
                throw HistoryError.httpError
            }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.historyResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = HistoryError.httpError.localizedDescription
        }
    }

    @Test
    func refreshReplacesTransactions() async {
        let newTx = HistoryTransaction(
            id: "0xnew789",
            hash: "0xnew789",
            from: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
            fromEns: nil,
            to: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            toEns: nil,
            value: "2.0 ETH",
            symbol: "ETH",
            timestamp: Date(timeIntervalSince1970: 1_700_001_000),
            isOutgoing: false,
            status: .success,
            chainId: "11155111",
            blockNumber: 101,
            method: nil
        )

        let store = TestStore(
            initialState: History.State(
                address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                chain: Self.testChain,
                hasMore: false,
                transactions: [Self.testTx]
            )
        ) {
            History()
        } withDependencies: {
            $0.transactionHistory.fetchHistory = { _, _, _ in
                HistoryPage(transactions: [newTx], nextPageParams: nil)
            }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }
        await store.receive(\.refreshResponse.success) {
            $0.isLoading = false
            $0.transactions = [newTx]
            $0.nextPageParams = nil
            $0.hasMore = false
        }
    }
}
