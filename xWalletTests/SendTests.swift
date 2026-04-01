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
import StarknetKit
import Foundation
import SwiftUI

@testable import xWallet

@MainActor
struct SendTests {

    @Test
    func estimateFeeSuccessEvm() async {
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
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            toAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            amount: "0.01",
            phase: .estimating
        )

        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateFeeResponse(.success(.evm(mockTx)))) {
            $0.feeEstimate = .evm(mockTx)
            $0.phase = .confirm
        }
    }

    @Test
    func estimateFeeFailure() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .estimating
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateFeeResponse(.failure(SendError.invalidAddress))) {
            $0.phase = .input
            $0.errorMessage = SendError.invalidAddress.localizedDescription
        }
    }

    @Test
    func estimateFeeWithInvalidAddress() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            toAddress: "not-an-address",
            amount: "1.0"
        )
        let store = TestStore(initialState: state) {
            Send()
        } withDependencies: {
            $0.sendClient.validateAddress = { _, _ in false }
        }

        await store.send(.estimateFeeTapped) {
            $0.errorMessage = "Invalid address"
        }
    }

    @Test
    func estimateFeeWithInvalidAmount() async {
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            toAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            amount: "invalid"
        )
        let store = TestStore(initialState: state) {
            Send()
        } withDependencies: {
            $0.sendClient.validateAddress = { _, _ in true }
        }

        await store.send(.estimateFeeTapped) {
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
        } withDependencies: {
            $0.sendClient.waitForConfirmation = { _, _ in .success }
        }
        store.exhaustivity = .off

        await store.send(.sendResponse(.success(txHash))) {
            $0.txHash = txHash
            $0.phase = .pending(txHash)
        }
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
    func waitForConfirmationSuccess() async {
        let txHash = "0xabc"
        let state = Send.State(
            chain: EvmChain.sepolia.toChain(),
            phase: .pending(txHash)
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.waitForConfirmationResponse(.success(.success))) {
            $0.phase = .success(txHash)
        }
    }

    @Test
    func waitForConfirmationFailure() async {
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

        await store.send(.waitForConfirmationResponse(.failure(NetworkError()))) {
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
            amount: "0.5"
        )

        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.assetSelected(usdcAsset)) {
            $0.selectedAsset = usdcAsset
            $0.amount = ""
            $0.feeEstimate = nil
            $0.phase = .input
        }
    }

    // MARK: - Starknet Tests

    @Test
    func estimateFeeSuccessStarknet() async {
        let json = """
        {"gas_consumed":"0x1a4","gas_price":"0x3b9aca00","data_gas_consumed":"0x0","data_gas_price":"0x1","overall_fee":"0x61c46800","fee_unit":"WEI"}
        """
        let mockEstimate = try! JSONDecoder().decode(StarknetFeeEstimate.self, from: json.data(using: .utf8)!)
        let state = Send.State(
            chain: Starknet.sepolia.toChain(),
            toAddress: "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
            amount: "1.0",
            phase: .estimating
        )

        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.estimateFeeResponse(.success(.starknet(mockEstimate)))) {
            $0.feeEstimate = .starknet(mockEstimate)
            $0.phase = .confirm
        }
    }

    @Test
    func sendSuccessEntersPendingPhaseStarknet() async {
        let txHash = "0x01abc"
        let state = Send.State(
            chain: Starknet.sepolia.toChain(),
            phase: .sending
        )
        let store = TestStore(initialState: state) {
            Send()
        } withDependencies: {
            $0.sendClient.waitForConfirmation = { _, _ in .success }
        }
        store.exhaustivity = .off

        await store.send(.sendResponse(.success(txHash))) {
            $0.txHash = txHash
            $0.phase = .pending(txHash)
        }
    }

    @Test
    func waitForConfirmationSuccessStarknet() async {
        let txHash = "0x01abc"
        let state = Send.State(
            chain: Starknet.sepolia.toChain(),
            phase: .pending(txHash)
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.waitForConfirmationResponse(.success(.success))) {
            $0.phase = .success(txHash)
        }
    }

    @Test
    func waitForConfirmationRevertedStarknet() async {
        let txHash = "0x01abc"
        let state = Send.State(
            chain: Starknet.sepolia.toChain(),
            phase: .pending(txHash)
        )
        let store = TestStore(initialState: state) {
            Send()
        }

        await store.send(.waitForConfirmationResponse(.success(.reverted("Execution reverted")))) {
            $0.phase = .failure("Execution reverted")
        }
    }
}
