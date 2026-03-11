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
            validator: ImmediateValidator<MockItem>()
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
            validator: ImmediateValidator<MockItem>()
        )

        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)
        _ = try await fetchPage(from: paginator, key: "0", pageSize: 3)

        XCTAssertEqual(dataSource.fetchCallCount, 1)
    }
    
    func testClearRemovesCacheAndRefetches() async throws {
        let dataSource = MockDataSource()
        let paginator = CallbackPaginator(
            dataSource: dataSource,
            validator: ImmediateValidator<MockItem>()
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
            validator: AlwaysInvalidValidator<MockItem>()
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
