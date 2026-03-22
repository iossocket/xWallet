//
//  NewsRepository.swift
//  xWallet
//
//  Created by Xueliang Zhu on 16/3/26.
//

import Foundation

@MainActor
protocol NewsRepositoryDelegate: AnyObject {
    func newsRepositoryDidUpdate(_ repository: NewsRepository)
}

@MainActor
final class NewsRepository {
    weak var delegate: NewsRepositoryDelegate?
    private(set) var items: [NewsItem] = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var error: PaginatorError?
    private(set) var hasMore = true
    
    private let paginator: any Paginator<NewsItem>
    private var nextKey: String?

    init(paginator: any Paginator<NewsItem> = NewsPaginatorFactory.make()) {
        self.paginator = paginator
    }

    func loadFirstPage() async {
        guard items.isEmpty, !isLoading else { return }
        isLoading = true
        notifyDelegate()
        await fetchPage(key: nil, append: false)
    }
    
    func refresh() async {
        isRefreshing = true
        error = nil
        notifyDelegate()
        await paginator.clear(key: nil)
        await fetchPage(key: nil, append: false)
    }

    func loadMore() async {
        guard hasMore, !isLoading, let key = nextKey else { return }
        isLoading = true
        notifyDelegate()
        await fetchPage(key: key, append: true)
    }
    
    func clearCache() async {
        await paginator.clearAll()
    }
    
    // MARK: - Private

    private func fetchPage(key: String?, append: Bool) async {
        do {
            let page = try await paginator.fetch(key: key, pageSize: 20)
            if append {
                items.append(contentsOf: page.content)
            } else {
                items = page.content
            }
            nextKey = page.nextKey
            hasMore = page.nextKey != nil
            error = nil
        } catch let err as PaginatorError where err == .cancelled {
            // Another fetch is already in progress — silently ignore
        } catch let err as PaginatorError {
            error = err
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        isLoading = false
        isRefreshing = false
        notifyDelegate()
    }

    private func notifyDelegate() {
        delegate?.newsRepositoryDidUpdate(self)
    }
}
