## ADDED Requirements

### Requirement: Handle personal_sign requests
The system SHALL process personal_sign requests from DApps and return ECDSA signatures.

#### Scenario: Sign text message
- **WHEN** DApp sends personal_sign request with message "Hello World" and user address
- **THEN** system displays signature request sheet with message content
- **WHEN** user taps "Sign"
- **THEN** system signs message with user's private key and returns signature to DApp

#### Scenario: Reject signing request
- **WHEN** user receives personal_sign request and taps "Reject"
- **THEN** system sends rejection response to DApp
- **THEN** system dismisses request sheet

#### Scenario: Sign request for wrong address
- **WHEN** DApp sends personal_sign request for address not owned by user
- **THEN** system displays error "Address not found in wallet"
- **THEN** system automatically rejects request

### Requirement: Handle eth_signTypedData_v4 requests
The system SHALL process EIP-712 typed data signing requests from DApps.

#### Scenario: Sign structured data
- **WHEN** DApp sends eth_signTypedData_v4 request with EIP-712 payload
- **THEN** system displays signature request sheet with structured data preview
- **WHEN** user taps "Sign"
- **THEN** system signs typed data according to EIP-712 spec and returns signature

#### Scenario: Display typed data fields
- **WHEN** user receives eth_signTypedData_v4 request
- **THEN** system displays domain (name, version, chainId), primary type, and message fields
- **THEN** user can review all fields before signing

#### Scenario: Invalid typed data format
- **WHEN** DApp sends malformed EIP-712 payload
- **THEN** system displays error "Invalid typed data format"
- **THEN** system automatically rejects request

### Requirement: Handle eth_sendTransaction requests
The system SHALL process transaction sending requests from DApps.

#### Scenario: Send native token transaction
- **WHEN** DApp sends eth_sendTransaction with to, value, and chainId
- **THEN** system displays transaction confirmation sheet with recipient, amount, and estimated gas
- **WHEN** user taps "Confirm"
- **THEN** system signs and broadcasts transaction, returns transaction hash to DApp

#### Scenario: Send contract interaction transaction
- **WHEN** DApp sends eth_sendTransaction with to, data, and chainId
- **THEN** system displays transaction confirmation with contract address and decoded function call (if possible)
- **WHEN** user taps "Confirm"
- **THEN** system signs and broadcasts transaction

#### Scenario: Insufficient balance for transaction
- **WHEN** DApp requests transaction but user has insufficient balance for value + gas
- **THEN** system displays error "Insufficient balance"
- **THEN** system allows user to reject or cancel

#### Scenario: Transaction on wrong chain
- **WHEN** DApp sends transaction request for chainId not in active session
- **THEN** system displays error "Chain not connected"
- **THEN** system automatically rejects request

### Requirement: Handle Starknet signing requests
The system SHALL process Starknet SNIP-12 typed data signing requests.

#### Scenario: Sign Starknet typed data
- **WHEN** DApp sends starknet_signTypedData request with SNIP-12 payload
- **THEN** system displays signature request sheet with Starknet domain and message
- **WHEN** user taps "Sign"
- **THEN** system signs with Starknet account and returns signature array

#### Scenario: Starknet account not deployed
- **WHEN** DApp sends signing request but user's Starknet account is not deployed
- **THEN** system displays warning "Account not deployed on Starknet"
- **THEN** system allows user to proceed with signing (counterfactual signature)

### Requirement: Handle Starknet transaction requests
The system SHALL process Starknet execute (invoke) requests from DApps.

#### Scenario: Execute Starknet transaction
- **WHEN** DApp sends starknet_execute request with contract calls array
- **THEN** system displays transaction confirmation with contract addresses and entry points
- **WHEN** user taps "Confirm"
- **THEN** system executes via StarknetAccount.executeV3 and returns transaction hash

#### Scenario: Multi-call transaction
- **WHEN** DApp sends starknet_execute with multiple calls (e.g., approve + swap)
- **THEN** system displays all calls in confirmation sheet
- **THEN** user can review each call before confirming

### Requirement: Request timeout handling
The system SHALL enforce timeout limits on pending DApp requests.

#### Scenario: Request expires after 5 minutes
- **WHEN** user receives signing or transaction request
- **WHEN** user does not respond within 5 minutes
- **THEN** system automatically rejects request with "Request timeout"
- **THEN** system dismisses request sheet

#### Scenario: Multiple pending requests
- **WHEN** DApp sends multiple requests in quick succession
- **THEN** system queues requests and displays them one at a time
- **THEN** each request has independent 5-minute timeout

### Requirement: Display request context
The system SHALL display relevant context for each DApp request to help users make informed decisions.

#### Scenario: Show DApp identity
- **WHEN** user receives any request (sign or transaction)
- **THEN** system displays DApp name, icon, and URL at top of confirmation sheet
- **THEN** user can verify request source before approving

#### Scenario: Show estimated gas for transactions
- **WHEN** user receives eth_sendTransaction or starknet_execute request
- **THEN** system estimates gas cost and displays in native token (ETH/STRK)
- **THEN** system displays total cost (value + gas) in confirmation sheet

#### Scenario: Decode contract calls
- **WHEN** user receives transaction with contract interaction
- **THEN** system attempts to decode function signature and parameters
- **THEN** system displays decoded data if available, raw hex otherwise
