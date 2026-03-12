//
//  TTLEvictor.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import Foundation

/// Evicts entries whose insertion time exceeds the given TTL.
public struct TTLEvictor: PaginatorEvictor {
    private let ttl: TimeInterval

    public init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    public func keysToEvict(entries: [CacheEntryMeta], maxCount: Int) -> [String?] {
        let now = Date()
        return entries
            .filter { now.timeIntervalSince($0.insertedAt) > ttl }
            .map(\.key)
    }
}
