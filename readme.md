# Green Energy Farm Smart Contract

A Clarity smart contract that enables investment in renewable energy generators and earning carbon credits based on energy production. Built for the Stacks blockchain ecosystem.

## Overview

The Green Energy Farm contract creates a decentralized platform where users can invest in various types of renewable energy generators (Solar Panels, Wind Turbines, Hydroelectric systems) and earn carbon credits over time based on their investment and the efficiency of the generators.

## Features

- **Multiple Generator Types**: Support for Solar Panels, Wind Turbines, and Hydroelectric generators
- **Investment System**: Users can invest carbon credits in specific generators
- **Credit Earning**: Automatic calculation of credits earned based on time, investment, and generator efficiency
- **Emergency Shutdown**: Safety mechanism for emergency withdrawals with loss penalties
- **Admin Controls**: Maintenance mode and generator management
- **Input Validation**: Comprehensive validation for all user inputs

## Token Economics

- **Token**: `carbon-credit` (Fungible Token)
- **Initial Supply**: 750,000 credits minted to admin
- **Credits per kWh**: 5 credits (configurable)
- **Emergency Shutdown Loss**: 12% penalty during emergency exits

## Generator Types

| Type | Efficiency | Credit Rate | Description |
|------|------------|-------------|-------------|
| Solar Panel | 3 | 85 | Basic solar energy generation |
| Wind Turbine | 6 | 125 | Wind-powered energy generation |
| Hydroelectric | 9 | 170 | Water-powered energy generation |

## Smart Contract Functions

### Public Functions

#### `setup-energy-farm()`
Initializes the energy farm with default generators and mints initial token supply.
- **Access**: Admin only
- **Returns**: `(ok true)` on success

#### `install-generator(type-name, efficiency, credit-rate)`
Installs a new energy generator type.
- **Parameters**:
  - `type-name`: String (max 25 chars) - Name of the generator type
  - `efficiency`: uint (1-100) - Generator efficiency rating
  - `credit-rate`: uint (1-1000) - Credit earning rate
- **Access**: Admin only
- **Returns**: Generator ID on success

#### `invest-in-energy(gen-id, investment)`
Invest carbon credits in a specific generator.
- **Parameters**:
  - `gen-id`: uint - Generator ID to invest in
  - `investment`: uint - Amount of credits to invest
- **Returns**: `(ok true)` on success
- **Side Effects**: Transfers credits, updates capacity, distributes pending credits

#### `divest-from-energy(gen-id, amount)`
Withdraw investment from a generator.
- **Parameters**:
  - `gen-id`: uint - Generator ID to divest from
  - `amount`: uint - Amount to withdraw
- **Returns**: `(ok true)` on success
- **Side Effects**: Distributes pending credits, returns investment

#### `emergency-shutdown-exit(gen-id)`
Emergency withdrawal during maintenance mode (with penalty).
- **Parameters**:
  - `gen-id`: uint - Generator ID to exit from
- **Access**: Only during maintenance mode
- **Returns**: Amount withdrawn after penalty
- **Penalty**: 12% loss of invested amount

#### `toggle-maintenance(active)`
Enable/disable maintenance mode.
- **Parameters**:
  - `active`: bool - Maintenance mode status
- **Access**: Admin only
- **Returns**: New maintenance status

### Read-Only Functions

#### `get-investment-status(investor, gen-id)`
Get investment details for a specific investor and generator.
- **Parameters**:
  - `investor`: principal - Investor address
  - `gen-id`: uint - Generator ID
- **Returns**: `{invested-amount: uint, last-harvest-block: uint}`

#### `get-generator-details(gen-id)`
Get details about a specific generator.
- **Parameters**:
  - `gen-id`: uint - Generator ID
- **Returns**: Generator details or `none`

#### `get-farm-overview()`
Get overall farm statistics.
- **Returns**: `{total-capacity: uint, maintenance-mode: bool, generator-types: uint}`

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u101 | ERR-UNAUTHORIZED-USER | User lacks required permissions |
| u102 | ERR-INSUFFICIENT-INVESTMENT | Investment amount too low or exceeds holdings |
| u103 | ERR-NO-INVESTMENT-FOUND | No investment found for user/generator |
| u104 | ERR-GENERATOR-OFFLINE | Generator is currently offline |
| u105 | ERR-INVALID-GENERATOR | Invalid generator ID |
| u106 | ERR-INVALID-EFFICIENCY | Efficiency must be 1-100 |
| u107 | ERR-INVALID-CREDIT-RATE | Credit rate must be 1-1000 |
| u108 | ERR-EMPTY-TYPE-NAME | Generator type name cannot be empty |

## Credit Calculation

Credits are calculated using the formula:
```
credits = (invested_amount × blocks_producing × credits_per_kwh × credit_rate) / (total_capacity × 100)
```

Where:
- `blocks_producing`: Blocks since last harvest
- `credits_per_kwh`: Base credit rate (default: 5)
- `credit_rate`: Generator-specific multiplier
- `total_capacity`: Total investment in the generator

## Usage Example

```clarity
;; Setup the farm (admin only)
(contract-call? .green-energy-farm setup-energy-farm)

;; Invest 1000 credits in solar panels (generator ID 0)
(contract-call? .green-energy-farm invest-in-energy u0 u1000)

;; Check investment status
(contract-call? .green-energy-farm get-investment-status tx-sender u0)

;; Divest 500 credits
(contract-call? .green-energy-farm divest-from-energy u0 u500)
```

## Security Features

- **Input Validation**: All inputs are validated before processing
- **Access Control**: Admin functions restricted to contract deployer
- **Safe Math**: Overflow protection through Clarity's built-in safety
- **Emergency Mechanisms**: Maintenance mode for emergency situations

## Development

### Prerequisites
- Clarity CLI
- Stacks blockchain testnet access

### Testing
Test all functions with various input combinations, including edge cases:
- Invalid generator IDs
- Zero or excessive investment amounts
- Emergency shutdown scenarios
- Multiple investments and divestments

### Deployment
1. Deploy to Stacks testnet first
2. Verify all functions work correctly
3. Run security audits
4. Deploy to mainnet
