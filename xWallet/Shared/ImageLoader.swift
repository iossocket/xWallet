import Foundation

struct ImageLoadHandle: Sendable {
    private let _data: @Sendable () async throws -> Data
    private let _cancel: @Sendable () -> Void

    fileprivate init(
        data: @escaping @Sendable () async throws -> Data,
        cancel: @escaping @Sendable () -> Void
    ) {
        self._data = data
        self._cancel = cancel
    }

    func data() async throws -> Data {
        try await _data()
    }

    func cancel() {
        _cancel()
    }
}

/// Actor-isolated loader: memory cache + one in-flight `Task` per URL.
///
/// `data(for:)` registers a bounded pending waiter (`pendingWaiters[id] = url`).
/// `handle.data()` consumes that registration first, then may enter `inFlight`.
/// `handle.cancel()` removes pending or resumes the in-flight continuation.
/// A handle that is never `data()`/`cancel()`d leaves one pending entry until `remove*`.
///
/// Cancellation: `handle.cancel()` and caller-`Task` cancellation both call `cancelWaiter`
/// (`withTaskCancellationHandler` while suspended on the continuation).
actor ImageLoader {
    static let shared = ImageLoader()

    private struct Waiter<Value> {
        let id: UUID
        let continuation: CheckedContinuation<Value, Error>
    }

    private struct InFlightEntry<Value> {
        let task: Task<Void, Never>
        var waiters: [Waiter<Value>]
    }

    private let session: URLSession
    private let cache = NSCache<NSURL, NSData>()
    private var inFlight: [URL: InFlightEntry<Data>] = [:]
    private var pendingWaiters: [UUID: URL] = [:]
    private let maxConcurrent: Int
    private var availablePermits: Int
    private var permitWaiters: [Waiter<Void>]

    init(
        session: URLSession = .shared,
        countLimit: Int = 200,
        totalCostLimit: Int = 50 * 1024 * 1024,
        maxConcurrent: Int = 3
    ) {
        assert(maxConcurrent > 0)
        self.session = session
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.maxConcurrent = maxConcurrent
        self.availablePermits = maxConcurrent
        self.permitWaiters = []
    }

    func data(for url: URL) -> ImageLoadHandle {
        let waiterID = UUID()
        pendingWaiters[waiterID] = url
        return ImageLoadHandle(
            data: { try await self.wait(url: url, waiterID: waiterID) },
            cancel: { Task { await self.cancelWaiter(url: url, id: waiterID) } }
        )
    }

    func prefetch(_ urls: [URL]) {
        for url in urls {
            Task {
                let handle = self.data(for: url)
                _ = try? await handle.data()
            }
        }
    }

    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
        pendingWaiters = pendingWaiters.filter { $0.value != url }
        
        guard let entry = inFlight.removeValue(forKey: url) else { return }
        entry.waiters.forEach { $0.continuation.resume(throwing: CancellationError()) }
        entry.task.cancel()
    }

    func removeAll() {
        cache.removeAllObjects()
        pendingWaiters.removeAll()
        
        let entries = inFlight
        inFlight.removeAll()
        for entry in entries.values {
            entry.waiters.forEach { $0.continuation.resume(throwing: CancellationError()) }
            entry.task.cancel()
        }
    }

    private func wait(url: URL, waiterID: UUID) async throws -> Data {
        guard pendingWaiters.removeValue(forKey: waiterID) != nil else {
            throw CancellationError()
        }

        try Task.checkCancellation()

        if let cached = cache.object(forKey: url as NSURL) {
            return cached as Data
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let waiter = Waiter(id: waiterID, continuation: continuation)

                if var existing = inFlight[url] {
                    existing.waiters.append(waiter)
                    inFlight[url] = existing
                    return
                }

                let task = Task {
                    do {
                        var didAcquire = false
                        try await acquirePermit()
                        didAcquire = true
                        defer {
                            if didAcquire {
                                releasePermit()
                            }
                        }
                        
                        try Task.checkCancellation()
                        let (data, resp) = try await session.data(from: url)
                        guard let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                            self.complete(url: url, result: .failure(URLError(.badServerResponse)))
                            return
                        }
                        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
                        self.complete(url: url, result: .success(data))
                    } catch is CancellationError {
                        self.complete(url: url, result: .failure(CancellationError()))
                    } catch {
                        self.complete(url: url, result: .failure(error))
                    }
                }

                inFlight[url] = InFlightEntry(task: task, waiters: [waiter])
            }
        } onCancel: {
            Task { await self.cancelWaiter(url: url, id: waiterID) }
        }
    }

    private func cancelWaiter(url: URL, id: UUID) {
        if pendingWaiters.removeValue(forKey: id) != nil {
            return
        }

        if var entry = inFlight[url],
           let index = entry.waiters.firstIndex(where: { $0.id == id })
        {
            let waiter = entry.waiters.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
            if entry.waiters.isEmpty {
                inFlight[url] = nil
                entry.task.cancel()
            } else {
                inFlight[url] = entry
            }
        }
    }

    private func complete(url: URL, result: Result<Data, Error>) {
        guard let entry = inFlight.removeValue(forKey: url) else { return }
        entry.waiters.forEach {
            $0.continuation.resume(with: result)
        }
    }
    
    private func acquirePermit() async throws {
        if availablePermits > 0 {
            availablePermits -= 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                permitWaiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelPermitWaiter(id: id) }
        }
    }
    
    private func releasePermit() {
        if permitWaiters.count > 0 {
            let waiter = permitWaiters.removeFirst()
            waiter.continuation.resume(returning: ())
        } else {
            availablePermits = min(availablePermits + 1, maxConcurrent)
        }
    }
    
    private func cancelPermitWaiter(id: UUID) {
        guard let index = permitWaiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        let waiter = permitWaiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}

func test() async throws {
    let handler = await ImageLoader.shared.data(for: URL(string: "")!)
    let _ = try await handler.data()
    handler.cancel()
}
