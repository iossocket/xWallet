# Testing Rules — xWallet

## Framework

- Swift Testing (`import Testing`) — not XCTest
- TCA `TestStore` from `import ComposableArchitecture`
- All test structs marked `@MainActor`

## Test File Layout

```swift
import ComposableArchitecture
import Testing

@testable import xWallet

@MainActor
struct FeatureNameTests {
    @Test
    func descriptiveBehaviorName() async {
        let store = TestStore(initialState: FeatureName.State(...)) {
            FeatureName()
        } withDependencies: {
            $0.someClient.someMethod = { ... }
        }

        await store.send(.someAction) {
            $0.someProperty = expectedValue
        }
        await store.receive(\.responseAction.success) {
            $0.resultProperty = expectedResult
        }
    }
}
```

## Checklist — Every New Reducer

- [ ] Test file created at `xWalletTests/<FeatureName>Tests.swift`
- [ ] Test struct name matches `<FeatureName>Tests`
- [ ] `@MainActor` on the struct
- [ ] `@testable import xWallet`

## Checklist — Every Test Method

- [ ] Annotated with `@Test` (not `func test...()` XCTest convention — though descriptive names still fine)
- [ ] `async` — all `TestStore` interactions are async
- [ ] `TestStore` created with explicit initial state
- [ ] Dependencies overridden via `withDependencies:` — never hit real Keychain, network, or DB
- [ ] `store.send(action)` trailing closure asserts all state mutations exhaustively
- [ ] `store.receive(\.action)` used for every effect-produced action — TCA fails if unhandled
- [ ] No `try!` or force-unwraps in tests — use `throws` or safe stubs

## Dependency Overrides

Override only what the test exercises. Existing `testValue` stubs are safe defaults:

```swift
// KeychainClient.testValue: saveData no-ops, loadData throws .itemNotFound
// WalletClient.testValue: returns a fixed test identity
// KeyValueStorageClient.testValue: save no-ops, load returns nil
```

Override specific closures when testing their behavior:

```swift
withDependencies: {
    $0.keychain.saveData = { _, _ in throw KeychainError.unexpectedStatus(-1) }
}
```

## Test Patterns in This Repo

| Pattern | Example |
|---------|---------|
| Happy path | `AccountTests.importSuccess` — send action, receive success response, assert state |
| Error path | `AccountTests.importFailure` — override dep to throw, assert error message |
| Sync state toggle | `WalletTests.toggleShowBalance` — send, assert, no effects |
| Guard / early return | `WalletTests.refreshWithoutAddressDoesNothing` — send with nil address, assert loading state only |
| Async RPC | `SettingsTests.checkConnectionSuccess` — override RPC client, send, receive response |
| Validation | `SettingsTests.invalidURLPreventsCheck` — no dep override needed, assert sync failure |

## Test Data

- Use well-known Anvil/Hardhat test keys: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- Use deterministic UUIDs: `UUID(uuidString: "00000000-0000-0000-0000-000000000001")!`
- Never use real private keys or mnemonics

## Running Tests

```bash
# Command line
xcodebuild -project xWallet.xcodeproj -scheme xWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Xcode
Cmd+U
```
