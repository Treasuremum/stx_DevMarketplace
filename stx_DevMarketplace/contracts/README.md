# STX Development Marketplace

A decentralized marketplace built on the Stacks blockchain connecting clients with specialized STX/Bitcoin developers.

##  Overview

The STX Development Marketplace is a Clarity smart contract that facilitates secure, milestone-based development projects within the Stacks ecosystem. It features developer staking, escrow payments, and reputation tracking to ensure quality deliverables.

##  Key Features

### For Clients
- **Post Development Projects** with specific skill requirements
- **Milestone-Based Payments** released as work progresses
- **Developer Applications** with proposals and timelines
- **Escrow Protection** with automatic payment release
- **Review System** to rate developer performance

### For Developers
- **Skill-Based Matching** across 8 STX/Bitcoin specializations
- **Reputation Building** through completed projects
- **Stake-to-Earn** model ensuring commitment
- **Portfolio Tracking** of deployed contracts and earnings
- **Dispute Resolution** for project disagreements

### Core Specializations
- Clarity Smart Contract Development
- Bitcoin Integration
- DeFi Protocol Building
- NFT Marketplace Creation
- Web3 Frontend Development
- Stacks API Development
- Ordinals Development
- Lightning Network Integration

##  Architecture

### Smart Contract Components
- **Projects**: Core project management with milestone tracking
- **Developer Profiles**: Reputation, skills, and earnings history
- **Applications**: Developer proposal system
- **Milestones**: Granular payment and deliverable tracking
- **Disputes**: Structured conflict resolution

### Key Parameters
- Platform fee: 3% (300 basis points)
- Minimum developer stake: 1 STX
- Milestone limit: 10 per project
- Difficulty levels: 1-5 scale
- Reputation tiers: Beginner → Expert

##  Getting Started

### Deploying the Contract
```bash
clarinet deploy --testnet
```

### Creating a Project
```clarity
(contract-call? .stx-dev-marketplace create-project
  u5000000  ;; 5 STX payment
  "DeFi Lending Protocol"
  "Build a secure lending protocol with liquidation mechanics"
  (list "defi-protocol" "clarity-dev")
  u4  ;; difficulty level
  u1440  ;; ~1 week in blocks
  u3)  ;; 3 milestones
```

### Developer Application
```clarity
(contract-call? .stx-dev-marketplace apply-for-project
  u1  ;; project ID
  "I have 3 years experience building DeFi on Stacks..."
  u1200  ;; proposed timeline
  u1000000)  ;; 1 STX stake
```

##  Functions Reference

### Core Functions
- `create-project()` - Post a new development project
- `apply-for-project()` - Developer applies with proposal
- `accept-developer()` - Client accepts application
- `complete-milestone()` - Developer completes work milestone
- `submit-review()` - Client reviews completed work
- `raise-dispute()` - Initiate dispute resolution

### Read-Only Functions
- `get-project()` - Retrieve project details
- `get-developer-profile()` - View developer stats
- `get-platform-stats()` - Marketplace metrics
- `get-developer-reputation-tier()` - Reputation level

##  Security Features

- **Input Validation**: Comprehensive parameter checking
- **Access Control**: Role-based function restrictions
- **Escrow System**: Automatic fund holding and release
- **Stake Requirements**: Developer commitment mechanism
- **Dispute Resolution**: Structured conflict handling

##  Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://docs.stacks.co/build-apps/references/stacks-cli)

### Testing
```bash
clarinet test
```

### Local Development
```bash
clarinet integrate
```

##  Roadmap

- [ ] Advanced search and filtering
- [ ] Automated milestone verification
- [ ] Integration with GitHub for code verification
- [ ] Multi-sig escrow for large projects
- [ ] DAO governance for dispute resolution
- [ ] Cross-chain Bitcoin integration features

##  Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

