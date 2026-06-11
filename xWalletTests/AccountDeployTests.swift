//
//  AccountDeployTests.swift
//  xWalletTests
//

import ComposableArchitecture
import Testing
import Foundation
import BigInt
import MultiChainKit

@testable import xWallet

@MainActor
struct AccountDeployTests {
    private let identityId = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    private let address = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

    private static let mockFee: StarknetFeeEstimate = {
        let json = """
        {"gas_consumed":"0x1a4","gas_price":"0x3b9aca00","data_gas_consumed":"0x0","data_gas_price":"0x1","overall_fee":"0x61c46800","fee_unit":"WEI"}
        """
        return try! JSONDecoder().decode(StarknetFeeEstimate.self, from: Data(json.utf8))
    }()

    private static let mockSuccessReceipt: StarknetReceipt = {
        let json = """
        {
          "type": "DEPLOY_ACCOUNT",
          "transaction_hash": "0xabc",
          "actual_fee": {"amount": "0x2386f26fc10000", "unit": "FRI"},
          "execution_status": "SUCCEEDED",
          "finality_status": "ACCEPTED_ON_L2",
          "block_hash": "0x03b2711fe29eba45f2a0250c34901d15e37b495599fac498a3d2eaa4c2225c81",
          "block_number": 1,
          "messages_sent": [],
          "events": [],
          "execution_resources": {"steps": 1}
        }
        """
        return try! JSONDecoder().decode(StarknetReceipt.self, from: Data(json.utf8))
    }()

    private func makeState(phase: AccountDeploy.Phase = .checkBalance) -> AccountDeploy.State {
        AccountDeploy.State(
            phase: phase,
            identityId: self.identityId,
            address: self.address,
            starknet: .sepolia,
            starknetAccountType: .oz
        )
    }

    @Test
    func happyPath() async {
        let store = TestStore(initialState: makeState()) {
            AccountDeploy()
        } withDependencies: {
            $0.starknetRPCService.waitForTransaction = { _, _ in await Self.mockSuccessReceipt }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.phase = .checkBalance
            $0.errorMessage = nil
        }
        await store.send(.checkBalanceResponse(.success(BigUInt(1)))) {
            $0.balance = BigUInt(1)
            $0.phase = .estimating
        }
        await store.send(.estimateFeeResponse(.success(Self.mockFee))) {
            $0.estimatedFee = Self.mockFee
            $0.phase = .readyToDeploy
        }
        await store.send(.deployTapped) {
            $0.phase = .deploying
            $0.errorMessage = nil
        }
        await store.send(.deployResponse(.success("0xabc"))) {
            $0.phase = .pending("0xabc")
        }
        await store.send(.pollStatusResponse(.success(true))) {
            $0.phase = .success
            $0.errorMessage = nil
        }
    }

    @Test
    func insufficientFundsThenRetry() async {
        let store = TestStore(initialState: makeState()) {
            AccountDeploy()
        } withDependencies: {
            $0.starknetRPCService.getBalance = { _, _, _ in BigUInt(0) }
        }
        // store.exhaustivity = .off(showSkippedAssertions: true)

        await store.send(.onAppear)
        await store.receive(\.checkBalanceResponse.success) {
            $0.balance = .zero
            $0.phase = .insufficientFunds
        }

        await store.send(.retryTapped) {
            $0.phase = .checkBalance
            $0.estimatedFee = nil
            $0.balance = nil
            $0.errorMessage = nil
        }
        
        await store.receive(\.onAppear)
        await store.receive(\.checkBalanceResponse.success) {
            $0.balance = .zero
            $0.phase = .insufficientFunds
        }
    }

    @Test
    func estimateFeeFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "estimate failed" }
        }

        let store = TestStore(initialState: makeState(phase: .estimating)) {
            AccountDeploy()
        }

        await store.send(.estimateFeeResponse(.failure(FakeError()))) {
            $0.phase = .failure
            $0.errorMessage = "estimate failed"
        }
    }

    @Test
    func deployFailureThenRetry() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "deploy failed" }
        }

        let store = TestStore(initialState: makeState(phase: .deploying)) {
            AccountDeploy()
        }
        store.exhaustivity = .off

        await store.send(.deployResponse(.failure(FakeError()))) {
            $0.phase = .failure
            $0.errorMessage = "deploy failed"
        }
        await store.send(.retryTapped) {
            $0.phase = .checkBalance
            $0.estimatedFee = nil
            $0.balance = nil
            $0.errorMessage = nil
        }
        await store.receive(\.onAppear)
    }

    @Test
    func pollStatusFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "tx reverted" }
        }

        let store = TestStore(initialState: makeState(phase: .pending("0xabc"))) {
            AccountDeploy()
        }

        await store.send(.pollStatusResponse(.failure(FakeError()))) {
            $0.phase = .failure
            $0.errorMessage = "tx reverted"
        }
    }
}

