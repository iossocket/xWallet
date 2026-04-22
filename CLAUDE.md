# CLAUDE.md — xWallet

## Project Summary

iOS-native multi-chain crypto wallet built with SwiftUI + TCA (The Composable Architecture).
Target chains: EVM (Ethereum + L2s) and Starknet. Privacy layer (Railgun/Zcash) planned.
Minimum deployment: iOS 16.4 / Xcode 16.4 / Swift 5.9.

## Module Map

```
xWallet/                          # App target
├── xWalletApp.swift              # @main entry — creates root Store<AppFeature>
├── Core/
│   └── WalletCoreValidator.swift # WalletCore sanity check (currently disabled)
├── Features/
│   ├── App/                      # AppFeature @Reducer, ContentView, RootView, BiometricSetupView
│   ├── Account/                  # Account @Reducer + Import/Mnemonic views
│   ├── Wallet/                   # Wallet @Reducer + dashboard/asset/receive views
│   ├── Send/                     # Send @Reducer + SendView
│   ├── Settings/                 # Settings / ChainManagement / WalletList reducers + views
│   ├── History/                  # Transaction history feature
│   ├── Market/                   # Market / price / candle chart feature
│   └── Starknet/                 # Starknet-specific UI
├── Models/                       # AssetItem, Chain, ChainBalance, ChainPresets,
│                                   ERC20ABI, ERC20Token, LockTimeout, WalletIdentity
├── Services/
│   ├── WalletClient.swift        # DependencyKey — multi-wallet CRUD, delegates to WalletDataSource
│   ├── BiometricClient.swift     # DependencyKey — LAContext wrapper (auth + capability)
│   ├── BalanceClient.swift       # DependencyKey — per-chain balance fetch
│   ├── ChainRegistryClient.swift # DependencyKey — chain list persistence
│   ├── ERC20Client.swift         # DependencyKey — ERC-20 calls
│   ├── PriceClient.swift         # DependencyKey — price lookup
│   ├── SendClient.swift          # DependencyKey — fee estimate + broadcast
│   ├── EvmProviderClient.swift   # DependencyKey — EthereumProvider factory
│   ├── StarknetProviderClient.swift # DependencyKey — StarknetProvider factory
│   ├── TransactionHistoryClient.swift # DependencyKey — history fetch
│   ├── HTTPClient.swift / AppHTTPClientFactory.swift # shared HTTP
│   ├── BiometricCapabilityService.swift # low-level biometric helper
│   ├── Providers/                # Provider utilities
│   └── Core/                     # Non-DI core services:
│       ├── KeychainService.swift         # iOS Keychain wrapper (SecurityStore protocol)
│       ├── WalletDataSource.swift        # struct — SQLite (GRDB) wallet metadata + secret facade
│       ├── WalletSecretDataSource.swift  # struct — JSON-encodes secrets into SecurityStore
│       ├── DatabaseService.swift         # GRDB DatabaseQueue factory
│       ├── AccountDerivationService.swift # BIP-39 / key derivation
│       ├── AppConfiguration.swift        # app config constants
│       ├── ChainDataSource.swift         # chain list DB access
│       ├── BalanceRepository.swift / PriceRepository.swift / PriceCache.swift / PriceIdResolverService.swift
└── Shared/                       # DesignSystem, ActionButton, AuroraBackground,
                                    FloatingTabBar, Color+Hex, View+RoundedCorner,
                                    PrivacyOverlayView, Shake, UnitFormatter, Paginator/

xWalletTests/                     # Test target (Swift Testing framework)
├── AccountTests.swift            # Account reducer tests
├── AccountDeployTests.swift      # Starknet account deployment tests
├── AppFeatureTests.swift         # Root reducer tests
├── WalletTests.swift             # Wallet reducer tests
├── WalletDataSourceTests.swift   # Wallet persistence tests
├── SendTests.swift               # Send reducer tests
├── HistoryTests.swift            # History reducer tests
├── ChainManagementTests.swift    # ChainManagement reducer tests
├── News/                         # News feature tests
└── Paginator/                    # Paginator tests

docs/thinking/                    # Design docs & roadmap (gitignored, not shipped)
```

## Dependencies (SPM via Xcode)

- `swift-composable-architecture` — pointfreeco TCA
- `GRDB.swift` — SQLite persistence for wallet identities
- `wallet-core` — trustwallet (WalletCore v4.4.2)
- `MultiChainKit` / `MultiChainCore` / `EthereumKit` — custom multi-chain SDK (BIP-39, signers, providers)
- `BigInt` — large number handling for Wei values

## Build & Test Commands

```bash
# Build (command line)
xcodebuild -project xWallet.xcodeproj -scheme xWallet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -project xWallet.xcodeproj -scheme xWallet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Preferred: open in Xcode, Cmd+B to build, Cmd+U to test
open xWallet.xcodeproj
```

No Makefile, Fastfile, or CI pipeline exists yet.

## Architecture Invariants

- Every feature is a TCA `@Reducer` with `@ObservableState` State, Action enum, and `body: some ReducerOf<Self>`.
- Side effects (network, keychain, DB) go through `@Dependency` clients, never called directly from reducers.
- All dependency clients provide `liveValue`, `testValue` (and optionally `previewValue`).
- Tests use `TestStore` from ComposableArchitecture with dependency overrides.
- Private keys and mnemonics are stored ONLY in iOS Keychain, guarded by `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` + `SecAccessControl` with `.biometryCurrentSet`. Wallet metadata lives in SQLite.
- Concurrency safety is provided by the underlying primitives: GRDB `DatabaseQueue` serializes all DB reads/writes, and the Keychain `SecItem*` APIs are thread-safe. `WalletDataSource` / `WalletSecretDataSource` / `KeychainService` are plain `struct`s — do not wrap them in `actor`s. Atomicity across both stores is NOT provided; compensating logic lives in the reducer layer.

## Security Constraints

- NEVER log, print, or persist mnemonics/private keys outside Keychain.
- NEVER weaken Keychain accessibility. Current policy: `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` with `SecAccessControl` flag `.biometryCurrentSet` (see `Services/Core/KeychainService.swift`).
- NEVER commit `.env` files, API keys, or real private keys.
- Test fixtures use well-known Anvil/Hardhat test keys only (e.g., `0xac0974bec...`).

## Design System Constraints

- All views must use design tokens from `Shared/DesignSystem.swift` — no hardcoded colors, fonts, spacing, or radii.
- Token prefixes: `Color.x*`, `Font.x*`, `XSpacing.*`, `XRadius.*`, `Animation.x*`.
- Card styles: `.xCard()` (frosted glass) or `.xSolidCard()` (solid dark).

## Change Policy

- Minimal diffs only — do not refactor, rename, or "improve" code outside the scope of the task.
- Do not add comments, docstrings, or type annotations to unchanged code.
- Do not create new files unless the task requires it.
- All new reducers must have corresponding tests in `xWalletTests/`.
- Run `xcodebuild test` (or Cmd+U) before considering work complete.
- `#if DEBUG _printChanges()` in AppFeature is intentional for development.
