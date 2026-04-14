//
//  XWDebugOverlay.swift
//  xWallet
//
//  Created by Xueliang Zhu on 20/3/26.
//

#if DEBUG

import SwiftUI
import UIKit

final class XWDebugOverlay {
    static let shared = XWDebugOverlay()

    private let dragMargin: CGFloat = 12
    private var window: UIWindow?
    private var isVisible = false

    func toggle() {
        isVisible ? hide() : show()
    }

    private func show() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        XWFPSMonitor.shared().startMonitoring()
        XWMainThreadStallDetector.shared().startMonitoring()

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true

        let hostingVC = UIHostingController(rootView: DebugOverlayView())
        hostingVC.view.backgroundColor = .clear
        window.rootViewController = hostingVC
        window.frame = CGRect(x: 16, y: 60, width: 320, height: 280)
        window.frame = constrainedFrame(for: window.frame, in: window)
        window.isHidden = false

        self.window = window
        isVisible = true
    }

    private func hide() {
        XWFPSMonitor.shared().stopMonitoring()
        XWMainThreadStallDetector.shared().stopMonitoring()
        window?.isHidden = true
        window = nil
        isVisible = false
    }

    func move(by delta: CGSize) {
        guard let window else { return }
        var frame = window.frame
        frame.origin.x += delta.width
        frame.origin.y += delta.height
        window.frame = constrainedFrame(for: frame, in: window)
    }

    func clampToBounds() {
        guard let window else { return }
        window.frame = constrainedFrame(for: window.frame, in: window)
    }

    private func constrainedFrame(for frame: CGRect, in window: UIWindow) -> CGRect {
        let bounds = window.windowScene?.screen.bounds ?? UIScreen.main.bounds
        let insets = window.safeAreaInsets
        let minX = insets.left + dragMargin
        let minY = insets.top + dragMargin
        let maxX = max(minX, bounds.width - frame.width - insets.right - dragMargin)
        let maxY = max(minY, bounds.height - frame.height - insets.bottom - dragMargin)

        var constrained = frame
        constrained.origin.x = min(max(constrained.origin.x, minX), maxX)
        constrained.origin.y = min(max(constrained.origin.y, minY), maxY)
        return constrained
    }
}

private struct DebugOverlayView: View {
    @State private var selectedTab = 0
    @State private var headerDragTranslation: CGSize = .zero
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var fps: Double = 0
    @State private var dropRate: Double = 0
    @State private var stallCount: Int = 0
    @State private var avgStallMs: Double = 0
    @State private var appMemoryMB: Double = 0
    @State private var recentStalls: [[String: Any]] = []
    @State private var networkLogs: [XWNetworkLog] = []
    @State private var networkSummary = XWNetworkSummary(
        requestCount: 0,
        errorCount: 0,
        slowCount: 0,
        averageDurationMs: 0
    )

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("xWallet Debug")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Button("X") { XWDebugOverlay.shared.toggle() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let delta = CGSize(
                            width: value.translation.width - headerDragTranslation.width,
                            height: value.translation.height - headerDragTranslation.height
                        )
                        XWDebugOverlay.shared.move(by: delta)
                        headerDragTranslation = value.translation
                    }
                    .onEnded { _ in
                        headerDragTranslation = .zero
                        XWDebugOverlay.shared.clampToBounds()
                    }
            )

            Picker("", selection: $selectedTab) {
                Text("FPS").tag(0)
                Text("Net").tag(1)
                Text("Perf").tag(2)
                Text("Storqage").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)

            ScrollView {
                switch selectedTab {
                case 0: fpsTab
                case 1: networkTab
                case 2: perfTab
                case 3: storageTab
                default: EmptyView()
                }
            }
            .padding(8)
        }
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .onReceive(timer) { _ in
            fps = PerformanceTracker.shared.currentFPS
            dropRate = PerformanceTracker.shared.droppedFrameRate
            stallCount = PerformanceTracker.shared.stallCount
            avgStallMs = PerformanceTracker.shared.averageStallDuration
            recentStalls = PerformanceTracker.shared.recentStalls

            PerformanceTracker.shared.sampleMemory()
            if let latest = PerformanceTracker.shared.latestMemorySnapshot {
                appMemoryMB = latest.appMemoryMB
            }

            networkLogs = Array(XWNetworkMonitor.shared.recentLogs.suffix(10))
            networkSummary = XWNetworkMonitor.shared.recentSummary
        }
    }

    private var fpsTab: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("FPS:").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                Text(String(format: "%.1f", fps))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(fps >= 55 ? .green : .red)
            }
            HStack {
                Text("Drop Rate:").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                Text(String(format: "%.2f%%", dropRate * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(dropRate < 0.01 ? .green : .yellow)
            }
            HStack {
                Text("Stalls:").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                Text("\(stallCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(stallCount == 0 ? .green : .red)
            }
            HStack {
                Text("Avg Stall:").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                Text(String(format: "%.1fms", avgStallMs))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(avgStallMs < 100 ? .yellow : .red)
            }
        }
    }

    private var networkTab: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("30s Req:").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                Text("\(networkSummary.requestCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Spacer()
                Text("Err:").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                Text("\(networkSummary.errorCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(networkSummary.errorCount == 0 ? .green : .red)
            }

            HStack {
                Text("Slow:").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                Text("\(networkSummary.slowCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(networkSummary.slowCount == 0 ? .green : .yellow)
                Spacer()
                Text("Avg:").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                Text(String(format: "%.0fms", networkSummary.averageDurationMs))
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
            }

            Divider().background(Color.gray.opacity(0.3)).padding(.vertical, 2)

            ForEach(networkLogs) { log in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(log.method)
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.cyan)
                        Text(log.target)
                            .lineLimit(1)
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.white)
                    }
                    HStack(spacing: 4) {
                        Text(String(format: "%.0fms", log.durationMs))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(log.isSlow ? .yellow : .white)
                        if let statusCode = log.statusCode {
                            Text("\(statusCode)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(statusCode < 400 ? .green : .red)
                        }
                        if let responseBytes = log.responseBytes {
                            Text("\(responseBytes)B")
                                .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                        }
                        if log.warning != nil {
                            Text("!!").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
                        }
                    }
                    if let errorMessage = log.errorMessage {
                        Text(errorMessage)
                            .lineLimit(1)
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.red)
                    }
                }
            }
            if networkLogs.isEmpty {
                Text("No requests yet").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            }
        }
    }

    private var perfTab: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Memory").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.cyan)
            HStack {
                Text("App:").font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                Text(String(format: "%.1f MB", appMemoryMB))
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white)
            }

            Divider().background(Color.gray.opacity(0.3)).padding(.vertical, 4)

            Text("Main Thread Stalls").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.cyan)
            if recentStalls.isEmpty {
                Text("No stalls detected").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            } else {
                let slice = Array(recentStalls.suffix(5))
                ForEach(slice.indices, id: \.self) { i in
                    let stall = slice[i]
                    HStack(spacing: 4) {
                        Text(stall["activity"] as? String ?? "")
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.yellow)
                        Text(String(format: "%.0fms", stall["duration_ms"] as? Double ?? 0))
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var storageTab: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clear all storage includes wallet identity & keychain data").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.cyan)
            Button("Delete") {
                Task {
                    let ds = WalletDataSource(dbQueue: DatabaseService.dbQueue, securityStore: KeychainService())
                    try ds.truncate()
                }
            }
        }
    }
}

#endif
