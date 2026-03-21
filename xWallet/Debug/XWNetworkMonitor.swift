//
//  XWNetworkMonitor.swift
//  xWallet
//
//  Created by Xueliang Zhu on 21/3/26.
//

#if DEBUG

import Foundation

struct XWNetworkLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let target: String
    let host: String
    let path: String
    let statusCode: Int?
    let durationMs: Double
    let responseBytes: Int?
    let warning: String?
    let errorMessage: String?

    var isError: Bool {
        errorMessage != nil || (statusCode.map { $0 >= 400 } ?? false)
    }

    var isSlow: Bool {
        durationMs >= 800
    }
}

struct XWNetworkSummary {
    let requestCount: Int
    let errorCount: Int
    let slowCount: Int
    let averageDurationMs: Double
}

final class XWNetworkMonitor {
    static let shared = XWNetworkMonitor()

    private let queue = DispatchQueue(label: "com.xwallet.network-monitor")
    private let maxLogs = 200
    private var logs: [XWNetworkLog] = []

    private init() {}

    func record(
        request: URLRequest,
        response: URLResponse?,
        responseBytes: Int?,
        error: Error?,
        durationMs: Double
    ) {
        let url = request.url
        let host = url?.host ?? "unknown"
        let path = url?.path.isEmpty == false ? (url?.path ?? "") : "/"
        let target = host + path
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let scheme = url?.scheme?.lowercased()
        let warning = scheme == "https" ? nil : "non-https"

        let log = XWNetworkLog(
            timestamp: Date(),
            method: request.httpMethod ?? "GET",
            target: target,
            host: host,
            path: path,
            statusCode: statusCode,
            durationMs: durationMs,
            responseBytes: responseBytes,
            warning: warning,
            errorMessage: error?.localizedDescription
        )

        queue.async {
            self.logs.append(log)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
        }
    }

    var recentLogs: [XWNetworkLog] {
        queue.sync { logs }
    }

    var recentSummary: XWNetworkSummary {
        queue.sync {
            let cutoff = Date().addingTimeInterval(-30)
            let recent = logs.filter { $0.timestamp >= cutoff }
            let totalDuration = recent.reduce(0) { $0 + $1.durationMs }
            return XWNetworkSummary(
                requestCount: recent.count,
                errorCount: recent.filter(\.isError).count,
                slowCount: recent.filter(\.isSlow).count,
                averageDurationMs: recent.isEmpty ? 0 : totalDuration / Double(recent.count)
            )
        }
    }
}

#endif
