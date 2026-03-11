//
//  CallbackPaginatorTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/3/26.
//

import XCTest

@testable import xWallet

class CallbackPaginatorTests: XCTestCase {
    
    func testFetchReturnsPageFromDataSource() async throws {
        let dataSource = MockDataSource()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache()
        )

        let page = try await fetchPage(from: paginator, key: nil, pageSize: 3)

        XCTAssertEqual(page.content.count, 3)
        XCTAssertEqual(page.content[0], MockItem(id: 0, title: "Item 0"))
        XCTAssertEqual(dataSource.fetchCallCount, 1)
    }

    func testFetchSameKeyHitsMemoryCache() async throws {
        let dataSource = MockDataSource()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache()
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)
        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)

        XCTAssertEqual(dataSource.fetchCallCount, 1)
    }
    
    func testClearRemovesCacheAndRefetches() async throws {
        let dataSource = MockDataSource()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache()
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)
        await paginator.clear(key: "0")
        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)

        XCTAssertEqual(dataSource.fetchCallCount, 2)
    }

    func testFetchReturnsValidationFailedWhenValidatorRejectsPage() async {
        let dataSource = MockDataSource()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: AlwaysInvalidValidator<MockItem>(),
            cache: PaginatorInMemoryCache()
        )

        do {
            _ = try await fetchPage(from: paginator, key: nil, pageSize: 3)
            XCTFail("Expected validation failure")
        } catch let error as PaginatorError {
            XCTAssertEqual(error, .validationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Store Tests

    func testFetchHitsStoreWhenCacheMisses() async throws {
        let dataSource = MockDataSource()
        let store = MockStore()

        // Pre-populate store
        let storedPage = PaginatorPage(
            content: [MockItem(id: 99, title: "Stored")],
            key: "0",
            expirationTime: Date().addingTimeInterval(60)
        )
        await store.save(key: "0", page: storedPage)

        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache(),
            store: store
        )

        let page = try await fetchPage(from: paginator, key: "0", pageSize: 3)

        XCTAssertEqual(page.content, [MockItem(id: 99, title: "Stored")])
        XCTAssertEqual(dataSource.fetchCallCount, 0)
    }

    func testFetchFallsToDataSourceWhenStoreMisses() async throws {
        let dataSource = MockDataSource()
        let store = MockStore()

        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache(),
            store: store
        )

        let page = try await fetchPage(from: paginator, key: "0", pageSize: 3)

        XCTAssertEqual(page.content.count, 3)
        XCTAssertEqual(dataSource.fetchCallCount, 1)
        // DataSource result should be written back to store
        let saveCount = await store.saveCallCount
        XCTAssertEqual(saveCount, 1)
    }

    func testClearRemovesBothCacheAndStore() async throws {
        let dataSource = MockDataSource()
        let store = MockStore()

        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache(),
            store: store
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)
        await paginator.clear(key: "0")

        // Store should have no data for this key after clear
        let loaded = await store.load(key: "0")
        XCTAssertNil(loaded)
    }
}

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
