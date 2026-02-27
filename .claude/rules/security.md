# Security Rules — xWallet

## Keychain — Private Key & Mnemonic Storage

The only authorized store for secrets is iOS Keychain via `KeychainService` in `xWallet/Services/KeychainService.swift`.

Checklist:
- [ ] Accessibility level is `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — never weaken
- [ ] Keychain keys follow the pattern `wallet_<UUID>` — see `WalletStorage.saveSecret`
- [ ] Secrets are JSON-encoded with a `type` discriminator (`"mnemonic"` / `"privateKey"`) before storage
- [ ] Private key bytes are base64-encoded inside the JSON payload, never stored as raw hex
- [ ] `WalletStorage` is an `actor` — all Keychain + SQLite access is serialized and concurrency-safe

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

`WalletStorage` in `xWallet/Services/WalletClient.swift` stores wallet metadata in `wallets.sqlite3`:
- `wallet_identity` table: id, name, sourceType, chainType, createdAt, isActive
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
| `KeychainClient` | iOS Keychain | no-op save, throws on load |
| `WalletClient` | Keychain + SQLite + crypto signing | returns fixed test identity |
| `EvmProviderClient` | network RPC | returns a real provider (no secret exposure) |
| `KeyValueStorageClient` | `UserDefaults` | no-op save, nil load |

Checklist:
- [ ] Never call `KeychainService` directly from a reducer — always go through `KeychainClient`
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
