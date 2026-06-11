## ADDED Requirements

### Requirement: BalanceClient exposes fetchPortfolio stream
`BalanceClient` SHALL have a new closure property `fetchPortfolio: @Sendable (ActiveWalletIdentitySet, [Chain]) -> AsyncStream<PortfolioUpdate>`. The stream SHALL yield intermediate results as data becomes available.

#### Scenario: Stream yields balances then complete portfolio
- **WHEN** `fetchPortfolio` is called with a valid identity set and chains
- **THEN** the stream SHALL first yield `.balancesLoaded([ChainBalance])`
- **AND** then yield `.complete([ChainBalance], [String: Double])` with balances and prices
- **AND** then finish

#### Scenario: Balance fetch fails
- **WHEN** `fetchPortfolio` is called and the balance fetch fails
- **THEN** the stream SHALL yield `.failed(Error)`
- **AND** then finish

#### Scenario: Prices fetch fails gracefully
- **WHEN** balances are fetched successfully but price fetch fails
- **THEN** the stream SHALL yield `.balancesLoaded([ChainBalance])`
- **AND** then yield `.complete([ChainBalance], [:])` with empty prices
- **AND** then finish

### Requirement: PortfolioUpdate enum
A `PortfolioUpdate` enum SHALL be defined with cases: `.balancesLoaded([ChainBalance])`, `.complete([ChainBalance], [String: Double])`, `.failed(Error)`.

#### Scenario: PortfolioUpdate is Sendable
- **WHEN** `PortfolioUpdate` is used across concurrency boundaries
- **THEN** it SHALL conform to `Sendable`

### Requirement: Wallet reducer uses fetchPortfolio
The Wallet reducer SHALL replace the `fetchAllBalances → allBalancesResponse → fetchPrices → pricesResponse` action chain with a single `fetchPortfolio` effect that iterates the `AsyncStream`.

#### Scenario: Refresh triggers portfolio stream
- **WHEN** user taps refresh (or on initial load after chains are loaded)
- **THEN** the reducer SHALL call `balanceClient.fetchPortfolio(identitySet, chains)` in a `.run` effect
- **AND** dispatch `.portfolioUpdate(PortfolioUpdate)` for each yielded value

#### Scenario: Balances loaded updates state
- **WHEN** reducer receives `.portfolioUpdate(.balancesLoaded(balances))`
- **THEN** `state.chainBalances` SHALL be updated
- **AND** `state.isLoadingAllChains` SHALL remain `true`

#### Scenario: Complete updates state with prices and assets
- **WHEN** reducer receives `.portfolioUpdate(.complete(balances, prices))`
- **THEN** `state.chainBalances`, `state.prices` SHALL be updated
- **AND** `state.rebuildAssets()` SHALL be called
- **AND** `state.isLoadingAllChains` SHALL be set to `false`

#### Scenario: Failed updates error state
- **WHEN** reducer receives `.portfolioUpdate(.failed(error))`
- **THEN** `state.errorMessage` SHALL be set
- **AND** `state.isLoadingAllChains` SHALL be set to `false`
