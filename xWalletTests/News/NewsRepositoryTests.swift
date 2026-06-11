//
//  NewsRepositoryTests.swift
//  xWallet
//
//  Created by Xueliang Zhu on 27/4/26.
//

import XCTest
import Testing
import os
@testable import xWallet

class MockViewController: NewsRepositoryDelegate {
    var repository: NewsRepository?
    var state: FeedListState?
    var items: [NewsItem] = []

    init(repository: NewsRepository? = nil, state: FeedListState? = nil, items: [NewsItem] = []) {
        self.repository = repository
        self.state = state
        self.items = items
    }

    func newsRepository(_ repository: NewsRepository, didChangeState state: FeedListState) {
        self.repository = repository
        self.state = state
    }

    func newsRepository(_ repository: NewsRepository, didReplaceItems items: [NewsItem]) {
        self.repository = repository
        self.items = items
    }

    func newsRepository(_ repository: NewsRepository, didAppendItems newItems: [NewsItem]) {
        self.repository = repository
        items.append(contentsOf: newItems)
    }
}

final class MockNewsHTTPClient: HTTPServiceProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return (Data(), URLResponse())
    }
}

final class MockPaginatorExecution: PaginatorExecution {
    private let counter = OSAllocatedUnfairLock<Int>(initialState: 0)

    var cancelCallCount: Int {
        counter.withLock { $0 }
    }

    func cancel() {
        counter.withLock { $0 += 1 }
    }
}

struct FetchCall: Sendable, Equatable {
    let key: String?
    let pageSize: Int
}

final class MockPaginator: Paginator {
    typealias Item = NewsItem

    private struct State {
        var stubs: [String?: Result<PaginatorPage<NewsItem>, PaginatorError>] = [:]
        var fetchCalls: [FetchCall] = []
        var clearKeys: [String?] = []
        var clearAllCallCount = 0
        var lastExecution: MockPaginatorExecution?
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    var fetchCalls: [FetchCall] {
        state.withLock { $0.fetchCalls }
    }

    var clearKeys: [String?] {
        state.withLock { $0.clearKeys }
    }

    var clearAllCallCount: Int {
        state.withLock { $0.clearAllCallCount }
    }

    var lastExecution: MockPaginatorExecution? {
        state.withLock { $0.lastExecution }
    }

    func stub(key: String?, page: PaginatorPage<NewsItem>) {
        state.withLock { $0.stubs[key] = .success(page) }
    }

    func stub(key: String?, error: PaginatorError) {
        state.withLock { $0.stubs[key] = .failure(error) }
    }

    func fetch(
        key: String?,
        pageSize: Int,
        listener: @escaping @Sendable (Result<PaginatorPage<NewsItem>, PaginatorError>) -> Void
    ) -> any PaginatorExecution {
        let (result, execution) = state.withLock { state -> (Result<PaginatorPage<NewsItem>, PaginatorError>, MockPaginatorExecution) in
            state.fetchCalls.append(FetchCall(key: key, pageSize: pageSize))
            let result = state.stubs[key] ?? .success(PaginatorPage(content: [], key: key))
            let execution = MockPaginatorExecution()
            state.lastExecution = execution
            return (result, execution)
        }
        listener(result)
        return execution
    }

    func clear(key: String?) async {
        state.withLock {
            $0.clearKeys.append(key)
            $0.stubs.removeValue(forKey: key)
        }
    }

    func clearAll() async {
        state.withLock {
            $0.clearAllCallCount += 1
            $0.stubs.removeAll()
        }
    }
}

@MainActor
class NewsRepositoryTests: XCTestCase {

    var vc: MockViewController!

    override func setUp() {
        super.setUp()
        vc = MockViewController()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testLoadFirstPageSuccessfully() async {
        let paginator = MockPaginator()
        let item = NewsItem(id: "1", sourceName: "X", title: "T", url: "https://x.com", summary: "", imageURL: nil, author: nil, publishedAt: Date(), tags: [])
        paginator.stub(key: nil, page: PaginatorPage(content: [item], nextKey: "p2"))

        let repository = NewsRepository(paginator: paginator)
        repository.delegate = vc
        
        await repository.loadFirstPage()
        XCTAssertEqual(repository.state, .content)
        XCTAssertEqual(repository.items, [item])
    }
    
    func testLoadFirstPageFail() async {
        let paginator = MockPaginator()
        paginator.stub(key: nil, error: PaginatorError.network("400"))
        
        let repository = NewsRepository(paginator: paginator)
        repository.delegate = vc
        
        await repository.loadFirstPage()
        XCTAssertEqual(repository.state, .error(PaginatorError.network("400")))
        XCTAssertEqual(repository.items, [])
    }
}

@MainActor
struct NewsRepositoryV2Tests {
    
    let vc: MockViewController
    
    init() {
        self.vc = MockViewController()
    }
    
    @Test
    func loadFirstPage() async {
        let paginator = MockPaginator()
        paginator.stub(key: nil, error: PaginatorError.network("400"))
        
        let repository = NewsRepository(paginator: paginator)
        repository.delegate = vc
        
        await repository.loadFirstPage()
        #expect(repository.state == .error(PaginatorError.network("400")))
        #expect(repository.items == [])
    }
}
