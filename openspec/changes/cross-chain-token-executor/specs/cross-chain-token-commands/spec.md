## ADDED Requirements

### Requirement: Cross-chain command menu
`ChainOp<R>` SHALL provide factory commands forming a uniform menu. The cross-chain group SHALL include: `.balance(of: ERC20Token, owner: String) -> BigUInt`, `.transfer(_ token: ERC20Token, to: String, amount: BigUInt, from: any Account) -> TxHash`, `.metadata(of: ERC20Token) -> TokenMetadata`, `.nativeBalance(owner: String, chain: Chain) -> BigUInt`, `.sendNative(to: String, amount: BigUInt, from: any Account) -> TxHash`, `.estimateFee(SendRequest, from: any Account) -> FeeEstimate`, `.waitForConfirmation(txHash: String, chain: Chain) -> TxResult`. Each command SHALL carry its `Response` type so `execute` returns it directly.

#### Scenario: Balance command returns a typed amount
- **WHEN** a reducer executes `.balance(of: token, owner: addr)`
- **THEN** the result SHALL be a `BigUInt`
- **AND** the token's chain SHALL be resolved from `token.chainId`

#### Scenario: Transfer command returns a tx hash
- **WHEN** a reducer executes `.transfer(token, to:, amount:, from: account)`
- **THEN** the result SHALL be a `TxHash`
- **AND** the executor SHALL produce an ERC-20 `transfer` contract write on the token's chain

### Requirement: Token operations are thin wrappers over SDK Contract
`.balance`, `.transfer`, and `.metadata` SHALL be implemented by mapping to SDK `Contract.read`/`readSingle`/`write`, with the contract method name and `ContractArg` chosen per chain (e.g. `balanceOf` on EVM, `balance_of` on Starknet).

#### Scenario: Balance reuses SDK contract read
- **WHEN** `.balance` executes on an EVM token
- **THEN** the executor SHALL call `EthereumContract.readSingle(method: "balanceOf", args: [.address(owner)])`
- **AND** on a Starknet token it SHALL call `StarknetContract.readSingle(method: "balance_of", args: [.contractAddress(owner)])`
- **AND** SHALL NOT reintroduce a separate `balance_of` implementation in the provider layer

### Requirement: Native operations are sibling commands, not special-case branches
`.nativeBalance` and `.sendNative` SHALL exist as first-class commands. Callers SHALL NOT branch on "is native" — they select the native command directly. The executor SHALL implement native per chain (EVM via `eth_getBalance` / plain value transaction; Starknet via the well-known native token contract, since Starknet has no non-contract native token).

#### Scenario: Native balance on EVM uses eth_getBalance
- **WHEN** `.nativeBalance(owner:, chain:)` executes on an EVM chain
- **THEN** the executor SHALL query the native balance via the provider RPC (`eth_getBalance`), not a contract call

#### Scenario: Sending native does not require chain branching at the call site
- **WHEN** a reducer sends the native coin
- **THEN** it SHALL execute `.sendNative(to:, amount:, from:)`
- **AND** SHALL NOT contain an `if native` branch

### Requirement: Deploy-family commands are capability-gated at compile time
The deploy group SHALL include `.isDeployed(address: String, chain: Chain) -> Bool`, `.estimateDeployFee(account: any DeployableAccount) -> FeeEstimate`, `.deploy(account: any DeployableAccount) -> TxHash`. The signing commands (`.estimateDeployFee`/`.deploy`) SHALL take `any DeployableAccount` so that accounts which are not deployable cannot be passed. `.isDeployed` is a read-only status query and SHALL be address-based: constructing a `StarknetAccount` requires the private key (biometric-gated Keychain load), which MUST NOT be required for a status check at app launch / wallet switch.

#### Scenario: Deploy with a Starknet (deployable) account compiles
- **WHEN** a reducer executes `.deploy(account: starknetAccount)` where the account conforms to `DeployableAccount`
- **THEN** it SHALL compile and execute the account deployment

#### Scenario: Deploy with an EVM account fails to compile
- **WHEN** code attempts `.deploy(account: ethereumAccount)` where `EthereumAccount` is not a `DeployableAccount`
- **THEN** it SHALL fail to compile
- **AND** no runtime "unsupported chain" check SHALL be required

#### Scenario: Deploy status check requires no key material
- **WHEN** a reducer executes `.isDeployed(address:, chain:)` for a Starknet address
- **THEN** the executor SHALL query deployment status via provider RPC (class hash lookup)
- **AND** no private key SHALL be loaded and no biometric prompt SHALL be triggered

### Requirement: ERC20Client removed; chain-specific RPC types absorbed
`ERC20Client` SHALL be removed (it is dead code). `StarknetRPCService` SHALL be dissolved into commands (deploy group + `getBalance` → `.balance`) and then removed or narrowed. `SendClient`'s `send`/`estimateFee`/`waitForConfirmation` SHALL be expressed as commands. The contract-read logic in `EvmBalanceProvider`/`StarknetBalanceProvider` SHALL be served by `.balance`.

#### Scenario: No remaining references to ERC20Client
- **WHEN** the change is complete
- **THEN** `grep -rn "ERC20Client" xWallet/ xWalletTests/` SHALL return no results
- **AND** the file `xWallet/Services/ERC20Client.swift` SHALL NOT exist

#### Scenario: AccountDeploy reducer uses executor commands
- **WHEN** the `AccountDeploy` reducer needs balance / fee / deploy / confirmation
- **THEN** it SHALL call `chain.execute(.balance / .estimateDeployFee / .deploy / .waitForConfirmation)`
- **AND** SHALL NOT reference `starknetRPCService` directly
