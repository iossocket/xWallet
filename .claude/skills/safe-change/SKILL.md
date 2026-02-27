# Skill: Safe Change

Gate checklist for any code modification in xWallet. Run through this before committing.

## Risk Classification

Classify the change, then follow the matching track:

| Risk | Description | Examples |
|------|-------------|----------|
| Low | Single reducer case, view-only tweak, test addition | Add action case, adjust padding, new test |
| Medium | New dependency client, new feature reducer, DB migration | Add `TokenClient`, new `Swap` reducer |
| High | Keychain logic, signing flow, WalletStorage actor, delete operations | Change `saveSecret`, modify signer calls |

## Pre-Change Checklist (all changes)

- [ ] Read every file you plan to modify — no blind edits
- [ ] Confirm change follows `.claude/rules/code-style.md` (reducer structure, action naming, design tokens)
- [ ] Confirm change follows `.claude/rules/security.md` (no secret leaks, dependency isolation)
- [ ] Diff is minimal — no drive-by refactors, no added comments to unchanged code

## Medium Risk — Additional Gates

- [ ] New reducer has `@ObservableState` State, Action enum, `@Dependency` declarations, `body` with `Reduce`
- [ ] New dependency client provides `liveValue` + `testValue` + `DependencyValues` registration
- [ ] New test file created at `xWalletTests/<Feature>Tests.swift` per `.claude/rules/testing.md`
- [ ] Tests cover: happy path, error path, and at least one edge case
- [ ] If adding a DB migration in `WalletStorage.migrator`: migration is additive (new table/column), not destructive

## High Risk — Mandatory Human Review

Stop and request explicit human approval before applying any change that:

1. Modifies `KeychainService` or `kSecAttr*` parameters
2. Modifies `WalletStorage.saveSecret` / `loadSecret` / `deleteSecret`
3. Changes `EthereumSigner` or `StarknetSigner` usage (signing, key derivation)
4. Alters `BIP39.validate()` or `PrivateKeyUtils.normalizePrivateKey` call sites
5. Adds a new `kSecAttrAccessible` value or changes the existing one
6. Deletes wallet data (`deleteIdentity`, `deleteSecret`, `deleteWallet`)
7. Introduces any new network endpoint or changes RPC URL handling

Present to the reviewer:
- Exact diff (no surrounding "cleanup")
- Which security checklist items from `.claude/rules/security.md` are affected
- New or modified tests covering the change

## Testing Requirements

Every change must pass before merge:

```bash
xcodebuild -project xWallet.xcodeproj -scheme xWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

| Change type | Minimum test coverage |
|-------------|----------------------|
| New reducer action | `@Test` for the new case (send + assert state) |
| New async effect | `@Test` for success + failure paths (send + receive) |
| New dependency client | `testValue` stub + at least one `TestStore` test using it |
| Bug fix | Regression test that fails without the fix |
| View-only change | No new test required (but build must succeed) |

## Post-Change Verification

- [ ] `xcodebuild test` passes (or Cmd+U green)
- [ ] `git diff` shows only intended files — no accidental changes
- [ ] No new warnings introduced in Xcode build output
- [ ] If Keychain/signing was touched: re-run security red flags from `.claude/rules/security.md`
