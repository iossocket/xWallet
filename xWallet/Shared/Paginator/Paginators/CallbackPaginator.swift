//
//  CallbackPaginator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

@preconcurrency import UIKit

public final class CallbackPaginator<
    DataSource: PaginatorDataSource,
    Validator: PageValidator,
    Cache: PaginatorCache
>: Paginator where DataSource.Item == Validator.Item, DataSource.Item == Cache.Item {

    public typealias Item = DataSource.Item

    private let dataSource: DataSource
    private let validator: Validator
    private let cache: Cache
    private let store: (any PaginatorStore<Item>)?
    private let evictor: PaginatorEvictor?
    private let maxCount: Int
    private let metaTracker = CacheEntryMetaTracker()
    private let pressureObservers: [NSObjectProtocol]

    public init(
        dataSource: DataSource,
        validator: Validator,
        cache: Cache,
        store: (any PaginatorStore<Item>)? = nil,
        evictor: PaginatorEvictor? = nil,
        maxCount: Int = .max
    ) {
        self.dataSource = dataSource
        self.validator = validator
        self.cache = cache
        self.store = store
        self.evictor = evictor
        self.maxCount = maxCount
        self.pressureObservers = evictor != nil
            ? Self.makeSystemPressureObservers(cache: cache, store: store, evictor: evictor, maxCount: maxCount, metaTracker: metaTracker)
            : []
    }

    deinit {
        for observer in pressureObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @discardableResult
    public func fetch(
        key: String?,
        pageSize: Int,
        listener: @escaping @Sendable (Result<PaginatorPage<Item>, PaginatorError>) -> Void
    ) -> PaginatorExecution {
        let task = Task {
            // Track access for LRU
            await metaTracker.recordAccess(for: key)

            // 1. Cache (fast path)
            if let cached = await cache.value(for: key) {
                switch cached {
                case .success(let page):
                    listener(.success(page))
                    return
                case .loading:
                    // Another fetch is in progress — report cancelled so the
                    // continuation is always resumed and never leaked.
                    listener(.failure(.cancelled))
                    return
                default:
                    break
                }
            }

            await cache.set(.loading, for: key)

            // 2. Store (persistent cache, optional)
            if let store, let page = try? await store.load(key: key) {
                if validator.isValid(page) {
                    await cache.set(.success(page), for: key)
                    await metaTracker.recordInsert(for: key)
                    listener(.success(page))
                    return
                }
                try? await store.remove(key: key)
            }

            // 3. DataSource (network / DB)
            do {
                let page = try await dataSource.fetchPage(key: key, pageSize: pageSize)
                guard validator.isValid(page) else {
                    await cache.set(.failure(.validationFailed), for: key)
                    listener(.failure(.validationFailed))
                    return
                }
                await cache.set(.success(page), for: key)
                await metaTracker.recordInsert(for: key)
                try? await store?.save(key: key, page: page)
                await evictIfNeeded()
                listener(.success(page))
            } catch is CancellationError {
                await cache.set(.failure(.cancelled), for: key)
                listener(.failure(.cancelled))
            } catch let paginatorError as PaginatorError {
                await cache.set(.failure(paginatorError), for: key)
                listener(.failure(paginatorError))
            } catch let urlError as URLError {
                let mapped = PaginatorError.network(urlError.localizedDescription)
                await cache.set(.failure(mapped), for: key)
                listener(.failure(mapped))
            } catch {
                let mappedError = PaginatorError.unknown(String(describing: error))
                await cache.set(.failure(mappedError), for: key)
                listener(.failure(mappedError))
            }
        }

        return TaskPaginatorExecution {
            task.cancel()
        }
    }

    public func clear(key: String?) async {
        await cache.remove(for: key)
        await metaTracker.remove(for: key)
        try? await store?.remove(key: key)
    }

    public func clearAll() async {
        await cache.removeAll()
        await metaTracker.removeAll()
        try? await store?.removeAll()
    }

    // MARK: - Eviction

    private func evictIfNeeded() async {
        guard let evictor else { return }
        let entries = await metaTracker.allEntries()
        let keysToRemove = evictor.keysToEvict(entries: entries, maxCount: maxCount)
        for key in keysToRemove {
            await cache.remove(for: key)
            await metaTracker.remove(for: key)
            try? await store?.remove(key: key)
        }
    }

    private static func makeSystemPressureObservers(
        cache: Cache,
        store: (any PaginatorStore<DataSource.Item>)?,
        evictor: PaginatorEvictor?,
        maxCount: Int,
        metaTracker: CacheEntryMetaTracker
    ) -> [NSObjectProtocol] {
        var observers: [NSObjectProtocol] = []

        let evict: @Sendable () -> Void = {
            Task {
                guard let evictor else { return }
                let entries = await metaTracker.allEntries()
                let keysToRemove = evictor.keysToEvict(entries: entries, maxCount: maxCount)
                for key in keysToRemove {
                    await cache.remove(for: key)
                    await metaTracker.remove(for: key)
                    try? await store?.remove(key: key)
                }
            }
        }

        #if os(iOS) || os(tvOS)
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { _ in evict() }
        )
        #endif

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSBundleResourceRequestLowDiskSpace,
                object: nil,
                queue: nil
            ) { _ in evict() }
        )

        return observers
    }
}
