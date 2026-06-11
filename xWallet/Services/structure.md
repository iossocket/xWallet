# Services 分层架构

## 原则

1. **类型的职责决定层**，名字严格跟随层后缀，无例外。
2. **Reducer 可直接使用任意层**，不存在"只能用 Client 层"的限制。

## 层定义

| 层 | 职责 | 后缀 |
|----|------|------|
| Store | 单一存储读写（DB、Keychain） | `*Store` |
| Service | 单一外部 I/O / 系统访问，不组合其他类型 | `*Service` |
| Provider | 单一外部数据源访问，被 Repository 消费 | `*Provider` |
| Repository | 组合多个 Store/Service/Provider + 领域逻辑/缓存 | `*Repository` |
| Client | 为某功能用例做编排（组合 Repository + 签名/lifecycle 等） | `*Client` |

## 状态图例

✅ DI + 命名都到位 · 🔧 DI 完成、待重命名 · ⬜ 未开始 · ⚠️ 判断项，待你确认

## 完整清单

### Store
| 类型 | 文件 | DI | 状态 |
|------|------|----|----|
| `DatabaseStore` | Store/DatabaseStore.swift | @DependencyClient `\.databaseStore` | ✅ 改名完成 |
| `KeychainStore` | Store/KeychainStore.swift | @DependencyClient（待加 `\.keychainStore` 注册） | ✅ 改名完成 |

> 注：`KeychainStore` 目前只有 `DependencyKey`，尚无 `DependencyValues.keychainStore` 计算属性 —— 等 task 5.2 把 `WalletSecretDataSource` 改为 `@Dependency(\.keychainStore)` 解析时补上。

### Service
| 类型 | 文件 | DI | 状态 |
|------|------|----|----|
| `HTTPService` | Service/HTTPService.swift | @DependencyClient `\.httpService` | ✅ 新建完成（暂无消费方，见下注） |
| `BiometricService` | BiometricService.swift | @DependencyClient `\.biometricService` | ✅ 改名完成 |
| ~~`DateGenerator`（`\.appDate`）~~ | ~~AppDateClient.swift~~ 已删除 | 改用框架内置 `\.date` | ✅ 删除并替换 |
| `StarknetRPCService` | Service/StarknetRPCService.swift | DependencyKey `\.starknetRPCService` | ✅ 类型 + keypath 全改名（Service，直接 Starknet RPC）；3 reducer + 3 测试消费方已更新 |
| `ERC20Client` → `ERC20Service` ⚠️ | ERC20Client.swift | @DependencyClient | ⚠️ 待确认 |
| `TransactionHistoryClient` → `TransactionHistoryService` ⚠️ | TransactionHistoryClient.swift | @DependencyClient | ⚠️ 待确认 |

> 注 1：`HTTPService` 已新建并注册，但没有任何消费方 `@Dependency(\.httpService)`——Price/History 仍走 `AppHTTPClient.live`。把消费方接到 `\.httpService` 是后续单独的行。
> 注 2：目录不一致——`HTTPService` 在 `Services/Service/`，`BiometricService` 还在 `Services/` 顶层。是否把 Service 层文件统一收进 `Services/Service/`，待你定。

### Provider
| 当前类型 | 文件 | 目标名 | 状态 |
|---------|------|--------|----|
| `CoinGeckoPriceProvider` | Providers/CoinGeckoPriceProvider.swift | 不变 | ✅ |
| `DefiLlamaPriceProvider` | Providers/DefiLlamaPriceProvider.swift | 不变 | ✅ |
| `EvmBalanceProvider` | Providers/EvmBalanceProvider.swift | 不变 | ✅ |
| `StarknetBalanceProvider` | Providers/StarknetBalanceProvider.swift | 不变 | ✅ |

### Repository
| 当前类型 | 文件 | 目标名 | DI | 状态 |
|---------|------|--------|----|----|
| `ChainDataSource` | Core/ChainDataSource.swift | `ChainRepository` | @DependencyClient | 🔧 |
| `WalletDataSource` | Core/WalletDataSource.swift | `WalletRepository` | 待加 @DependencyClient | ⬜ |
| `WalletSecretRepository` | Core/WalletSecretRepository.swift | 不变 | @DependencyClient `\.walletSecretRepository` | ✅ 改名+DI 完成（Path A 已定）；消费方仅 WalletDataSource，测试待重写 |
| `PriceRepository` | Core/PriceRepository.swift | 不变 | 待加 @DependencyClient | ⬜ |
| `BalanceRepository` | Core/BalanceRepository.swift | 不变 | 待加 @DependencyClient | ⬜ |

### Client
| 当前类型 | 文件 | 组合 | 目标名 | DI | 状态 |
|---------|------|------|--------|----|----|
| `WalletClient` | WalletClient.swift | WalletRepository + 签名 | 不变 | @DependencyClient | ✅ macro，内部仍用单例 |
| `ChainRegistryClient` | ChainRegistryClient.swift | ChainRepository | 不变 | @DependencyClient | ✅ |
| `PriceClient` | PriceClient.swift | PriceRepository | 不变 | @DependencyClient | ✅ macro，仍用 AppHTTPClient.live |
| `BalanceClient` | BalanceClient.swift | BalanceRepository | 不变 | 待加 @DependencyClient | ⬜ |
| `SendClient` | SendClient.swift | provider + 签名 | 不变 | @DependencyClient | ✅ |
| `WalletConnectClient` | WalletConnectClient.swift | Reown SDK + session lifecycle | 不变 ⚠️ | 手写 testValue | ⚠️ |
| `ChainClient` | ChainClient.swift | chainRegistry + SDK Contract/Account/Provider + 签名 | — | `\.chain` | ⬜ 计划：cross-chain-token-executor 变更引入，吸收 SendClient/StarknetRPCService/ERC20Client |

### Factory（DI 注入的工厂，**不属值分层**，但仍需 `@Dependency`）

工厂造的对象有副作用（网络），测试要换 mock，所以仍在依赖图里。和纯函数不同：纯函数无副作用 → 无需 DI；工厂造 I/O 对象 → 需要 DI。

| 类型 | 文件 | DI | 状态 |
|------|------|----|----|
| `EvmProviderFactory` | Core/EvmProviderFactory.swift | DependencyKey `\.evmProviderFactory` | ✅ 类型 + keypath 全改名（`(Chain) -> EvmProviderProtocol`，testValue 返回 MockEvmProvider）；ChainManagement 已更新 |

## ⚠️ 需你确认的判断项

这几个卡在 **Service ↔ Client / Repository** 的边界上，取决于你怎么划"无状态外部调用"和"用例编排"这条线，我替你定了一个但不确定：

| 类型 | 我的判断 | 理由 | 反方观点 |
|------|---------|------|---------|
| ~~`EvmProviderClient`~~ | ✅ 已定 Factory → `EvmProviderFactory` | 纯 `(Chain) -> Provider` 工厂 | — |
| ~~`StarknetProviderClient`~~ | ✅ 已定 Service → `StarknetRPCService` | 直接 Starknet RPC 操作，包装单一外部系统 | — |
| `ERC20Client` → `ERC20Service` | Service | 无状态 ERC-20 RPC 调用，不组合多源 | 也可视为 EVM 之上的领域 Repository |
| `TransactionHistoryClient` → `TransactionHistoryService` | Service | 单一 API（Blockscout）+ 解析 | 有分页/领域映射，可视为 Repository |
| ~~`WalletSecretDataSource` → `WalletSecretRepository`~~ | ✅ 已定 Repository（Path A，独立 DI）| 组合 KeychainStore + JSON 编解码 | — |
| `WalletConnectClient` 保持 Client | Client | session/proposal lifecycle 编排 | 单一 SDK 薄包装，可能算 Service |

## 残留单例引用（迁移后必须为零）

| 单例 | 引用位置 | 替换为 |
|------|---------|--------|
| `DatabaseService.dbQueue` | WalletClient.swift:36 | `@Dependency(\.databaseStore)` |
| `KeychainService()` | WalletClient.swift:36 | `@Dependency(\.keychainStore)` |
| `AppHTTPClient.live` | PriceClient.swift:22-23 | `@Dependency(\.httpService)` |
| `AppHTTPClient.live` | TransactionHistoryClient.swift:74 | `@Dependency(\.httpService)` |
| `BalanceRepository()` | BalanceClient.swift:18 | `@Dependency(\.balanceRepository)` |

## 迁移后删除的遗留代码

| 类型 | 文件 | 说明 |
|------|------|------|
| `DatabaseService`（enum，旧单例） | Core/DatabaseService.swift:110-189 | DatabaseStore 取代 |
| `KeychainService`（全注释） | Core/KeychainService.swift | KeychainStore 取代，整文件删除 |
| `_AppHTTPClientFactory` | AppHTTPClientFactory.swift | HTTPService 取代 |
| `HTTPClient.shared` / `AppHTTPClient.live` | HTTPClient.swift | HTTPService 取代 |

## 纯函数 / Domain 工具（无副作用、无依赖，**不属于 DI 分层**）

DI 分层分的是副作用/依赖；纯确定性函数没有副作用，不在依赖图里，任意层可直接调用。

| 类型 | 文件 | 说明 |
|------|------|------|
| `AccountDerivation`（enum，static 纯函数） | Core/AccountDerivation.swift | BIP-39/crypto 地址派生，无 I/O/状态。被 WalletClient 直接调用。✅ 已去掉 "Service" 后缀 |

## 非 DI 辅助类型（Repository/Client 内部，不单列层）

| 类型 | 文件 | 归属 |
|------|------|------|
| `BiometricCapabilityService` | BiometricCapabilityService.swift | BiometricService 内部 |
| `PriceCache` | Core/PriceCache.swift | PriceRepository 内部 |
| `PriceIdResolverService` | Core/PriceIdResolverService.swift | Price Provider 内部 |
| `AppConfiguration` | Core/AppConfiguration.swift | 配置常量 + WalletConnect 初始化 |
