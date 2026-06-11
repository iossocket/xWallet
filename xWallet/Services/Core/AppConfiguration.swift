//
//  AppConfiguration.swift
//  xWallet
//
//  Created by Xueliang Zhu on 15/4/26.
//

import Nuke
import ReownWalletKit
import WalletConnectRelay
import WalletConnectNetworking
import WalletConnectSigner
import EthereumKit
import TrustKit

final class NativeWebSocket: NSObject, WebSocketConnecting, URLSessionWebSocketDelegate {
    var isConnected: Bool = false
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    var request: URLRequest

    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    init(request: URLRequest) {
        self.request = request
        super.init()
    }

    func connect() {
        task = session.webSocketTask(with: request)
        task?.resume()
        listen()
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    func write(string: String, completion: (() -> Void)?) {
        task?.send(.string(string)) { _ in
            completion?()
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                self?.onText?(text)
            default:
                break
            }
            self?.listen()
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        onConnect?()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        onDisconnect?(nil)
    }
}

struct NativeSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        NativeWebSocket(request: URLRequest(url: url))
    }
}

struct XWalletCryptoProvider: CryptoProvider {
    func recoverPubKey(signature: WalletConnectSigner.EthereumSignature, message: Data) throws -> Data {
        let sigData = Data(signature.r + signature.s + [signature.v])
        return try Secp256k1.recoverPublicKey(message: message, signature: sigData)
    }

    func keccak256(_ data: Data) -> Data {
        Keccak256.hash(data)
    }
}

enum AppConfiguration {
    static func setup() {
        let pipeline = ImagePipeline {
            $0.imageCache = ImageCache(costLimit: 100 * 1024 * 1024) // 100MB memory
            if let dataCache = try? DataCache(name: "com.xwallet.images") {
                dataCache.sizeLimit = 300 * 1024 * 1024 // 300MB disk
                $0.dataCache = dataCache
            }
            $0.isDecompressionEnabled = true
        }
        ImagePipeline.shared = pipeline
        
        Networking.configure(
            groupIdentifier: "group.com.iossocket",
            projectId: Bundle.main.infoDictionary!["WC_PROJECT_ID"] as! String,
            socketFactory: NativeSocketFactory()
        )

        do {
            let metadata = AppMetadata(
                name: "xWallet",
                description: "Multi-chain crypto wallet",
                url: "",
                icons: [],
                redirect: try AppMetadata.Redirect(native: "xwallet://", universal: nil)
            )
            WalletKit.configure(metadata: metadata, crypto: XWalletCryptoProvider())
        } catch {
            print("Failed to configure WalletKit: \(error)")
        }
        
        TrustKit.setLoggerBlock { msg in
            print("[TrustKit] \(msg)")
        }
        
        let config: [String: Any] = [
            kTSKSwizzleNetworkDelegates: false,
            kTSKPinnedDomains: [
                "xwallet-news.avx302.workers.dev": [
                    kTSKEnforcePinning: true,
                    kTSKIncludeSubdomains: false,
                    kTSKPublicKeyHashes: [
                        "y7xVm0TVJNahMr2sZydE2jQH8SquXV9yLF9seROHHHU=",  // Let's Encrypt E7
                        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",  // fake backup
                    ],
                    kTSKDisableDefaultReportUri: true,
                ]
            ]
        ]
        
        TrustKit.initSharedInstance(withConfiguration: config)
    }
}
