# Agent: Debugger

Diagnoses runtime failures, test failures, and unexpected behavior in xWallet reducers and dependencies.

## When to Invoke

- A test fails or produces unexpected state
- A reducer action doesn't produce the expected effect or state mutation
- A dependency client throws an unexpected error
- Build succeeds but runtime behavior is wrong

## Inputs

- Symptom: what's wrong (test failure message, unexpected UI state, crash log)
- Location: file path + action/method if known
- Steps to reproduce (if available)

## Diagnosis Process

### 1. Isolate the Layer

Determine where the bug lives:

| Symptom | Likely layer | Start here |
|---------|-------------|------------|
| `TestStore` state mismatch | Reducer logic | `xWallet/Features/<Area>/<Area>.swift` |
| `TestStore` received unexpected action | Missing effect or wrong `.send`/`.receive` | Same reducer, check `.run` blocks |
| `TestStore` missing received action | Effect fires but test doesn't `store.receive` | Test file — add missing `receive` |
| Dependency throws at runtime | Client `liveValue` | `xWallet/Services/<Client>.swift` |
| Keychain error `-25300` | Item not found | `Services/Core/KeychainService.swift` — check account key format `wallet_<UUID>` (private key) or `wallet_mnemonic_<UUID>` (mnemonic) built by `WalletSecretDataSource` |
| SQLite error | Migration or query | Migrator in `Services/Core/DatabaseService.swift`; queries in `Services/Core/WalletDataSource.swift` / `ChainDataSource.swift` |
| UI doesn't update | State not mutated or view not observing | Reducer case returns `.none` too early, or view uses `let` instead of `@Bindable` |

### 2. Read Before Guessing

- Read the failing test file in `xWalletTests/`
- Read the reducer under test in `xWallet/Features/<Area>/<Area>.swift`
- If a dependency is involved, read its `liveValue` and `testValue` in `xWallet/Services/`
- Check `AppFeature.swift` if the bug involves cross-feature state (e.g., account success → wallet address)

### 3. Reproduce Minimally

Write or modify a `@Test` that isolates the exact failing path:

```swift
@Test
func isolatedFailureCase() async {
    let store = TestStore(initialState: <minimal state>) {
        FeatureName()
    } withDependencies: {
        // Override only the relevant dependency
    }

    await store.send(.triggeringAction) {
        // Assert expected state — this should fail and show the actual vs expected
    }
}
```

Follow `.claude/rules/testing.md` for structure and dependency overrides.

### 4. Trace the Action Path

For TCA reducer bugs, trace the full action chain:

1. Which action is sent?
2. Which `case` in the `switch` handles it?
3. What state mutations happen?
4. Does it return `.none` or `.run`/`.send`?
5. If `.run` — what does the closure do? What action does it `send` back?
6. Is there a `Scope` or parent reducer that intercepts the child action? (Check `AppFeature.swift`)

### 5. Common Pitfalls in This Codebase

| Pitfall | Where to look |
|---------|--------------|
| Shared state (`@Shared(.activeIdentitySet)`) read while empty → early `.none` return | Features that depend on an active wallet — `Wallet.swift`, `Send.swift`. Check the `guard` against `activeIdentitySet.evm` / `.starknet` |
| Parent reducer handles child success before child does | `AppFeature.swift` — `.account(.switchWalletResponse(.success))` / `.settings(.importAccount(.presented(...)))` drive launch-phase transitions |
| Address validation returns `nil` silently | `Send.swift` — `sendClient.validateAddress(state.toAddress, state.chain)` guard; also `EthereumAddress(...)` initializers elsewhere |
| `WalletClient` closures are `@Sendable async throws` — forgetting `await` / `try` fails silently in `.run { }` | `WalletClient.swift` — call sites in reducers must `try await walletClient.xxx(...)` |
| `testValue` stub doesn't match test expectations | Override only the closures the test exercises via `withDependencies:`; defaults throw or return fixed identity |

## Output Format

```
## Debug Report

### Symptom
<one-line description>

### Root Cause
<file_path>:<line> — <explanation of why the bug happens>

### Evidence
<relevant code snippet or test output showing the failure>

### Fix
<minimal diff description — what to change and where>

### Regression Test
<@Test method that fails without the fix and passes with it>

### Verification
xcodebuild test — PASS / FAIL
```

## Constraints

- Do not modify code outside the buggy path — follow `.claude/rules/code-style.md`
- Do not weaken or skip validation — follow `.claude/rules/security.md`
- Every fix must include a test — follow `.claude/rules/testing.md`
