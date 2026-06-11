## ADDED Requirements

### Requirement: WalletClient exposes activeChainAccount
`WalletClient` SHALL have a new closure property `activeChainAccount: @Sendable (Chain) async throws -> ChainAccount`. The `liveValue` implementation SHALL resolve the active wallet identity and construct the appropriate `ChainAccount` (EVM or Starknet) with the correct provider, matching the logic currently in `Send.swift`'s file-private `resolveChainAccount` function.

#### Scenario: Resolve EVM chain account
- **WHEN** `activeChainAccount` is called with an EVM chain
- **THEN** it SHALL return `.evm(EthereumAccount, EthereumProvider)` for the active EVM identity

#### Scenario: Resolve Starknet chain account
- **WHEN** `activeChainAccount` is called with a Starknet chain
- **THEN** it SHALL return `.starknet(StarknetAccount, StarknetProvider)` for the active Starknet identity

#### Scenario: No active identity for chain type
- **WHEN** `activeChainAccount` is called with a chain type that has no active identity
- **THEN** it SHALL throw `WalletError.chainMismatch`

### Requirement: Send reducer uses walletClient.activeChainAccount
`Send.swift` SHALL use `walletClient.activeChainAccount(chain)` instead of the file-private `resolveChainAccount` function. The file-private function SHALL be deleted.

#### Scenario: Estimate fee resolves account via client
- **WHEN** user taps estimate fee in Send
- **THEN** the reducer SHALL call `walletClient.activeChainAccount(chain)` to obtain the `ChainAccount`
- **AND** pass it to `sendClient.estimateFee`

#### Scenario: Confirm send resolves account via client
- **WHEN** user confirms send
- **THEN** the reducer SHALL call `walletClient.activeChainAccount(chain)` to obtain the `ChainAccount`
- **AND** pass it to `sendClient.send`
