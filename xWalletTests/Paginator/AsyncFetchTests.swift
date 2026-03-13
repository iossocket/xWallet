//
//  AsyncFetchTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

import XCTest

@testable import xWallet

class AsyncFetchTests: XCTestCase {

    func testAsyncFetchReturnsPage() async throws {
        let paginator = CallbackPaginator(
            dataSource: MockDataSource(),
            validator: ImmediateValidator<MockItem>(),
            cache: PaginatorInMemoryCache()
        )

        let page = try await paginator.fetch(key: nil, pageSize: 3)

        XCTAssertEqual(page.content.count, 3)
        XCTAssertEqual(page.content[0], MockItem(id: 0, title: "Item 0"))
    }

    func testAsyncFetchThrowsOnValidationFailure() async {
        let paginator = CallbackPaginator(
            dataSource: MockDataSource(),
            validator: AlwaysInvalidValidator<MockItem>(),
            cache: PaginatorInMemoryCache()
        )

        do {
            _ = try await paginator.fetch(key: nil, pageSize: 3)
            XCTFail("Expected error")
        } catch let error as PaginatorError {
            XCTAssertEqual(error, .validationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
