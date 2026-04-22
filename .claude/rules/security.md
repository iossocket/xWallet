# Security Rules — xWallet

## Keychain — Private Key & Mnemonic Storage

The only authorized store for secrets is iOS Keychain via `KeychainService` in `xWallet/Services/Core/KeychainService.swift`. JSON encoding / key-name construction lives in `xWallet/Services/Core/WalletSecretDataSource.swift`.

Checklist:
- [ ] Accessibility is `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` combined with a `SecAccessControl` flag of `.biometryCurrentSet` — never weaken either half
- [ ] Keychain account keys follow these two patterns — see `WalletSecretDataSource.privateKeyAccount` / `mnemonicAccount`:
  - `wallet_<UUID>` — private-key payload
  - `wallet_mnemonic_<UUID>` — mnemonic payload
- [ ] Secrets are JSON-encoded with a `type` discriminator (`"mnemonic"` / `"privateKey"`) before storage
- [ ] Private key bytes are base64-encoded inside the JSON payload, never stored as raw hex
- [ ] Concurrency safety comes from the underlying primitives: GRDB `DatabaseQueue` serializes DB I/O and Apple's `SecItem*` APIs are thread-safe. `WalletDataSource` / `WalletSecretDataSource` / `KeychainService` are plain `struct`s — do NOT wrap them in `actor`s.
- [ ] Atomicity across Keychain + SQLite is NOT provided. Composite operations (e.g. `deleteWallet`) must use a fixed order and be re-runnable so partial failures don't leave orphans.

## What NEVER Touches Disk, Logs, or Network

- Mnemonic phrases
- Raw private key bytes / hex
- Keychain `Data` blobs before or after decoding

Violations to watch for:
- [ ] No `print()`, `debugPrint()`, `os_log()`, `Logger`, or `NSLog` containing secrets
- [ ] No writing secrets to `UserDefaults`, files, SQLite, or Core Data
- [ ] No including secrets in `Error.localizedDescription` or `errorMessage` state
- [ ] No sending secrets in analytics, crash reports, or network requests (except signing)
- [ ] No secrets in SwiftUI `Text()` views outside of a dedicated, guarded mnemonic backup screen

## SQLite (GRDB) — Metadata Only

`WalletDataSource` in `xWallet/Services/Core/WalletDataSource.swift` stores wallet metadata in `wallets.sqlite3` (DB queue set up by `DatabaseService`):
- `wallet_identity` table: id, name, sourceType, chainType, createdAt, isActive, chainId, starknetAccountType
- `derived_address` table: walletId, chain, path, address

Checklist:
- [ ] No secret material (mnemonic, private key) in any SQLite column
- [ ] Public addresses are fine to store — they are not secrets
- [ ] Database path: `ApplicationSupport/wallets.sqlite3`

## Test Fixtures

- Only use well-known Anvil/Hardhat test keys in tests and previews:
  - Private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
  - Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
  - Mnemonic: `"test test test test test test test test test test test junk"`
- [ ] Never commit real keys, seeds, or `.env` files
- [ ] `.gitignore` already excludes `note/` and `docs/` — verify sensitive scratch files stay out

## Dependency Isolation

All external I/O goes through `@Dependency` clients. This is a security boundary:

| Client | Live touches | Test stub |
|--------|-------------|-----------|
| `WalletClient` | Keychain + SQLite + crypto signing (owns `WalletDataSource`) | returns fixed test identity |
| `BiometricClient` | `LAContext` biometric prompt | returns success (or configurable) |
| `EvmProviderClient` / `StarknetProviderClient` | network RPC | returns a real provider (no secret exposure) |
| `ChainRegistryClient` | SQLite chain list | in-memory stub |
| `BalanceClient` / `PriceClient` / `ERC20Client` / `SendClient` / `TransactionHistoryClient` | network RPC / HTTP | safe stubs |

Note: there is no dedicated `KeychainClient`. Keychain access is fully owned by `WalletClient` → `WalletDataSource` → `WalletSecretDataSource` → `KeychainService`; reducers must not reach past `WalletClient`. UserDefaults access uses `@Shared(.appStorage(...))` from TCA, not a DI client.

Checklist:
- [ ] Never call `KeychainService` directly from a reducer — always go through `WalletClient`
- [ ] Never call `SecItemAdd` / `SecItemCopyMatching` outside `KeychainService`
- [ ] `testValue` stubs must never touch real Keychain or network

## Input Validation

- [ ] Mnemonic validated via `BIP39.validate()` before import — see `WalletClient.importMnemonic`
- [ ] Private key hex normalized via `PrivateKeyUtils.normalizePrivateKey(hex:)` — see `WalletClient.importPrivateKey`
- [ ] Ethereum addresses validated via `EthereumAddress()` initializer (returns nil on invalid) — see `Send.swift`
- [ ] RPC URLs must start with `https://` — see `Settings.swift` validation

## Network

- [ ] RPC URLs are `https://` only — no plain HTTP
- [ ] No API keys hardcoded in source — use configuration or environment if needed later
- [ ] Transaction signing happens locally via `EthereumSigner` / `StarknetSigner` — private keys never leave the device

## Code Review Red Flags

Reject any change that:
1. Adds `print` / logging of variables that could contain key material
2. Stores secrets in `State` properties that flow into SwiftUI views (except guarded mnemonic backup)
3. Weakens Keychain accessibility (e.g. `kSecAttrAccessibleAlways`)
4. Bypasses `@Dependency` to call Keychain or network directly from a reducer
5. Adds HTTP (non-TLS) endpoints
6. Commits real private keys, mnemonics, or API secrets
7. Disables or skips `BIP39.validate()` or address validation
