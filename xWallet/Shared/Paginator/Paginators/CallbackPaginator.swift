//
//  CallbackPaginator.swift
//  xWallet
//
//  Created by Xueliang Zhu on 10/3/26.
//

final class CallbackPaginator<DataSource: PaginatorDataSource, Validator: PageValidator>: Paginator where DataSource.Item == Validator.Item {
    
    typealias Item = DataSource.Item
    
    private let dataSource: DataSource
    private let validator: Validator
    private let cache: PaginatorInMemoryCache<Item>

    public init(
        dataSource: DataSource,
        validator: Validator,
        cache: PaginatorInMemoryCache<Item> = .init()
    ) {
        self.dataSource = dataSource
        self.validator = validator
        self.cache = cache
    }
    
    @discardableResult
    func fetch(key: String?, pageSize: Int, listener: @escaping @Sendable (Result<PaginatorPage<DataSource.Item>, PaginatorError>) -> Void) -> PaginatorExecution {
        let internalKey = InternalPageKey(key)

        let task = Task {
            if let cached = await cache.value(for: internalKey) {
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
            
            await cache.set(.loading, for: internalKey)
            
            do {
                let page = try await dataSource.fetchPage(key: key, pageSize: pageSize)
                guard validator.isValid(page) else {
                    await cache.set(.failure(.validationFailed), for: internalKey)
                    listener(.failure(.validationFailed))
                    return
                }
                await cache.set(.success(page), for: internalKey)
                listener(.success(page))
            } catch is CancellationError {
                await cache.set(.failure(.cancelled), for: internalKey)
                listener(.failure(.cancelled))
            } catch {
                let mappedError = PaginatorError.unknown(String(describing: error))
                await cache.set(.failure(mappedError), for: internalKey)
                listener(.failure(mappedError))
            }
        }
        
        return TaskPaginatorExecution {
            task.cancel()
        }
    }
    
    func clear(key: String?) async {
        await cache.remove(for: InternalPageKey(key))
    }
    
    func clearAll() async {
        await cache.removeAll()
    }
}
