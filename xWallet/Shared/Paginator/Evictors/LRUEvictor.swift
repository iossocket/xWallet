//
//  LRUEvictor.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

/// Evicts the least recently accessed entries when count exceeds maxCount.
public struct LRUEvictor: PaginatorEvictor {
    public init() {}

    public func keysToEvict(entries: [CacheEntryMeta], maxCount: Int) -> [String?] {
        guard entries.count > maxCount else { return [] }
        let evictCount = entries.count - maxCount
        return entries
            .sorted { $0.lastAccessedAt < $1.lastAccessedAt }
            .prefix(evictCount)
            .map(\.key)
    }
}
