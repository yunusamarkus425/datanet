# DataNet - Tokenized Data Marketplace 🗂️

A decentralized marketplace built on Stacks blockchain where users can securely buy, sell, and trade digital data using tokenized transactions.

## Overview

DataNet enables data providers to list their datasets for sale while maintaining control and security. Buyers can purchase access to data using marketplace tokens, creating a trustless environment for data commerce.

## System Architecture

### Core Components

1. **Data Marketplace Contract** (`data-marketplace.clar`)
   - Manages data listings and metadata
   - Handles purchase transactions
   - Tracks ownership and access rights
   - Implements pricing and revenue sharing

2. **Token Manager Contract** (`token-manager.clar`)
   - Manages marketplace token economy
   - Handles token minting and burning
   - Controls token transfers and balances
   - Implements staking mechanisms

## Key Features

### Data Listings
- **Secure Data Registration**: Data providers can list datasets with metadata
- **Access Control**: Granular permissions for data access
- **Pricing Models**: Flexible pricing including one-time purchase and subscription
- **Category System**: Organized data classification

### Token Economy
- **DataNet Tokens (DNT)**: Native marketplace currency
- **Staking Rewards**: Earn tokens by providing quality data
- **Transaction Fees**: Network fee distribution to stakeholders
- **Governance Rights**: Token holders participate in platform decisions

### Security Features
- **Data Integrity**: Cryptographic verification of data authenticity
- **Privacy Protection**: Zero-knowledge proofs for sensitive data previews
- **Dispute Resolution**: Built-in arbitration system
- **Access Logging**: Complete audit trail of data access

## Smart Contract Functions

### Data Marketplace Functions

#### For Data Providers
- `list-data`: Register new dataset for sale
- `update-data-price`: Modify pricing for existing listings
- `deactivate-listing`: Remove data from marketplace
- `withdraw-earnings`: Claim revenue from sales

#### For Data Buyers
- `purchase-data-access`: Buy access to specific dataset
- `extend-subscription`: Renew time-based access
- `get-data-details`: View public metadata
- `verify-access`: Check current access permissions

#### For Marketplace
- `get-all-listings`: Retrieve active data listings
- `get-data-by-category`: Filter listings by category
- `get-provider-stats`: View provider performance metrics
- `calculate-fees`: Determine transaction costs

### Token Manager Functions

#### Token Operations
- `mint-tokens`: Create new tokens (admin only)
- `transfer-tokens`: Send tokens between users
- `burn-tokens`: Remove tokens from circulation
- `get-balance`: Check token balance

#### Staking System
- `stake-tokens`: Lock tokens for rewards
- `unstake-tokens`: Withdraw staked tokens
- `claim-rewards`: Collect staking rewards
- `get-staking-info`: View staking details

## Data Types and Structures

### Data Listing
```clarity
{
  id: uint,
  provider: principal,
  title: (string-ascii 100),
  category: (string-ascii 50),
  price: uint,
  access-type: (string-ascii 20),
  is-active: bool,
  created-at: uint,
  total-sales: uint
}
```

### Access Record
```clarity
{
  buyer: principal,
  data-id: uint,
  purchased-at: uint,
  expires-at: (optional uint),
  access-granted: bool
}
```

### Token Balance
```clarity
{
  owner: principal,
  balance: uint,
  staked: uint,
  rewards: uint
}
```

## Usage Examples

### Listing Data for Sale
```clarity
;; List a dataset for $100 in tokens
(contract-call? .data-marketplace list-data 
  "Financial Market Analysis Q3 2024"
  "finance"
  u10000  ;; 100.00 tokens (2 decimal places)
  "one-time")
```

### Purchasing Data Access
```clarity
;; Buy access to data listing #1
(contract-call? .data-marketplace purchase-data-access u1)
```

### Staking Tokens for Rewards
```clarity
;; Stake 500 tokens
(contract-call? .token-manager stake-tokens u50000)
```

## Economic Model

### Revenue Streams
- **Transaction Fees**: 2.5% on all data purchases
- **Listing Fees**: Small fee to prevent spam listings
- **Premium Features**: Enhanced analytics and priority placement

### Token Distribution
- **Data Providers**: 70% of purchase price
- **Platform Fee**: 25% for platform maintenance
- **Stakers Rewards**: 5% distributed to token stakers

### Incentive Structure
- **Quality Bonuses**: Higher rewards for highly-rated datasets
- **Volume Discounts**: Reduced fees for high-volume traders
- **Loyalty Program**: Benefits for long-term platform users

## Security Considerations

### Data Protection
- Metadata only stored on-chain
- Actual data stored off-chain with access controls
- Cryptographic proofs verify data integrity
- Time-limited access prevents unauthorized sharing

### Smart Contract Security
- Input validation on all public functions
- Overflow protection on arithmetic operations
- Access control for administrative functions
- Emergency pause functionality for critical issues

## Getting Started

### Prerequisites
- Stacks wallet with STX for gas fees
- DataNet tokens (DNT) for transactions
- Data to sell or STX/DNT to purchase data

### For Data Providers
1. Prepare your dataset with metadata
2. Acquire DNT tokens for listing fees
3. Call `list-data` function with details
4. Monitor sales and withdraw earnings

### For Data Buyers
1. Browse available data listings
2. Acquire sufficient DNT tokens
3. Purchase data access
4. Download data using provided access keys

## Development and Testing

### Local Development
```bash
# Check contract syntax
clarinet check

# Run tests
npm test

# Deploy to testnet
clarinet deploy --testnet
```

### Contract Deployment
The contracts are designed to be deployed independently:
1. Deploy `token-manager.clar` first
2. Deploy `data-marketplace.clar` with token manager reference
3. Initialize marketplace with admin functions

## Roadmap

### Phase 1 (Current)
- [x] Core marketplace functionality
- [x] Token management system
- [x] Basic access controls
- [x] Simple pricing models

### Phase 2 (Next)
- [ ] Advanced search and filtering
- [ ] Reputation system for providers
- [ ] Subscription-based pricing
- [ ] Data preview functionality

### Phase 3 (Future)
- [ ] Cross-chain compatibility
- [ ] AI-powered data recommendations
- [ ] Automated data quality scoring
- [ ] Integration with external data sources

## Contributing

We welcome contributions to DataNet! Please see our contribution guidelines and submit pull requests for improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**DataNet** - Democratizing data access through blockchain technology 🌐