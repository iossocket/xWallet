//
//  LockTimeout.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/4/26.
//

import Foundation

enum LockTimeout: Int, CaseIterable, Equatable, Codable, Sendable {
    case immediate = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var displayName: String {
        switch self {
        case .immediate: "now"
        case .oneMinute: "1 min"
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        }
    }
}
