## 1. Project Setup

- [x] 1.1 ~~Link `DependenciesMacros` product~~ — not needed: `ComposableArchitecture` re-exports it

## 2. Macro Migration（已完成）

- [x] 2.1 `BiometricClient` → `@DependencyClient`
- [x] 2.2 `ChainRegistryClient` → `@DependencyClient`
- [x] 2.3 `ERC20Client` → `@DependencyClient`
- [x] 2.4 `PriceClient` → `@DependencyClient`
- [x] 2.5 `SendClient` → `@DependencyClient`
- [x] 2.6 `TransactionHistoryClient` → `@DependencyClient`
- [x] 2.7 `WalletClient` → `@DependencyClient`
- [x] 2.8 `DatabaseClient` → `@DependencyClient`
- [x] 2.9 `SecurityStore` → `@DependencyClient`
- [x] 2.10 `ChainDataSource` → `@DependencyClient`

## 3. Store Layer — DI + 重命名

- [x] 3.1 `DatabaseClient` → `DatabaseStore`，key `\.databaseClient` → `\.databaseStore`
  > 完成；文件移至 Store/DatabaseStore.swift；ChainDataSource.swift 引用已更新
- [x] 3.2 `SecurityStore` → `KeychainStore`，文件 git mv 为 Store/KeychainStore.swift
  > 生产代码（WalletDataSource/WalletSecretDataSource）类型引用已更新
  > 遗留：测试 `InMemorySecurityStore: SecurityStore` 是死 mock（class 无法 conform struct，codex P1 #2），留给 task 5.2 closure 重写
  > 遗留：`DependencyValues.keychainStore` 注册待 task 5.2 补
- [ ] 3.3 删除全注释的 `Core/KeychainService.swift`（SecurityStore 已无生产引用，可删）

## 4. Service Layer — DI + 重命名

- [x] 4.1 新建 `HTTPService`（`@DependencyClient`，`\.httpService`），底层保留 `AppHTTPClient.live` / `.sslLive` 工厂
  > 完成；协议派统一为 `data(for:)`，新增 `SSLPinningHTTPBaseService`；删除残骸 `AppHTTPClientFactory.swift`
  > 遗留：暂无消费方接 `\.httpService`（Price/History 仍走 `AppHTTPClient.live`）——并入 4.7 / 6.x
- [x] 4.2 `BiometricClient` → `BiometricService`，key `\.biometricClient` → `\.biometricService`
  > 完成；文件 git mv 为 `Services/BiometricService.swift`（仍在顶层，未挪入 Service/）；AppFeature + AppFeatureTests 全部更新
- [x] 4.3 ~~`AppDateClient.swift` → `AppDateService.swift`~~ → 改为**删除** `AppDateClient.swift`，`\.appDate` 全部替换为框架内置 `\.date`
  > `AppDateKey`/`\.appDate` 是在重复造框架已有的 `\.date`（`DateGenerator { Date() }` 完全相同）。AppFeature 4 处 + 测试 3 处 override 改为 `\.date`/`$0.date`；测试已全部 override，符合内置 `\.date` 的 unimplemented testValue 要求
- [x] 4.4 `EvmProviderClient` → `EvmProviderFactory`（Factory 类，非 Service；仍 `@Dependency`，key `\.evmProvider` → `\.evmProviderFactory`）
  > 完成；文件移至 Core/；ChainManagement 已更新
- [x] 4.5 `StarknetProviderClient` → `StarknetRPCService`（Service，直接 Starknet RPC；key `\.starknetProvider` → `\.starknetRPCService`，3 reducer + 3 测试已更新）
- [ ] 4.6 ⚠️ `ERC20Client` → `ERC20Service`
- [ ] 4.7 ⚠️ `TransactionHistoryClient` → `TransactionHistoryService`，resolve HTTP via `@Dependency(\.httpService)`

## 5. Repository Layer — DI + 重命名

- [ ] 5.1 `ChainDataSource` → `ChainRepository`，key `\.chainDataSource` → `\.chainRepository`
  > 更新 ChainRegistryClient.swift:23 引用
- [x] 5.2 `WalletSecretDataSource` → `WalletSecretRepository`（`@DependencyClient`），resolve Keychain via `@Dependency(\.keychainStore)`
  > 已定 Path A（独立 Repository）。文件改名 Core/WalletSecretRepository.swift，注册 `\.walletSecretRepository`；secret JSON 编解码/legacy 兼容逐字保留为 file-private 函数
  > 生产消费方仅 `WalletDataSource`（已改用 `@Dependency(\.walletSecretRepository)`，`init` 去掉 `securityStore` 参数）
  > 未 build 验证：主 target 仍红（WalletClient:36 / XWDebugOverlay:299 调已删的 `KeychainService()` + 旧 init），留给 5.3/6.1
  > 测试遗留：WalletDataSourceTests 的 4 个 secret 测试仍引用已删的 `WalletSecretDataSource`，与第 5 个测试 + `InMemorySecurityStore` 一并在测试重写步骤处理
- [ ] 5.3 `WalletDataSource` → `WalletRepository`（`@DependencyClient`），resolve DB via `@Dependency(\.databaseStore)` + secret via `@Dependency(\.walletSecretRepository)`
- [ ] 5.4 `PriceRepository` → `@DependencyClient`，resolve HTTP via `@Dependency(\.httpService)`
- [ ] 5.5 `BalanceRepository` → `@DependencyClient`

## 6. Client Layer — 消除直接构造 / 单例

- [ ] 6.1 `WalletClient.liveValue` 改用 `@Dependency(\.walletRepository)`，删除 `WalletDataSource(dbQueue: DatabaseService.dbQueue, securityStore: KeychainService())`
- [ ] 6.2 `PriceClient.liveValue` 改用 `@Dependency(\.priceRepository)`
- [ ] 6.3 `BalanceClient` → `@DependencyClient`，改用 `@Dependency(\.balanceRepository)`

## 7. Cleanup — 删除遗留

- [ ] 7.1 删除 `DatabaseService` enum（Core/DatabaseService.swift:110-189）
- [ ] 7.2 删除 `_AppHTTPClientFactory`（AppHTTPClientFactory.swift）
- [ ] 7.3 删除 `HTTPClient.shared` / `AppHTTPClient.live`

## 8. Client Composition — WalletClient.activeChainAccount

- [ ] 8.1 `WalletClient` 新增 `activeChainAccount` 闭包 + `liveValue` 实现
- [ ] 8.2 `WalletClient.testValue` 补 `activeChainAccount` stub
- [ ] 8.3 `Send.swift` 改用 `walletClient.activeChainAccount`，删除 file-private `resolveChainAccount`
- [ ] 8.4 Send reducer 测试改为 override `activeChainAccount`

## 9. Portfolio Refresh Stream

- [ ] 9.1 `BalanceClient.swift` 定义 `PortfolioUpdate` enum
- [ ] 9.2 `BalanceClient` 新增 `fetchPortfolio` 闭包
- [ ] 9.3 `fetchPortfolio` `liveValue` 组合 `PriceClient`（via `@Dependency`）
- [ ] 9.4 Wallet reducer 用 `portfolioUpdate` 替代 `fetchAllBalances/allBalancesResponse/fetchPrices/pricesResponse` 链路
- [ ] 9.5 Wallet reducer 测试改用 `fetchPortfolio` stream

## 10. Verification

- [ ] 10.1 `xcodebuild build` — 无编译错误
- [ ] 10.2 `xcodebuild test` — 无回归
- [ ] 10.3 零单例引用：`grep -rn "DatabaseService\.dbQueue\|KeychainService()\|AppHTTPClient\.live\|HTTPClient\.shared\|BalanceRepository()" xWallet/Services/`

## ⚠️ 标记说明

`⚠️` 任务依赖 structure.md「需你确认的判断项」表 —— 这几个类型卡在 Service↔Client/Repository 边界，命名待你拍板后再执行。
