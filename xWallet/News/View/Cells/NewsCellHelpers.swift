//
//  NewsCellHelpers.swift
//  xWallet
//
//  Created by Xueliang Zhu on 16/3/26.
//

import Foundation

/// Formats "Source · Xh ago" metadata string for news cells.
func formatMeta(source: String, date: Date?) -> String {
    guard let date else { return source }
    let elapsed = Date().timeIntervalSince(date)
    let relative: String
    switch elapsed {
    case ..<60:
        relative = "just now"
    case ..<3600:
        relative = "\(Int(elapsed / 60))m ago"
    case ..<86400:
        relative = "\(Int(elapsed / 3600))h ago"
    case ..<604800:
        relative = "\(Int(elapsed / 86400))d ago"
    default:
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        relative = formatter.string(from: date)
    }
    return "\(source) · \(relative)"
}
