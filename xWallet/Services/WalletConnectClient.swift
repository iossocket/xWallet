//
//  WalletConnectClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 22/4/26.
//

import Combine
import ReownWalletKit
import MultiChainCore
import ComposableArchitecture

// MARK: - Bridging Models

struct WCSession: Equatable, Identifiable, @unchecked Sendable {
    var id: String { topic }
    let topic: String
    let peerName: String
    let peerUrl: String
    let peerIcon: String?
    let chains: [Blockchain]
    let methods: Set<String>
    let expiryDate: Date

    init(from session: Session) {
        self.topic = session.topic
        self.peerName = session.peer.name
        self.peerUrl = session.peer.url
        self.peerIcon = session.peer.icons.first
        self.chains = session.namespaces.values.flatMap { $0.chains ?? [] }
        self.methods = session.namespaces.values.reduce(into: Set<String>()) { $0.formUnion($1.methods) }
        self.expiryDate = session.expiryDate
    }

    init(topic: String, peerName: String, peerUrl: String, peerIcon: String?, chains: [Blockchain], methods: Set<String>, expiryDate: Date) {
        self.topic = topic
        self.peerName = peerName
        self.peerUrl = peerUrl
        self.peerIcon = peerIcon
        self.chains = chains
        self.methods = methods
        self.expiryDate = expiryDate
    }
}

struct WCProposal: Equatable, @unchecked Sendable {
    let proposal: Session.Proposal

    var id: String { proposal.id }
    var peerName: String { proposal.proposer.name }
    var peerUrl: String { proposal.proposer.url }
    var peerIcon: String? { proposal.proposer.icons.first }
    var requiredNamespaces: [String: ProposalNamespace] { proposal.requiredNamespaces }
    var optionalNamespaces: [String: ProposalNamespace]? { proposal.optionalNamespaces }
}

enum WCRequest: Equatable, Sendable {
    case personalSign(message: Data, address: String)
    case signTypedData(json: String, address: String)
    case sendTransaction(tx: WCTransactionData)
    case starknetSignTypedData(json: String)
    case starknetExecute(calls: [WCStarknetCall])
}

struct WCTransactionData: Equatable, Sendable, Codable {
    let from: String
    let to: String
    let value: String
    let data: String
    let gasLimit: String?
    let chainId: String?

    enum CodingKeys: String, CodingKey {
        case from, to, value, data
        case gasLimit = "gas"
        case chainId
    }
}

struct WCStarknetCall: Equatable, Sendable, Codable {
    let contractAddress: String
    let entrypoint: String
    let calldata: [String]

    enum CodingKeys: String, CodingKey {
        case contractAddress = "contract_address"
        case entrypoint = "entry_point"
        case calldata
    }
}

// MARK: - Client

struct WalletConnectClient {
    var pair: @Sendable (WalletConnectURI) async throws -> Void
    var approveSession: @Sendable (String, [String: SessionNamespace]) async throws -> WCSession
    var rejectSession: @Sendable (String, RejectionReason) async throws -> Void
    var approveRequest: @Sendable (String, RPCID, AnyCodable) async throws -> Void
    var rejectRequest: @Sendable (String, RPCID) async throws -> Void
    var disconnect: @Sendable (String) async throws -> Void
    var activeSessions: @Sendable () -> [WCSession]
    var sessionProposals: @Sendable () -> AsyncStream<WCProposal>
    var sessionRequests: @Sendable () -> AsyncStream<(WCRequest, String, RPCID, Blockchain)>
    var sessionDeleted: @Sendable () -> AsyncStream<String>
}

// MARK: - Live Implementation

extension WalletConnectClient: DependencyKey {
    static var liveValue: WalletConnectClient {
        WalletConnectClient(
            pair: { uri in
                try await WalletKit.instance.pair(uri: uri)
            },
            approveSession: { proposalId, namespaces in
                let session = try await WalletKit.instance.approve(
                    proposalId: proposalId,
                    namespaces: namespaces
                )
                return WCSession(from: session)
            },
            rejectSession: { proposalId, reason in
                try await WalletKit.instance.rejectSession(
                    proposalId: proposalId,
                    reason: reason
                )
            },
            approveRequest: { topic, requestId, result in
                try await WalletKit.instance.respond(
                    topic: topic,
                    requestId: requestId,
                    response: .response(result)
                )
            },
            rejectRequest: { topic, requestId in
                try await WalletKit.instance.respond(
                    topic: topic,
                    requestId: requestId,
                    response: .error(JSONRPCError(code: 4001, message: "User rejected the request"))
                )
            },
            disconnect: { topic in
                try await WalletKit.instance.disconnect(topic: topic)
            },
            activeSessions: {
                WalletKit.instance.getSessions().map(WCSession.init(from:))
            },
            sessionProposals: {
                AsyncStream { continuation in
                    let cancellable = WalletKit.instance.sessionProposalPublisher
                        .sink { (proposal, _) in
                            continuation.yield(WCProposal(proposal: proposal))
                        }
                    continuation.onTermination = { _ in
                        cancellable.cancel()
                    }
                }
            },
            sessionRequests: {
                AsyncStream { continuation in
                    let cancellable = WalletKit.instance.sessionRequestPublisher
                        .sink { (request, _) in
                            guard let wcRequest = WCRequest.parse(request) else { return }
                            continuation.yield((wcRequest, request.topic, request.id, request.chainId))
                        }
                    continuation.onTermination = { _ in
                        cancellable.cancel()
                    }
                }
            },
            sessionDeleted: {
                AsyncStream { continuation in
                    let cancellable = WalletKit.instance.sessionDeletePublisher
                        .sink { (topic, _) in
                            continuation.yield(topic)
                        }
                    continuation.onTermination = { _ in
                        cancellable.cancel()
                    }
                }
            }
        )
    }

    static var testValue: WalletConnectClient {
        WalletConnectClient(
            pair: { _ in },
            approveSession: { _, _ in
                WCSession(
                    topic: "", peerName: "", peerUrl: "",
                    peerIcon: nil, chains: [], methods: [],
                    expiryDate: .distantFuture
                )
            },
            rejectSession: { _, _ in },
            approveRequest: { _, _, _ in },
            rejectRequest: { _, _ in },
            disconnect: { _ in },
            activeSessions: { [] },
            sessionProposals: { AsyncStream { $0.finish() } },
            sessionRequests: { AsyncStream { $0.finish() } },
            sessionDeleted: { AsyncStream { $0.finish() } }
        )
    }
}

// MARK: - Request Parsing

private extension WCRequest {
    static func parse(_ request: Request) -> WCRequest? {
        switch request.method {
        case "personal_sign":
            guard let params = try? request.params.get([String].self),
                  params.count >= 2,
                  let messageData = Data(hexString: params[0]) else { return nil }
            return .personalSign(message: messageData, address: params[1])

        case "eth_signTypedData_v4", "eth_signTypedData":
            guard let params = try? request.params.get([String].self),
                  params.count >= 2 else { return nil }
            return .signTypedData(json: params[1], address: params[0])

        case "eth_sendTransaction":
            guard let params = try? request.params.get([WCTransactionData].self),
                  let tx = params.first else { return nil }
            return .sendTransaction(tx: tx)

        case "starknet_signTypedData":
            let json = request.params.stringRepresentation
            guard !json.isEmpty else { return nil }
            return .starknetSignTypedData(json: json)

        case "starknet_execute":
            guard let calls = try? request.params.get([WCStarknetCall].self) else { return nil }
            return .starknetExecute(calls: calls)

        default:
            return nil
        }
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    var walletConnectClient: WalletConnectClient {
        get { self[WalletConnectClient.self] }
        set { self[WalletConnectClient.self] = newValue }
    }
}
