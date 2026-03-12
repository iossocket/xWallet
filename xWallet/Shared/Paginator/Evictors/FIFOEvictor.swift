//
//  FIFOEvictor.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

/// Evicts the oldest inserted entries when count exceeds maxCount.
public struct FIFOEvictor: PaginatorEvictor {
    public init() {}

    public func keysToEvict(entries: [CacheEntryMeta], maxCount: Int) -> [String?] {
        guard entries.count > maxCount else { return [] }
        let evictCount = entries.count - maxCount
        return entries
            .sorted { $0.insertedAt < $1.insertedAt }
            .prefix(evictCount)
            .map(\.key)
    }
}
