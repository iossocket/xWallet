//
//  Paginator+Async.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

extension Paginator {
    /// Async/await wrapper over the callback-based fetch.
    public func fetch(key: String?, pageSize: Int) async throws -> PaginatorPage<Item> {
        try await withCheckedThrowingContinuation { continuation in
            _ = fetch(key: key, pageSize: pageSize) { result in
                continuation.resume(with: result)
            }
        }
    }
}
