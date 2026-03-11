//
//  CallbackPaginator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

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

    public init(
        dataSource: DataSource,
        validator: Validator,
        cache: Cache,
        store: (any PaginatorStore<Item>)? = nil
    ) {
        self.dataSource = dataSource
        self.validator = validator
        self.cache = cache
        self.store = store
    }

    @discardableResult
    public func fetch(
        key: String?,
        pageSize: Int,
        listener: @escaping @Sendable (Result<PaginatorPage<Item>, PaginatorError>) -> Void
    ) -> PaginatorExecution {
        let task = Task {
            // 1. Cache (fast path)
            if let cached = await cache.value(for: key) {
                switch cached {
                case .success(let page):
                    listener(.success(page))
                    return
                case .loading:
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
                    listener(.success(page))
                    return
                }
                // Stale — fall through to DataSource
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
                try? await store?.save(key: key, page: page)
                listener(.success(page))
            } catch is CancellationError {
                await cache.set(.failure(.cancelled), for: key)
                listener(.failure(.cancelled))
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
        try? await store?.remove(key: key)
    }

    public func clearAll() async {
        await cache.removeAll()
        try? await store?.removeAll()
    }
}
