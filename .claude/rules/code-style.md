# Code Style Rules — xWallet

## Reducer Structure

Every feature follows this exact layout:

```swift
@Reducer
struct FeatureName {
    @ObservableState
    struct State: Equatable { ... }

    enum Action { ... }

    @Dependency(\.someClient) var someClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // ...
            }
        }
    }
}
```

Checklist:

- [ ] State is a `struct` marked `@ObservableState` and conforms to `Equatable`
- [ ] Action is a plain `enum` (add `BindableAction` only when using `BindingReducer()`)
- [ ] Dependencies declared as `@Dependency` properties before `body`
- [ ] `body` uses `Reduce { state, action in ... }` — not a bare closure
- [ ] Child reducers composed via `Scope(state:action:)` or `.ifLet(\.$child, action: \.child)`
- [ ] Async responses modeled as `case someResponse(Result<T, Error>)`

## Action Naming

Follow the existing conventions exactly:

- User interactions: `verbNounTapped` — e.g. `createWalletTapped`, `refreshButtonTapped`
- Async responses: `verbNounResponse(Result<T, Error>)` — e.g. `balanceResponse`, `checkResponse`
- State setters: `setPropertyName(Value)` — e.g. `setShowBalance(Bool)`
- Input changes: `propertyNameChanged(Value)` — e.g. `rpcURLChanged(String)`, `mnemonicInputChanged(String)`
- Lifecycle: `onAppear`
- Child actions: `childName(ChildReducer.Action)` — e.g. `account(Account.Action)`

## Dependency Client Pattern

```swift
struct SomeClient {
    var doThing: @Sendable (Input) async throws -> Output
}

extension SomeClient: DependencyKey {
    static var liveValue: SomeClient { ... }
    static var testValue: SomeClient { ... }   // required
}

extension DependencyValues {
    var someClient: SomeClient {
        get { self[SomeClient.self] }
        set { self[SomeClient.self] = newValue }
    }
}
```

Checklist:

- [ ] Client is a `struct` with closure properties (not a protocol)
- [ ] All closures marked `@Sendable`
- [ ] `liveValue` uses real implementations
- [ ] `testValue` provides safe stubs (no-ops or throws)
- [ ] Registered on `DependencyValues` via computed property

## Dependency

- [ ] `@Dependency` only appears inside `@Reducer` structs — never inside `liveValue`, `testValue`, or other dependency clients
- [ ] Dependency clients must NOT reference other dependency clients — if `ClientA.liveValue` needs `ClientB`, that is a design smell; refactor so the reducer orchestrates both clients instead
- [ ] When tempted to compose dependencies, move the coordination logic into the reducer's `Effect` and pass the needed values as closure parameters

## SwiftUI Views

```swift
struct SomeView: View {
    @Bindable var store: StoreOf<SomeReducer>   // or let store:
    var body: some View { ... }
}
```

Checklist:

- [ ] Use `@Bindable var store` when the view needs bindings, `let store` otherwise
- [ ] Colors: `Color.xBg0`, `Color.xAccent`, `Color.xTextPrimary`, etc. — never hardcoded hex
- [ ] Fonts: `Font.xTitle1`, `Font.xBody`, `Font.xMono`, etc. — never `.system(size:)` directly
- [ ] Spacing: `XSpacing.sm`, `XSpacing.lg`, etc. — never magic numbers for padding
- [ ] Radii: `XRadius.md`, `XRadius.xl`, etc.
- [ ] Animations: `Animation.xStandard`, `.xSnappy`, etc.
- [ ] Cards: `.xCard()` for glass, `.xSolidCard()` for solid dark
- [ ] Addresses and hashes displayed with `Font.xMono` or `Font.xMonoSm`

## File Header

```swift
//
//  FileName.swift
//  xWallet
//
//  Created by Name on DD/M/YY.
//
```

## General

- No SwiftLint or SwiftFormat configured — follow existing code style by example
- 4-space indentation
- `import` statements: `Foundation`/`SwiftUI` first, then `ComposableArchitecture`, then domain packages (`EthereumKit`, `MultiChainKit`, etc.)
- Prefer `let` over `var` for immutable state
- Enums that cross module boundaries: conform to `String, Codable, Equatable, Sendable`
- Model structs: conform to `Equatable, Sendable` (add `Codable` if persisted)
