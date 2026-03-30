//
//  SendClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 25/3/26.
//

import Foundation
import Dependencies
import EthereumKit
import MultiChainKit
import MultiChainCore
import BigInt

struct SendRequest: Equatable, Sendable {
    let chain: Chain
    let toAddress: String
    let amount: String
    let asset: AssetItem?
}

enum FeeEstimate: Equatable, Sendable {
    case evm(EthereumTransaction)
    case starknet(StarknetFeeEstimate)
}

enum TxResult: Equatable, Sendable {
    case success
    case reverted(String?)
}

enum ChainAccount: Sendable {
    case evm(EthereumAccount, EthereumProvider)
    case starknet(StarknetAccount, StarknetProvider)
}

struct SendClient {
    var validateAddress: @Sendable (String, Chain) -> Bool
    var estimateFee: @Sendable (SendRequest, ChainAccount) async throws -> FeeEstimate
    var send: @Sendable (SendRequest, ChainAccount) async throws -> String
    var waitForConfirmation: @Sendable (String, Chain) async throws -> TxResult
}

extension SendClient: DependencyKey {
    static var liveValue: SendClient {
        return SendClient(
            validateAddress: { address, chain in
                switch chain.chainType() {
                case .evm:
                    return EthereumAddress(address) != nil
                case .starknet:
                    return StarknetAddress(address) != nil
                }
            },
            estimateFee: { request, account in
                guard let asset = request.asset else {
                    throw SendError.invalidToken
                }
                switch account {
                case .evm(let account, let provider):
                    let tx = try await buildEvmTransaction(request: request, asset: asset, account: account, provider: provider)
                    return .evm(tx)
                case .starknet(let account, let provider):
                    let call = try makeStarknetTransferCall(asset: asset, toAddress: request.toAddress, amount: request.amount)
                    let nonceRequest = StarknetRequestBuilder.getNonceRequest(address: account.address, block: .latest)
                    let nonce: String = try await provider.send(request: nonceRequest)
                    let estimate = try await account.estimateFee(calls: [call], nonce: Felt(nonce)!)
                    return .starknet(estimate)
                }
            },
            send: { request, account in
                guard let asset = request.asset else {
                    throw SendError.invalidToken
                }
                switch account {
                case .evm(let account, let provider):
                    var tx = try await buildEvmTransaction(request: request, asset: asset, account: account, provider: provider)
                    try account.sign(transaction: &tx)
                    guard let raw = tx.rawTransaction else {
                        throw SendError.invalidTransaction
                    }
                    return try await provider.send(request: EthereumRequestBuilder.sendRawTransactionRequest(raw))
                case .starknet(let account, _):
                    let call = try makeStarknetTransferCall(asset: asset, toAddress: request.toAddress, amount: request.amount)
                    let response = try await account.executeV3(calls: [call])
                    return response.transactionHash
                }
            },
            waitForConfirmation: { hash, chain in
                switch chain.chainType() {
                case .evm:
                    let provider = EthereumProvider(chain: chain.toEvmChain())
                    let receipt = try await provider.waitForTransaction(hash: hash)
                    return receipt.isSuccess ? .success : .reverted(nil)
                case .starknet:
                    guard let txHash = Felt(hash) else {
                        throw SendError.invalidTransaction
                    }
                    let provider = StarknetProvider(chain: chain.toStrkChain())
                    let receipt = try await provider.waitForTransaction(hash: txHash)
                    return receipt.isSuccess ? .success : .reverted(receipt.revertReason)
                }
            }
        )
    }

    static var testValue: SendClient {
        SendClient(
            validateAddress: { _, _ in true },
            estimateFee: { _, _ in fatalError() },
            send: { _, _ in "0xdeadbeef" },
            waitForConfirmation: { _, _ in fatalError() }
        )
    }
}

extension DependencyValues {
    var sendClient: SendClient {
        get { self[SendClient.self] }
        set { self[SendClient.self] = newValue }
    }
}

// MARK: - Private Helpers

private func buildEvmTransaction(
    request: SendRequest,
    asset: AssetItem,
    account: EthereumAccount,
    provider: EthereumProvider
) async throws -> EthereumTransaction {
    guard let address = EthereumAddress(request.toAddress) else {
        throw SendError.invalidAddress
    }
    if asset.id != "ETH" {
        guard let token = ERC20TokenList.token(address: String(asset.id.split(separator: ":")[1]), chainId: String(provider.chain.chainId)) else {
            throw SendError.invalidToken
        }
        guard let tokenAmount = UnitFormatter.parse(request.amount, decimals: token.decimals) else {
            throw SendError.invalidAmount
        }
        let data = ABIValue.encodeCall(
            signature: "transfer(address,uint256)",
            arguments: [
                .address(address),
                .uint256(Wei(tokenAmount))
            ]
        )
        return try await account.prepareTransaction(
            to: EthereumAddress(token.address)!,
            value: .zero,
            data: data
        )
    } else {
        let value = Wei.fromEther(request.amount) ?? .zero
        return try await account.prepareTransaction(
            to: address,
            value: value
        )
    }
}

private func makeStarknetTransferCall(asset: AssetItem, toAddress: String, amount: String) throws -> StarknetCall {
    let tokenContract: Felt
    let parts = asset.id.split(separator: ":")
    if parts.count == 2, String(parts[1]).hasPrefix("0x") {
        guard let felt = Felt(String(parts[1])) else {
            throw SendError.invalidToken
        }
        tokenContract = felt
    } else {
        switch asset.symbol.uppercased() {
        case "STRK": tokenContract = Starknet.Token.STRK
        case "ETH":  tokenContract = Starknet.Token.ETH
        default:     throw SendError.invalidToken
        }
    }
    guard let toFelt = Felt(toAddress) else {
        throw SendError.invalidAddress
    }
    let amountWei = decimalToWei(Decimal(string: amount) ?? 0, decimals: 18)
    let low  = Felt(amountWei & ((BigUInt(1) << 128) - 1))
    let high = Felt(amountWei >> 128)
    return StarknetCall(
        contractAddress: tokenContract,
        entrypoint: "transfer",
        calldata: [toFelt, low, high]
    )
}

private func decimalToWei(_ amount: Decimal, decimals: Int) -> BigUInt {
    let multiplier = pow(Decimal(10), decimals)
    let wei = amount * multiplier
    var value = wei
    var rounded = Decimal()
    NSDecimalRound(&rounded, &value, 0, .plain)
    return BigUInt(NSDecimalNumber(decimal: rounded).stringValue) ?? .zero
}
