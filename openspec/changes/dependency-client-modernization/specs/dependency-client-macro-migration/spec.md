## ADDED Requirements

### Requirement: Clients use @DependencyClient macro
The following 6 clients SHALL be annotated with `@DependencyClient`: `BiometricClient`, `ChainRegistryClient`, `ERC20Client`, `PriceClient`, `SendClient`, `TransactionHistoryClient`. The hand-written `testValue` property SHALL be removed from each client.

#### Scenario: Macro generates testValue with unimplemented stubs
- **WHEN** a test creates a `TestStore` without overriding a client method
- **AND** the reducer dispatches an action that calls that method
- **THEN** the test SHALL fail with an "unimplemented" error from the macro-generated stub

#### Scenario: Existing test overrides continue to work
- **WHEN** a test overrides a specific closure via `withDependencies`
- **THEN** the overridden closure SHALL be called instead of the unimplemented stub
- **AND** the test SHALL pass without modification (beyond removing any testValue-related code)

### Requirement: Non-Void closures have default values
Every closure property on a `@DependencyClient`-annotated struct that returns a non-`Void` type SHALL have a default value. The default value SHALL be the zero/empty value for that type (e.g., `[]` for arrays, `.unknown` for enums).

#### Scenario: Client compiles with macro
- **WHEN** the `@DependencyClient` macro expands on a client struct
- **AND** all non-Void closures have default values
- **THEN** the project SHALL compile without errors

### Requirement: No separate DependenciesMacros linking needed
`ComposableArchitecture` re-exports `DependenciesMacros`. Client files SHALL use `import ComposableArchitecture` only — no `import DependenciesMacros` required.

### Requirement: Excluded clients remain unchanged
`WalletClient`, `AppDateClient`, `EvmProviderClient`, `StarknetProviderClient`, and `WalletConnectClient` SHALL NOT be modified by this change.

#### Scenario: WalletClient keeps hand-written testValue
- **WHEN** the migration is complete
- **THEN** `WalletClient` SHALL still have a manually written `testValue` with fixture data
