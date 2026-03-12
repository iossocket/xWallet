//
//  EvictorTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 12/3/26.
//

import XCTest

@testable import xWallet

class EvictorTests: XCTestCase {

    private func fetchPage<P: Paginator>(
        from paginator: P,
        key: String?,
        pageSize: Int
    ) async throws -> PaginatorPage<P.Item> {
        try await withCheckedThrowingContinuation { continuation in
            _ = paginator.fetch(key: key, pageSize: pageSize) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - LRU

    func testLRUEvictsLeastRecentlyAccessed() async throws {
        let dataSource = MockDataSource()
        let cache = PaginatorInMemoryCache<MockItem>()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: cache,
            evictor: LRUEvictor(),
            maxCount: 2
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await fetchPage(from: paginator, key: "1", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)

        // Access "0" to make it more recent than "1"
        _ = try await fetchPage(from: paginator, key: "0", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)

        // Insert "2" — should evict "1" (least recently accessed)
        _ = try await fetchPage(from: paginator, key: "2", pageSize: 1)

        let val0 = await cache.value(for: "0")
        let val1 = await cache.value(for: "1")
        let val2 = await cache.value(for: "2")

        XCTAssertNotNil(val0)
        XCTAssertNil(val1)
        XCTAssertNotNil(val2)
    }

    // MARK: - FIFO

    func testFIFOEvictsOldestInserted() async throws {
        let dataSource = MockDataSource()
        let cache = PaginatorInMemoryCache<MockItem>()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: cache,
            evictor: FIFOEvictor(),
            maxCount: 2
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await fetchPage(from: paginator, key: "1", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)

        // Insert "2" — should evict "0" (oldest inserted)
        _ = try await fetchPage(from: paginator, key: "2", pageSize: 1)

        let val0 = await cache.value(for: "0")
        let val1 = await cache.value(for: "1")
        let val2 = await cache.value(for: "2")

        XCTAssertNil(val0)
        XCTAssertNotNil(val1)
        XCTAssertNotNil(val2)
    }

    // MARK: - TTL

    func testTTLEvictsExpiredEntries() async throws {
        let dataSource = MockDataSource()
        let cache = PaginatorInMemoryCache<MockItem>()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: cache,
            evictor: TTLEvictor(ttl: 0.05),
            maxCount: .max
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 1)

        // Wait for TTL to expire
        try await Task.sleep(nanoseconds: 60_000_000)

        // Insert another — triggers eviction, "0" should be evicted
        _ = try await fetchPage(from: paginator, key: "1", pageSize: 1)

        let val0 = await cache.value(for: "0")
        let val1 = await cache.value(for: "1")

        XCTAssertNil(val0)
        XCTAssertNotNil(val1)
    }

    // MARK: - Eviction also clears Store

    func testEvictionAlsoClearsStore() async throws {
        let dataSource = MockDataSource()
        let store = MockStore()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache(),
            store: store,
            evictor: FIFOEvictor(),
            maxCount: 2
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await fetchPage(from: paginator, key: "1", pageSize: 1)
        try await Task.sleep(nanoseconds: 10_000_000)

        // Insert "2" — should evict "0" from both cache and store
        _ = try await fetchPage(from: paginator, key: "2", pageSize: 1)

        let storeLoaded = await store.load(key: "0")
        XCTAssertNil(storeLoaded)
    }

    // MARK: - No Evictor

    func testNoEvictorKeepsAllEntries() async throws {
        let dataSource = MockDataSource()
        let cache = PaginatorInMemoryCache<MockItem>()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: cache
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 1)
        _ = try await fetchPage(from: paginator, key: "1", pageSize: 1)
        _ = try await fetchPage(from: paginator, key: "2", pageSize: 1)

        let val0 = await cache.value(for: "0")
        let val1 = await cache.value(for: "1")
        let val2 = await cache.value(for: "2")

        XCTAssertNotNil(val0)
        XCTAssertNotNil(val1)
        XCTAssertNotNil(val2)
    }
}
