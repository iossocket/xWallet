## Why

TCA dependency clients 全部手写 struct-of-closures + 手写 testValue，没有使用 `@DependencyClient` 宏。同时底层基础设施（DatabaseQueue、KeychainService、HTTPClient）通过 static 单例或直接构造获取，绕过了 DI 体系。client 之间不允许组合，导致 reducer 承担了大量 I/O 编排逻辑（如 Wallet 刷新链路需要 6 个中间 action 串联 3 个 client）。

项目需要：
1. 利用 `@DependencyClient` 宏简化 client 代码
2. 将基础设施（DB、Keychain、HTTP）纳入 `@Dependency` 体系，消除隐式全局依赖
3. 建立清晰的五层依赖架构（Store → Service → Provider → Repository → Client）

## What Changes

### Phase 1: Macro Migration（已完成）
- 为 6 个 struct-of-closures client 添加 `@DependencyClient` 宏，删除手写 `testValue`
- `DependenciesMacros` 已通过 `ComposableArchitecture` re-export，无需单独 link

### Phase 2: Infrastructure DI
- 新增 `DatabaseStore`（Store 层）：将 `DatabaseService.dbQueue` static 单例包装为 `@Dependency`
- 新增 `KeychainStore`（Store 层）：将 `KeychainService` 直接构造包装为 `@Dependency`
- 新增 `HTTPService`（Service 层）：将 `AppHTTPClient.live` / `HTTPClient.shared` 单例包装为 `@Dependency`
- `ChainRepository`（原 `ChainDataSource`）→ 通过 `@Dependency(\.databaseStore)` 获取 DB（已完成）
- `WalletRepository`（原 `WalletDataSource`）→ 通过 `@Dependency(\.databaseStore)` + `@Dependency(\.keychainStore)` 获取依赖
- `PriceClient` / `TransactionHistoryClient` → 通过 `@Dependency(\.httpService)` 获取 HTTP

### Phase 3: Client Composition
- `WalletClient` 新增 `activeChainAccount` 闭包，收纳 `Send.swift` 中的 `resolveChainAccount` 逻辑
- `Send` reducer 删除 file-private `resolveChainAccount` 函数，改用 `walletClient.activeChainAccount`

### Phase 4: Portfolio Refresh Stream
- `BalanceClient` 新增 `fetchPortfolio` 闭包（返回 `AsyncStream`），内部组合 `PriceClient`
- `Wallet` reducer 用 `fetchPortfolio` 替代 `fetchAllBalances → allBalancesResponse → fetchPrices → pricesResponse` 四步链路

## Capabilities

### New Capabilities

- `dependency-client-macro-migration`: 将 6 个 client 从手写 testValue 迁移到 `@DependencyClient` 宏
- `infrastructure-di`: 将 DB、Keychain、HTTP 基础设施纳入 `@Dependency` 体系
- `client-composition`: 允许并实施 client 间通过 `@Dependency` 组合
- `portfolio-refresh-stream`: `BalanceClient` 通过 `AsyncStream` 提供聚合的 portfolio 刷新流

### Modified Capabilities

## Impact

- **架构**: 建立五层依赖体系（Store → Service → Provider → Repository → Client），消除所有 static 单例和直接构造
- **代码文件**: 6 个 client 文件、3 个新 Store/Service 文件、`WalletRepository`、`Wallet.swift`、`Send.swift`
- **测试**: Repository 级集成测试成为可能（注入 in-memory DatabaseQueue）；所有涉及 `testValue` 的测试需验证宏生成的 stub 行为一致
- **不受影响**: `AppDateClient`、`EvmProviderClient`、`StarknetProviderClient`（结构不同，不纳入此次变更）
