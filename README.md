# Sheltrix 🏠

## Homeless Shelter Escrow System

Sheltrix is a blockchain-based escrow platform built on the Stacks network that facilitates secure funding for homeless shelters by releasing funds only upon verified care delivery. The system creates transparency and accountability in homeless assistance funding, ensuring donations reach their intended beneficiaries and shelters are properly compensated for their services.

## 🌟 Overview

The Sheltrix ecosystem uses smart contracts to create a trustless escrow mechanism between donors, shelters, and verification authorities. Funds are held securely until care services are verified, creating a transparent and efficient funding model for homeless assistance programs.

## 🚀 Core Features

### Escrow Management
- **Secure Fund Holding**: Donations held in smart contract escrow until verified
- **Multi-Party System**: Supports donors, shelters, and verification authorities
- **Automated Release**: Funds released automatically upon care verification
- **Dispute Resolution**: Built-in mechanisms for handling disputes and refunds

### Care Verification
- **Service Documentation**: Track meals, shelter nights, medical care, and social services
- **Multiple Verifiers**: Support for authorized verification entities
- **Timestamped Records**: Immutable records of all care activities
- **Performance Metrics**: Track shelter performance and care outcomes

### Transparency & Accountability
- **Public Ledger**: All transactions recorded on blockchain
- **Donation Tracking**: Complete audit trail from donation to care delivery
- **Impact Reporting**: Real-time metrics on funds distributed and care provided
- **Community Oversight**: Public verification of shelter activities

## 🛠️ Technical Architecture

### Blockchain Infrastructure
- **Platform**: Stacks Blockchain with Bitcoin security
- **Smart Contracts**: Clarity programming language
- **Consensus**: Proof-of-Transfer (PoX) consensus mechanism
- **Security**: Bitcoin-level security for all transactions

### Contract System
1. **Shelter Registry (`shelter-registry.clar`)**
   - Shelter registration and verification
   - Capacity management and service offerings
   - Performance tracking and ratings
   - Compliance monitoring and status updates

2. **Escrow Manager (`escrow-manager.clar`)**
   - Donation collection and escrow management
   - Care verification and fund release
   - Dispute handling and resolution
   - Automated payment processing

### Data Models
- **Shelter Profile**: Registration details, capacity, services, verification status
- **Escrow Agreement**: Donor, shelter, amount, terms, verification requirements
- **Care Record**: Service type, beneficiary count, verification status, timestamp
- **Transaction History**: Complete audit trail of all fund movements

## 🔧 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet/) development environment
- Node.js and npm for testing
- Stacks wallet for interaction (Hiro Wallet recommended)

### Development Setup
```bash
# Clone the repository
git clone https://github.com/dogobarau633/sheltrix.git
cd sheltrix

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test

# Deploy to testnet
clarinet deploy --testnet
```

### Basic Usage
```clarity
;; Register a shelter
(contract-call? .shelter-registry register-shelter 
    "Downtown Shelter" 
    u100 ;; capacity
    "Meals, beds, medical care")

;; Create donation escrow
(contract-call? .escrow-manager create-escrow 
    'SP1234...SHELTER-PRINCIPAL
    u1000000 ;; 1 STX
    "Monthly meal service")

;; Verify care delivery
(contract-call? .escrow-manager verify-care 
    u1 ;; escrow-id
    u50 ;; people served
    "Provided 150 meals to 50 individuals")
```

## 🎯 Use Cases

### For Donors
- **Transparent Giving**: See exactly how donations are used
- **Verified Impact**: Receive proof of care delivery before funds release
- **Tax Documentation**: Immutable records for tax deduction purposes
- **Recurring Donations**: Set up automated monthly giving programs

### For Shelters
- **Guaranteed Payment**: Receive funds immediately upon care verification
- **Reduced Bureaucracy**: Streamlined funding process with fewer intermediaries
- **Performance Tracking**: Build reputation through verified care delivery
- **Predictable Income**: Secure funding commitments for operational planning

### For Verification Authorities
- **Efficient Oversight**: Digital tools for monitoring and verification
- **Standardized Reporting**: Consistent metrics across all shelters
- **Real-time Monitoring**: Immediate visibility into shelter operations
- **Compliance Tracking**: Automated compliance reporting and alerts

### For Beneficiaries
- **Service Guarantee**: Assurance that funding is tied to actual care delivery
- **Quality Standards**: Verified shelters meet minimum service requirements
- **Data Privacy**: Personal information protected while services are tracked
- **Consistent Care**: Funding structure incentivizes reliable service provision

## 💰 Economic Model

### Funding Structure
- **Escrow Deposits**: Donors deposit funds into time-locked escrows
- **Verification Requirements**: Clear criteria for fund release
- **Performance Incentives**: Bonus payments for exceeding care targets
- **Dispute Resolution**: Fair arbitration process for disagreements

### Fee Structure
- **Platform Fee**: Minimal fee (1-2%) for system maintenance
- **Verification Fee**: Small fee for third-party verification services
- **Transaction Costs**: Standard Stacks network fees apply
- **Emergency Fund**: Reserve fund for disputed transactions

## 🔐 Security Features

### Smart Contract Security
- **Access Control**: Role-based permissions for different user types
- **Escrow Protection**: Funds locked until verification criteria are met
- **Multi-signature**: Multiple approval requirements for large transactions
- **Audit Trail**: Complete transaction history stored on blockchain

### Data Protection
- **Privacy Preserving**: Personal beneficiary data kept confidential
- **Aggregate Reporting**: Public metrics without individual identification
- **Secure Verification**: Cryptographic proofs for care delivery
- **GDPR Compliance**: European data protection standards followed

## 🌐 Social Impact

### Measurable Outcomes
- **People Served**: Track number of individuals receiving care
- **Services Provided**: Monitor meals, shelter nights, medical visits
- **Fund Efficiency**: Measure percentage of donations reaching beneficiaries
- **Shelter Performance**: Rate shelters based on care delivery metrics

### Community Benefits
- **Increased Donations**: Transparency encourages more giving
- **Better Services**: Performance incentives improve care quality
- **Reduced Fraud**: Verification requirements prevent misuse of funds
- **Data-Driven Policy**: Provide evidence for policy decisions

### Long-term Vision
- **Scale Globally**: Expand to homeless services worldwide
- **Government Integration**: Partner with public assistance programs
- **Corporate Partnerships**: Engage businesses in systematic giving
- **Research Platform**: Generate data for homelessness research

## 🤝 Contributing

We welcome contributions to the Sheltrix project! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with comprehensive tests
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines
- Follow Clarity best practices for smart contract development
- Include comprehensive tests for all new functionality
- Update documentation for any API changes
- Ensure all contracts pass `clarinet check` validation

## 📊 Project Status

- ✅ **Smart Contract Architecture**: Core escrow and registry contracts designed
- ✅ **Verification System**: Multi-party verification with dispute resolution
- ✅ **Donation Management**: Secure escrow with automated fund release
- 🔄 **Testing Suite**: Comprehensive test coverage in development
- 🔄 **Web Interface**: User-friendly interface for all stakeholders
- 📅 **Mainnet Launch**: Planned deployment after thorough testing

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Resources

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [National Alliance to End Homelessness](https://endhomelessness.org/)
- [Homeless Services Research](https://www.hudexchange.info/)

## 📞 Support & Community

- **GitHub Issues**: [Report bugs and request features](https://github.com/dogobarau633/sheltrix/issues)
- **Community Forum**: Join our Discord community for discussions
- **Email Support**: contact@sheltrix.org
- **Twitter**: [@SheltrixOrg](https://twitter.com/SheltrixOrg)

## 🏆 Recognition

Sheltrix addresses UN Sustainable Development Goals:
- **Goal 1**: No Poverty
- **Goal 3**: Good Health and Well-being  
- **Goal 11**: Sustainable Cities and Communities
- **Goal 16**: Peace, Justice and Strong Institutions

---

**Building a transparent, accountable future for homeless assistance through blockchain technology. Every donation counts, every verification matters. 🏠**
