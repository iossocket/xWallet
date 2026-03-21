//
//  PerformanceTracker.swift
//  xWallet
//
//  Created by Xueliang Zhu on 20/3/26.
//

#if DEBUG

import Foundation

final class PerformanceTracker {
    static let shared = PerformanceTracker()

    struct MemorySnapshot {
        let timestamp: Date
        let appMemoryMB: Double
    }

    private(set) var latestMemorySnapshot: MemorySnapshot?

    func sampleMemory() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let appMB = result == KERN_SUCCESS
            ? Double(info.resident_size) / (1024 * 1024)
            : 0

        latestMemorySnapshot = MemorySnapshot(
            timestamp: Date(),
            appMemoryMB: appMB
        )
    }

    var currentFPS: Double {
        XWFPSMonitor.shared().currentFPS
    }

    var droppedFrameRate: Double {
        XWFPSMonitor.shared().droppedFrameRate()
    }

    // MARK: - Main Thread Stall Detection

    var stallCount: Int {
        Int(XWMainThreadStallDetector.shared().stallCount)
    }

    var recentStalls: [[String: Any]] {
        XWMainThreadStallDetector.shared().recentStalls as? [[String: Any]] ?? []
    }

    /// Average stall duration (ms) over recent records.
    var averageStallDuration: Double {
        let stalls = recentStalls
        guard !stalls.isEmpty else { return 0 }
        let total = stalls.compactMap { $0["duration_ms"] as? Double }.reduce(0, +)
        return total / Double(stalls.count)
    }
}

#endif
