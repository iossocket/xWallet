## ADDED Requirements

### Requirement: ChainClient dependency
A `ChainClient` SHALL be registered as `@Dependency(\.chain)` in `xWallet/Services/`. It SHALL expose a single generic method `execute<R>(_ op: ChainOp<R>) async throws -> R`. Reducers SHALL invoke all cross-chain operations through this method.

#### Scenario: Reducer resolves the executor via dependency
- **WHEN** a reducer declares `@Dependency(\.chain) var chain`
- **THEN** it SHALL obtain a `ChainClient` value
- **AND** it SHALL invoke operations only via `chain.execute(...)`, not by constructing chain providers/contracts directly

#### Scenario: Executor returns the command's typed result
- **WHEN** `execute` is called with a `ChainOp<R>`
- **THEN** the returned value SHALL be of type `R`
- **AND** the caller SHALL NOT need to unwrap an intermediate result enum

### Requirement: Runtime chain dispatch is centralized
The `ChainClient` SHALL be the single place that branches on chain at runtime. It SHALL resolve the target chain from the command (e.g. `ERC20Token.chainId`, account type) and dispatch to one of: SDK `Contract<C>` (contract read/write), SDK `Provider` (native), or SDK `DeployableAccount<C>` (deploy). No other layer SHALL contain a `switch chain { evm / starknet }`.

#### Scenario: Contract command dispatches to the right Contract type
- **WHEN** a contract-backed command (`.balance`/`.transfer`/`.metadata`) is executed
- **THEN** the executor SHALL construct an `EthereumContract` for EVM chainIds or a `StarknetContract` for Starknet chainIds
- **AND** call the SDK `Contract.read`/`readSingle`/`write` on it

#### Scenario: Adding a new chain does not change callers
- **WHEN** support for a new chain is added
- **THEN** only the executor dispatch SHALL gain a branch
- **AND** no reducer or command call site SHALL require modification

### Requirement: ContractArg maps to chain-native value types
A `ContractArg` enum SHALL provide cross-chain call arguments with cases `.address(String)`, `.uint256(BigUInt)`, `.bool(Bool)`, `.bytes(Data)`. The executor SHALL map `ContractArg` to the SDK `Contract.Value` of the target chain: `ABIValue` for EVM, `CairoValue` for Starknet.

#### Scenario: uint256 maps to chain-specific encoding
- **WHEN** a `.uint256(amount)` argument is dispatched to EVM
- **THEN** it SHALL map to `ABIValue.uint(bits: 256, value:)`
- **AND** when dispatched to Starknet it SHALL map to `CairoValue.u256(low:high:)` splitting the value

#### Scenario: address maps to chain-specific encoding
- **WHEN** a `.address(addr)` argument is dispatched to EVM
- **THEN** it SHALL map to `ABIValue.address(EthereumAddress)`
- **AND** when dispatched to Starknet it SHALL map to `CairoValue.contractAddress(Felt)`

### Requirement: Executor is testable per command
`ChainClient.testValue` SHALL allow tests to override execution per command kind without hitting real RPC. Reducer tests SHALL stub command results at the executor layer.

#### Scenario: Test overrides a command result
- **WHEN** a test overrides the executor so that `.balance` returns a fixed value
- **AND** a reducer dispatches `.balance`
- **THEN** the reducer SHALL receive the fixed value
- **AND** no network request SHALL be made
