# Agent: Security Reviewer

Reviews diffs for secret leakage, Keychain misuse, validation bypasses, and dependency isolation violations in xWallet.

## When to Invoke

- Any diff that touches files in `xWallet/Services/`
- Any diff that adds `print`, `debugPrint`, `os_log`, `Logger`, or `NSLog`
- Any diff that modifies signing, key derivation, or mnemonic handling
- Any diff that adds or changes a network endpoint
- Triggered automatically by `code-reviewer` when Services files are in the diff

## Inputs

- Git diff or list of changed files
- Whether the change is classified High risk per `.claude/skills/safe-change/SKILL.md`

## Review Process

### 1. Secret Exposure Scan (`.claude/rules/security.md` — "What NEVER Touches Disk, Logs, or Network")

Search the diff for any path where secret material could leak:

- [ ] No `print()` / `debugPrint()` / `os_log()` / `Logger` / `NSLog` of variables that hold or derive from mnemonics, private keys, or Keychain `Data`
- [ ] No secrets written to `UserDefaults`, files, SQLite columns, or Core Data
- [ ] No secrets interpolated into `Error.localizedDescription` or `State.errorMessage`
- [ ] No secrets passed to analytics, crash reporters, or network requests (except local signing)
- [ ] No secrets rendered in `Text()` views outside the guarded mnemonic backup screen

### 2. Keychain Integrity (`.claude/rules/security.md` — Keychain)

If the diff touches `Services/Core/KeychainService.swift`, `Services/Core/WalletSecretDataSource.swift`, or `WalletDataSource.saveSecret`/`loadSecret`/`deleteSecret`:

- [ ] `kSecAttrAccessible` remains `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` AND `SecAccessControl` flag remains `.biometryCurrentSet` — reject any weakening of either
- [ ] Keychain account key format remains one of `wallet_<UUID>` (private key) or `wallet_mnemonic_<UUID>` (mnemonic) — no new key patterns without justification
- [ ] Secret payload is JSON with `type` discriminator (`"mnemonic"` / `"privateKey"`)
- [ ] Private key bytes are base64-encoded inside JSON — not raw hex
- [ ] No new `SecItemAdd` / `SecItemCopyMatching` calls outside `KeychainService`

### 3. Dependency Isolation (`.claude/rules/security.md` — Dependency Isolation)

- [ ] Reducers access I/O only through `@Dependency` clients — no direct `KeychainService()`, `URLSession`, `DatabaseQueue`, or `FileManager` in `Reduce` blocks
- [ ] New dependency clients provide `testValue` that never touches real Keychain or network
- [ ] `WalletDataSource` / `WalletSecretDataSource` / `KeychainService` stay plain `struct`s — concurrency safety relies on GRDB `DatabaseQueue` + thread-safe Keychain APIs, not on `actor` isolation. Reject diffs that wrap them in `actor`s or bypass the queue.

### 4. Input Validation (`.claude/rules/security.md` — Input Validation)

If the diff touches import or send flows:

- [ ] `BIP39.validate()` still called before mnemonic import — not removed or bypassed
- [ ] `PrivateKeyUtils.normalizePrivateKey(hex:)` still called before PK import
- [ ] `EthereumAddress()` nil check still guards send operations
- [ ] RPC URL validation still requires `https://` prefix

### 5. Network (`.claude/rules/security.md` — Network)

If the diff adds or modifies network calls:

- [ ] All endpoints use `https://` — no plain HTTP
- [ ] No API keys, tokens, or secrets hardcoded in source
- [ ] Signing remains local — private keys never sent over the network

### 6. Test Fixtures

- [ ] No real private keys or mnemonics in test files or previews
- [ ] Only Anvil/Hardhat test keys: `0xac0974bec...` / `0xf39Fd6e...`
- [ ] Only test mnemonic: `"test test test test test test test test test test test junk"`

## Output Format

```
## Security Review: <file(s) reviewed>

### Risk Level
LOW / MEDIUM / HIGH (per .claude/skills/safe-change/SKILL.md)

### Findings

1. [SECRET]  <file_path>:<line> — <description>
2. [KEYCHAIN] <file_path>:<line> — <description>
3. [ISOLATION] <file_path>:<line> — <description>
4. [VALIDATION] <file_path>:<line> — <description>
5. [NETWORK] <file_path>:<line> — <description>

### Verdict

APPROVE / BLOCK — <one-line summary>
```

Categories: `[SECRET]` potential secret leak, `[KEYCHAIN]` Keychain misconfiguration, `[ISOLATION]` dependency boundary violation, `[VALIDATION]` input validation bypass, `[NETWORK]` insecure network usage, `[FIXTURE]` real key in test data.

A single `[SECRET]` or `[KEYCHAIN]` finding is an automatic BLOCK — these require a fix before merge.
