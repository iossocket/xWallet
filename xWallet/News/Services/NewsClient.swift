//
//  NewsClient.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

import Foundation

struct NewsDataSource: PaginatorDataSource {
    typealias Item = NewsItem
    let httpClient: any HTTPClientProtocol

    init(httpClient: any HTTPClientProtocol = AppHTTPClient.live) {
        self.httpClient = httpClient
    }

    func fetchPage(key: String?, pageSize: Int) async throws -> PaginatorPage<NewsItem> {
        var components = URLComponents(string: "https://xwallet-news.avx302.workers.dev/news")!
        var queryItems = [URLQueryItem(name: "limit", value: String(pageSize))]
        if let key {
            queryItems.append(URLQueryItem(name: "cursor", value: key))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw PaginatorError.invalidKey
        }
        let (data, response) = try await httpClient.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PaginatorError.network(
                "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            )
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let apiResponse = try decoder.decode(NewsAPIResponse.self, from: data)
        
        return PaginatorPage(
            content: apiResponse.items,
            key: key,
            expirationTime: Date().addingTimeInterval(300), // 5 min TTL
            prevKey: nil,
            nextKey: apiResponse.nextCursor
        )
    }
}

// MARK: - API Response

private struct NewsAPIResponse: Decodable {
    let items: [NewsItem]
    let nextCursor: String?
}

// MARK: - Errors

enum NewsError: Error, Equatable {
    case invalidURL
    case httpError
}

// MARK: - Paginator Type

typealias NewsPaginator = CallbackPaginator<
    NewsDataSource,
    DefaultPageValidator<NewsItem>,
    PaginatorInMemoryCache<NewsItem>
>

// MARK: - Factory

enum NewsPaginatorFactory {
    static func make(httpClient: any HTTPClientProtocol = AppHTTPClient.live) -> NewsPaginator {
        CallbackPaginator(
            dataSource: NewsDataSource(httpClient: httpClient),
            validator: DefaultPageValidator(),
            cache: PaginatorInMemoryCache(),
            store: try? FileBasedStore(namespace: "news"),
            evictor: LRUEvictor(),
            maxCount: 100
        )
    }
}
