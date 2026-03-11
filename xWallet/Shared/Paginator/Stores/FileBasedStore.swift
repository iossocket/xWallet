//
//  FileBasedStore.swift
//  xWallet
//
//  Created by Xueliang Zhu on 11/3/26.
//

import Foundation
import CryptoKit

public actor FileBasedStore<Item: Sendable & Codable>: PaginatorStore {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(namespace: String) throws {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = caches.appendingPathComponent("Paginator/\(namespace)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func load(key: String?) -> PaginatorPage<Item>? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PaginatorPage<Item>.self, from: data)
    }

    public func save(key: String?, page: PaginatorPage<Item>) throws {
        let data = try encoder.encode(page)
        try data.write(to: fileURL(for: key), options: .atomic)
    }

    public func remove(key: String?) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String?) -> URL {
        let raw = key ?? "first page"
        let hash = SHA256.hash(data: Data(raw.utf8))
        let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(filename).json")
    }
}
