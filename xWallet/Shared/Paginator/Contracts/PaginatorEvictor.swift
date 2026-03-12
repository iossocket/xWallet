//
//  PaginatorEvictor.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import Foundation

/// Metadata tracked per cache entry, used by evictors to make decisions.
public struct CacheEntryMeta: Sendable {
    public let key: String?
    public let insertedAt: Date
    public var lastAccessedAt: Date

    public init(key: String?, insertedAt: Date = Date(), lastAccessedAt: Date = Date()) {
        self.key = key
        self.insertedAt = insertedAt
        self.lastAccessedAt = lastAccessedAt
    }
}

/// Decides which cache entries to evict when capacity is exceeded.
public protocol PaginatorEvictor: Sendable {
    /// Given current entries metadata and the max capacity,
    /// return the keys that should be evicted.
    func keysToEvict(entries: [CacheEntryMeta], maxCount: Int) -> [String?]
}
