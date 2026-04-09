## ADDED Requirements

### Requirement: Pair with DApp via URI
The system SHALL allow users to initiate pairing with a DApp by providing a WalletConnect URI (wc:...).

#### Scenario: Valid URI pairing
- **WHEN** user inputs a valid WalletConnect v2 URI and taps "Connect"
- **THEN** system establishes pairing and awaits session proposal from DApp

#### Scenario: Invalid URI format
- **WHEN** user inputs an invalid URI format
- **THEN** system displays error message "Invalid WalletConnect URI"

#### Scenario: Pairing timeout
- **WHEN** pairing is initiated but DApp does not respond within 30 seconds
- **THEN** system displays error message "Connection timeout"

### Requirement: Approve session proposal
The system SHALL present session proposals from DApps and allow users to approve or reject them.

#### Scenario: Approve proposal with required chains
- **WHEN** user receives a session proposal requesting supported chains (e.g., eip155:1, eip155:11155111)
- **THEN** system displays DApp name, icon, URL, and requested chains
- **WHEN** user taps "Connect"
- **THEN** system approves the session with user's wallet addresses for requested chains

#### Scenario: Reject proposal
- **WHEN** user receives a session proposal and taps "Reject"
- **THEN** system sends rejection response to DApp and dismisses proposal sheet

#### Scenario: Proposal with unsupported chains
- **WHEN** DApp requests chains not supported by wallet (e.g., eip155:56 when BSC is disabled)
- **THEN** system displays warning "Some requested chains are not available" and allows partial approval

### Requirement: Persist active sessions
The system SHALL maintain a list of active WalletConnect sessions across app restarts.

#### Scenario: Session survives app restart
- **WHEN** user has an active WalletConnect session and closes the app
- **THEN** session remains active when app is reopened
- **THEN** system can receive and process requests from that session

#### Scenario: Display active sessions
- **WHEN** user navigates to DApp Connect tab
- **THEN** system displays list of all active sessions with DApp name, icon, and connection time

### Requirement: Disconnect session
The system SHALL allow users to manually disconnect from a DApp session.

#### Scenario: User-initiated disconnect
- **WHEN** user taps disconnect button on an active session
- **THEN** system sends disconnect notification to DApp
- **THEN** system removes session from active sessions list

#### Scenario: DApp-initiated disconnect
- **WHEN** DApp sends disconnect request
- **THEN** system removes session from active sessions list
- **THEN** system displays notification "Disconnected from [DApp name]"

### Requirement: Handle multiple concurrent sessions
The system SHALL support multiple active WalletConnect sessions simultaneously.

#### Scenario: Multiple sessions from different DApps
- **WHEN** user connects to multiple DApps (e.g., Uniswap, OpenSea, Aave)
- **THEN** system maintains all sessions independently
- **THEN** each DApp can send requests without interfering with others

#### Scenario: Session isolation
- **WHEN** user approves a transaction for DApp A
- **THEN** only DApp A receives the response
- **THEN** other active sessions are unaffected
