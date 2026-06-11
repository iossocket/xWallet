//
//  NewsRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 16/3/26.
//

import Foundation

@MainActor
protocol NewsRepositoryDelegate: AnyObject {
    func newsRepository(_ repository: NewsRepository, didChangeState state: FeedListState)
    func newsRepository(_ repository: NewsRepository, didReplaceItems items: [NewsItem])
    func newsRepository(_ repository: NewsRepository, didAppendItems newItems: [NewsItem])
}

enum FeedListState: Equatable {
    case idle
    case loading
    case empty
    case error(PaginatorError)
    case content
}

@MainActor
final class NewsRepository {
    weak var delegate: NewsRepositoryDelegate?
    private(set) var items: [NewsItem] = []
    private(set) var state: FeedListState = .idle
    private(set) var hasMore = true

    private let paginator: any Paginator<NewsItem>
    private var nextKey: String?

    init(paginator: any Paginator<NewsItem> = NewsPaginatorFactory.make(httpClient: AppHTTPClient.sslLive)) {
        self.paginator = paginator
    }

    func loadFirstPage() async {
        guard items.isEmpty else { return }
        state = .loading
        notifyStateChange()
        await fetchPage(key: nil, append: false)
    }

    func refresh() async {
        state = .loading
        notifyStateChange()
        await paginator.clear(key: nil)
        await fetchPage(key: nil, append: false)
    }

    func loadMore() async {
        guard hasMore, state != .loading, let key = nextKey else { return }
        state = .loading
        notifyStateChange()
        await fetchPage(key: key, append: true)
    }

    func clearCache() async {
        await paginator.clearAll()
    }

    // MARK: - Private

    private func fetchPage(key: String?, append: Bool) async {
        var appendedItems: [NewsItem]?
        var itemsReplaced = false
        do {
            let page = try await paginator.fetch(key: key, pageSize: 20)
            if append {
                items.append(contentsOf: page.content)
                appendedItems = page.content
            } else {
                items = page.content
                itemsReplaced = true
            }
            nextKey = page.nextKey
            hasMore = page.nextKey != nil
            state = items.isEmpty ? .empty : .content
        } catch let err as PaginatorError where err == .cancelled {
            // Another fetch is already in progress — keep prior state
        } catch let err as PaginatorError {
            state = .error(err)
        } catch {
            state = .error(.unknown(error.localizedDescription))
        }
        notifyStateChange()
        if let newItems = appendedItems {
            delegate?.newsRepository(self, didAppendItems: newItems)
        } else if itemsReplaced {
            delegate?.newsRepository(self, didReplaceItems: items)
        }
    }

    private func notifyStateChange() {
        delegate?.newsRepository(self, didChangeState: state)
    }
}
