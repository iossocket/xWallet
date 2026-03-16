//
//  NewsItem.swift
//  xWallet
//
//  Created by Xueliang Zhu on 13/3/26.
//

import Foundation

struct NewsItem: Identifiable, Equatable, Hashable, Sendable, Codable {
    let id: String
    let sourceName: String
    let title: String
    let url: String
    let summary: String?
    let imageURL: String?
    let author: String?
    let publishedAt: Date?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, url, summary, author, tags
        case sourceName = "source_name"
        case imageURL = "image_url"
        case publishedAt = "published_at"
    }
}

struct NewsPage: Equatable, Sendable {
    let items: [NewsItem]
    let nextCursor: String?
}
