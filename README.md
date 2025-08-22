# Labordao - Union Voting DAO

A decentralized autonomous organization (DAO) smart contract for labor union voting and decision-making on the Stacks blockchain.

## Overview

Labordao enables union members to create and vote on labor-related proposals such as wage increases, working conditions, strikes, and other collective decisions. The contract implements a democratic voting system with customizable quorum requirements and voting periods.

## Features

- **Member Management**: Join union with position and voting power
- **Proposal Creation**: Create labor-related proposals with descriptions
- **Democratic Voting**: Members vote for/against proposals with weighted voting power  
- **Quorum System**: Configurable minimum participation requirements
- **Time-based Voting**: Configurable voting periods in blocks
- **Proposal Execution**: Execute passed proposals after voting ends
- **Admin Controls**: Owner can manage member status and system parameters

## Contract Functions

### Read-Only Functions

- `get-proposal(proposal-id)` - Get proposal details
- `get-member(member-id)` - Get member information  
- `get-member-by-address(address)` - Find member by wallet address
- `get-vote(proposal-id, member-id)` - Get specific vote details
- `is-proposal-active(proposal-id)` - Check if proposal is still accepting votes
- `get-proposal-results(proposal-id)` - Get voting results and outcome

### Public Functions

#### Member Functions
- `join-union(union-position, voting-power)` - Join the union as a member
- `vote-on-proposal(proposal-id, vote-for)` - Vote on an active proposal

#### Proposal Functions  
- `create-proposal(title, description, proposal-type)` - Create new proposal
- `execute-proposal(proposal-id)` - Execute a passed proposal

#### Admin Functions (Contract Owner Only)
- `update-member-status(member-id, active)` - Enable/disable member
- `set-min-quorum(new-quorum)` - Update minimum quorum requirement
- `set-voting-period(new-period)` - Update voting period in blocks
- `emergency-pause-member(member-address)` - Emergency disable member

## Usage Examples

### 1. Join the Union
```clarity
(contract-call? .Labordao join-union "Shop Steward" u5)
```

### 2. Create a Proposal
```clarity
(contract-call? .Labordao create-proposal 
    "5% Wage Increase" 
    "Proposal to increase all union member wages by 5% effective next quarter"
    "wages")
```

### 3. Vote on Proposal
```clarity
(contract-call? .Labordao vote-on-proposal u1 true)
```

### 4. Execute Passed Proposal
```clarity
(contract-call? .Labordao execute-proposal u1)
```

## Configuration

- **Default Voting Period**: 144 blocks (~24 hours)
- **Default Minimum Quorum**: 10 votes
- **Proposal Types**: wages, conditions, strikes, benefits, policies

## Error Codes

- `u1000` - Unauthorized access
- `u1001` - Proposal not found
- `u1002` - Member not found  
- `u1003` - Already voted
- `u1004` - Proposal voting ended
- `u1005` - Proposal voting not ended
- `u1006` - Insufficient votes to pass
- `u1007` - Already a member
- `u1008` - Invalid proposal type
- `u1009` - Invalid voting period

## Testing

Run the test suite:
```bash
npm test
```

## Deployment

Deploy using Clarinet:
```bash
clarinet deploy
```
