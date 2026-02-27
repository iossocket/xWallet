# Skill: Fix Issue

Systematic workflow for diagnosing and fixing a bug in xWallet.

## Required Inputs

- Bug description (what's wrong, expected vs actual behavior)
- Affected feature area (Account, Wallet, Send, Settings, or Shared)
- Reproduction steps (if available)

## Workflow

### 1. Locate

- Identify the reducer in `xWallet/Features/<Area>/<Area>.swift`
- If the bug involves a dependency, check `xWallet/Services/<Client>.swift`
- If the bug is visual, check the corresponding view files in the same feature folder
- Read the relevant file(s) before proposing any change

### 2. Reproduce in a Test

Write a failing test FIRST in `xWalletTests/<Area>Tests.swift` that captures the bug:

```swift
@Test
func descriptiveBugName() async {
    let store = TestStore(initialState: ...) {
        FeatureName()
    } withDependencies: { ... }

    // Actions that trigger the bug
    await store.send(.action) {
        $0.property = expectedCorrectValue  // this will fail until fixed
    }
}
```

Follow `.claude/rules/testing.md` for test structure, dependency overrides, and test data.

### 3. Fix

- Change the minimum code necessary — one reducer case, one guard, one dependency method
- Follow `.claude/rules/code-style.md` for naming, structure, and patterns
- Run `.claude/rules/security.md` "Code Review Red Flags" checklist against your diff
- Do NOT refactor, rename, or "improve" surrounding code

### 4. Verify

Run all tests:

```bash
xcodebuild -project xWallet.xcodeproj -scheme xWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Checklist before declaring done:
- [ ] New test reproduces the original bug (fails without the fix)
- [ ] New test passes with the fix
- [ ] All existing tests still pass
- [ ] Diff touches only the buggy code path + the new test
- [ ] No secrets logged or exposed (`.claude/rules/security.md`)
- [ ] Design tokens used if any view changes (`.claude/rules/code-style.md` — SwiftUI Views)

## Required Outputs

1. Root cause — one sentence explaining why the bug happened
2. Diff — minimal change to production code
3. Test — at least one new `@Test` method proving the fix
4. Test run — passing output from `xcodebuild test` or Cmd+U
