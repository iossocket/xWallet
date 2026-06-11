## Context

All TCA dependency clients in xWallet use hand-written struct-of-closures with manually maintained `testValue` stubs. Infrastructure dependencies (DatabaseQueue, KeychainService, HTTPClient) are accessed via static singletons or direct construction, bypassing the DI system entirely. Clients are isolated and do not compose with each other, forcing reducers to orchestrate multi-step I/O chains via intermediate actions.

## Goals / Non-Goals

**Goals:**

- Migrate 6 eligible clients to `@DependencyClient` macro, eliminating hand-written `testValue`
- Establish five-layer dependency architecture: Store → Service → Provider → Repository → Client
- Wrap infrastructure singletons (DB, Keychain, HTTP) as `@Dependency`
- Enable client composition: `BalanceClient.fetchPortfolio` internally resolves `PriceClient`
- Simplify Wallet reducer refresh: replace 4-action chain with single `fetchPortfolio` stream
- Move `resolveChainAccount` from file-private function in Send.swift to `WalletClient.activeChainAccount`

**Non-Goals:**

- Migrate `AppDateClient` (uses `DateGenerator`), `EvmProviderClient` / `StarknetProviderClient` (factory pattern) — these have different shapes and are out of scope
- Add new network endpoints or change API contracts
- Modify `WalletConnectClient` (recently added, already has its own pattern)

## Dependency Architecture

Source of truth: `xWallet/Services/structure.md`. Layer is determined by responsibility; the type name strictly follows the layer suffix. ⚠️ marks items pending naming confirmation (see structure.md「需你确认的判断项」).

```
Store（单一存储读写）
├── DatabaseStore              (GRDB DatabaseQueue)      ← 当前 DatabaseClient
├── KeychainStore              (SecItem*)                ← 当前 SecurityStore

Service（单一外部 I/O，不组合其他类型）
├── HTTPService                (URLSession)              ← 新建
├── BiometricService           (LAContext)              ← 当前 BiometricClient
├── AppDateService             (DateGenerator)          ← AppDateClient.swift 文件改名
├── AccountDerivationService   (BIP-39, 纯函数，无需 DI)
├── EvmProviderService ⚠️      (vend EthereumProvider)  ← 当前 EvmProviderClient
├── StarknetProviderService ⚠️ (vend StarknetProvider)  ← 当前 StarknetProviderClient
├── ERC20Service ⚠️            (ERC-20 RPC)             ← 当前 ERC20Client
├── TransactionHistoryService ⚠️ (Blockscout API)       ← 当前 TransactionHistoryClient

Provider（单一外部数据源访问，被 Repository 消费）
├── CoinGeckoPriceProvider     → HTTPService
├── DefiLlamaPriceProvider     → HTTPService
├── EvmBalanceProvider         → EvmProviderService
├── StarknetBalanceProvider    → StarknetProviderService

Repository（组合 Store/Service/Provider + 领域逻辑/缓存）
├── ChainRepository            → DatabaseStore                              ← 当前 ChainDataSource
├── WalletRepository           → DatabaseStore + WalletSecretRepository     ← 当前 WalletDataSource
├── WalletSecretRepository ⚠️  → KeychainStore                             ← 当前 WalletSecretDataSource
├── PriceRepository            → CoinGecko/DefiLlama Provider + PriceCache
├── BalanceRepository          → Evm/Starknet BalanceProvider

Client（功能用例编排，组合 Repository + 签名/lifecycle）
├── WalletClient               → WalletRepository + 签名
├── ChainRegistryClient        → ChainRepository
├── PriceClient                → PriceRepository
├── BalanceClient              → BalanceRepository
├── SendClient                 → provider + 签名
└── WalletConnectClient ⚠️     → Reown SDK + session lifecycle
```

**Rules:**
- Reducer 可直接使用任意层（不限制只用 Client）。层由职责决定，名字跟随层后缀。
- Store/Service: `liveValue` 直接构造真实实现，不 `@Dependency` 其他业务 client
- Provider: 包装单一外部数据源，可 `@Dependency` 解析 Service
- Repository: `liveValue` 在闭包体内（call-time）`@Dependency` 解析 Store/Service/Provider
- Client: `liveValue` 在闭包体内 `@Dependency` 解析 Repository（或 Store/Service）

## Decisions

### D1: Use `@DependencyClient` macro for 6 clients

**Rationale:** The macro auto-generates `testValue` with `XCTFail`-based "unimplemented" stubs, a memberwise init, and proper parameter labels. This catches untested code paths in `TestStore` and eliminates manual stub code. Tests that currently override specific closures continue to work unchanged.

**Clients in scope:** `BiometricClient`, `ChainRegistryClient`, `ERC20Client`, `PriceClient`, `SendClient`, `TransactionHistoryClient`

**Clients excluded:** `WalletClient` (closures return optional/complex types with meaningful test fixtures), `AppDateClient` (uses `DateGenerator` type), `EvmProviderClient`/`StarknetProviderClient` (factory pattern).

### D2: DependenciesMacros does not need separate linking

**Rationale:** `ComposableArchitecture` re-exports `DependenciesMacros`. As verified by the existing `@DependencyClient` usage in `BiometricClient.swift` with only `import ComposableArchitecture`, no separate `import DependenciesMacros` or project linking is needed.

### D3: Closures with non-Void return types get default values

**Rationale:** `@DependencyClient` requires closures returning non-`Void` to have explicit default values, otherwise the macro emits a compile error. Use sensible zero-value defaults (empty arrays, `.unknown` for enums, etc.).

### D4: Wrap DatabaseQueue as `DatabaseStore`

**Rationale:** `DatabaseService.dbQueue` is a static singleton used by `WalletRepository` and `ChainRepository`. Wrapping it as `@Dependency(\.databaseStore)` makes the dependency explicit, enables Repository-level integration tests with in-memory `DatabaseQueue`, and eliminates hidden coupling to a global. Named `Store` (not `Client`) because it is a single-storage wrapper, not a Reducer-facing DI boundary.

### D5: Wrap KeychainService as `KeychainStore`

**Rationale:** `KeychainService()` is directly constructed inside `WalletClient.liveValue`. Wrapping it as `@Dependency(\.keychainStore)` makes the dependency explicit and allows integration tests of `WalletRepository` without hitting real Keychain. Named `Store` because it wraps a single persistence system (iOS Keychain).

### D6: Wrap HTTP as `HTTPService`

**Rationale:** `AppHTTPClient.live` / `HTTPClient.shared` are static singletons accessed by `PriceClient`, `TransactionHistoryClient`, and price providers. Wrapping as `@Dependency(\.httpService)` makes HTTP testable at the Repository/Provider level. Named `Service` (not `Client`/`Store`) because it wraps a stateless external I/O system (URLSession), not a persistence store.

### D7: `BalanceClient` gains `fetchPortfolio` returning `AsyncStream`

**Rationale:** The current Wallet refresh requires 4 actions chained across 2 clients. By composing `PriceClient` inside `BalanceClient.fetchPortfolio`, the stream yields intermediate `PortfolioUpdate` values (balances loaded → prices loaded), letting the reducer handle a single stream with a single response action.

### D8: `WalletClient` gains `activeChainAccount` closure

**Rationale:** `Send.swift` has a file-private `resolveChainAccount` function that resolves the active wallet + provider for a given chain. This logic belongs in `WalletClient` since it depends on wallet state. Moving it also makes it testable via dependency override.

## Risks / Trade-offs

- [Test breakage from unimplemented stubs] → Tests that call client methods without overriding them will now fail with `XCTFail` instead of returning silent defaults. **Mitigation:** Desired behavior — surfaces untested code paths.
- [Infrastructure DI adds indirection] → Store/Service layer adds new types. **Mitigation:** These types are simple wrappers with clear single responsibility; the indirection replaces hidden static coupling.
- [SecurityStore protocol removal breaks tests] → Codex flagged: changing `SecurityStore` from protocol to `@DependencyClient` struct breaks `InMemorySecurityStore` conformance in tests. **Mitigation:** Tests must construct `KeychainStore` with mock closures instead of protocol conformance.
- [AsyncStream complexity in fetchPortfolio] → More complex than simple request/response. **Mitigation:** The stream has exactly 2 yields; the reducer handles it via `for await` in a single `.run` effect.
