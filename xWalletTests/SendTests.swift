//
//  SendTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 3/3/26.
//

import ComposableArchitecture
import Testing
import BigInt
import EthereumKit
import Foundation
import SwiftUI

@testable import xWallet

@MainActor
struct SendTests {

    @Test
    func estimateGasSuccess() async {
        let mockTx = EthereumTransaction(
            chainId: EvmChain.sepolia.chainId,
            nonce: 0,
            maxPriorityFeePerGas: Wei.fromGwei(2),
            maxFeePerGas: Wei.fromGwei(20),
            gasLimit: 21_000,
            to: EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!,
            value: Wei.fromEther("0.01") ?? .zero,
            data: Data()
        )
        let estimate = Send.GasEstimate(
            transaction: mockTx,
            maxFeePerGas: Wei.fromGwei(20),
            maxPriorityFeePerGas: Wei.fromGwei(2),
            gasLimit: 21_000
        )
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            toAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            amount: "0.01",
            phase: .estimating
        )

        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateGasResponse(.success(estimate))) {
            $0.gasEstimate = "21000"
            $0.maxFeePerGas = "20000000000 Gwei"
            $0.maxPriorityFeePerGas = "2000000000 Gwei"
            $0.preparedTx = mockTx
            $0.phase = .confirm
        }
    }

    @Test
    func estimateGasFailure() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .estimating
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateGasResponse(.failure(SendError.invalidAddress))) {
            $0.phase = .input
            $0.errorMessage = SendError.invalidAddress.localizedDescription
        }
    }

    @Test
    func estimateGasWithInvalidAddress() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            toAddress: "not-an-address",
            amount: "1.0"
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateGasTapped) {
            $0.errorMessage = "Invalid address"
        }
    }

    @Test
    func estimateGasWithInvalidAmount() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            toAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            amount: "invalid"
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateGasTapped) {
            $0.errorMessage = "Invalid amount"
        }
    }

    @Test
    func sendSuccessEntersPendingPhase() async {
        let txHash = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .sending
        )
        let store = TestStore(initialState: state) {
            Send()
        }
        store.exhaustivity = .off

        await store.send(.sendResponse(.success(txHash))) {
            $0.txHash = txHash
            $0.phase = .pending(txHash)
        }
        await store.receive(\.pollReceipt)
    }

    @Test
    func sendFailure() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .sending
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.sendResponse(.failure(SendError.invalidAmount))) {
            $0.phase = .failure(SendError.invalidAmount.localizedDescription)
        }
    }

    @Test
    func pollReceiptMinedTransition() async {
        let txHash = "0xabc"
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .pending(txHash)
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.pollReceiptResponse(.success(true))) {
            $0.phase = .success(txHash)
        }
    }

    @Test
    func pollReceiptFailure() async {
        struct NetworkError: Error, LocalizedError {
            var errorDescription: String? { "Request timed out" }
        }

        let txHash = "0xabc"
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .pending(txHash)
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.pollReceiptResponse(.failure(NetworkError()))) {
            $0.phase = .failure("Request timed out")
        }
    }

    @Test
    func dismissErrorResetsToInput() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            errorMessage: "some error",
            phase: .failure("some error")
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.dismissError) {
            $0.errorMessage = nil
            $0.phase = .input
        }
    }

    @Test
    func assetSelection() async {
        let ethAsset = AssetItem(
            id: "ETH",
            symbol: "ETH",
            name: "Ethereum",
            balance: "1.5",
            value: "--",
            change: "--",
            icon: "diamond.fill",
            color: .indigo
        )
        let usdcAsset = AssetItem(
            id: "11155111:0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
            symbol: "USDC",
            name: "USD Coin",
            balance: "100.0",
            value: "--",
            change: "--",
            icon: "dollarsign.circle.fill",
            color: .blue
        )
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            selectedAsset: ethAsset,
            amount: "0.5",
            gasEstimate: "21000"
        )

        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.assetSelected(usdcAsset)) {
            $0.selectedAsset = usdcAsset
            $0.amount = ""
            $0.gasEstimate = ""
            $0.maxFeePerGas = ""
            $0.maxPriorityFeePerGas = ""
            $0.preparedTx = nil
            $0.phase = .input
        }
    }
}
