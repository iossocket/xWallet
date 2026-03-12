//
//  CacheEntryMetaTracker.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import Foundation

actor DataManager {
    private var cache: [String: Data] = [:]

    func save(_ data: Data, forKey key: String) {
        cache[key] = data
    }

    func load(forKey key: String, completion: @escaping (Data?) -> Void) async {
        let data = cache[key]
        await MainActor.run {
            completion(data)
        }
    }
}

/// Tracks metadata for cache entries. Used by CallbackPaginator to feed evictors.
actor CacheEntryMetaTracker {
    private var entries: [String: CacheEntryMeta] = [:]

    func recordAccess(for key: String?) {
        let k = key ?? ""
        if entries[k] != nil {
            entries[k]?.lastAccessedAt = Date()
        }
    }

    func recordInsert(for key: String?) {
        let k = key ?? ""
        if entries[k] == nil {
            entries[k] = CacheEntryMeta(key: key)
        }
    }

    func remove(for key: String?) {
        entries.removeValue(forKey: key ?? "")
    }

    func removeAll() {
        entries.removeAll()
    }

    func allEntries() -> [CacheEntryMeta] {
        Array(entries.values)
    }
}
