//
//  FileBasedStoreTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/3/26.
//

import XCTest

@testable import xWallet

class FileBasedStoreTests: XCTestCase {

    private func makeStore() throws -> FileBasedStore<MockItem> {
        try FileBasedStore(namespace: "test-\(UUID().uuidString)")
    }

    func testSaveAndLoad() async throws {
        let store = try makeStore()
        let page = PaginatorPage(
            content: [MockItem(id: 1, title: "A")],
            key: "0",
            expirationTime: Date().addingTimeInterval(60)
        )

        try await store.save(key: "0", page: page)
        let loaded = await store.load(key: "0")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.content, [MockItem(id: 1, title: "A")])
        XCTAssertEqual(loaded?.key, "0")
    }

    func testLoadReturnsNilForMissingKey() async throws {
        let store = try makeStore()
        let loaded = await store.load(key: "missing")
        XCTAssertNil(loaded)
    }

    func testRemoveDeletesPage() async throws {
        let store = try makeStore()
        let page = PaginatorPage(
            content: [MockItem(id: 1, title: "A")],
            key: "0"
        )

        try await store.save(key: "0", page: page)
        await store.remove(key: "0")
        let loaded = await store.load(key: "0")

        XCTAssertNil(loaded)
    }

    func testRemoveAllClearsEverything() async throws {
        let store = try makeStore()

        try await store.save(key: "0", page: PaginatorPage(content: [MockItem(id: 1, title: "A")]))
        try await store.save(key: "1", page: PaginatorPage(content: [MockItem(id: 2, title: "B")]))

        await store.removeAll()

        let loaded0 = await store.load(key: "0")
        let loaded1 = await store.load(key: "1")
        XCTAssertNil(loaded0)
        XCTAssertNil(loaded1)
    }

    func testNilKeyUsesInitialFile() async throws {
        let store = try makeStore()
        let page = PaginatorPage(content: [MockItem(id: 0, title: "Initial")])

        try await store.save(key: nil, page: page)
        let loaded = await store.load(key: nil)

        XCTAssertEqual(loaded?.content, [MockItem(id: 0, title: "Initial")])
    }
}
