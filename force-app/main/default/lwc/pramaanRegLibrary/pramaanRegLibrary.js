import { LightningElement, track } from 'lwc';

const REGULATORS = [
    {
        key: 'RBI',
        name: 'RBI',
        fullName: 'Reserve Bank of India',
        clauses: 51,
        icon: 'standard:currency',
        focus: 'IT governance, cyber security, digital lending, outsourcing, data localisation',
        description: 'Primary regulator for banks, NBFCs, and payment system operators. RBI mandates comprehensive IT governance, cyber security frameworks, and strict controls on AI-driven lending and customer-facing automation.',
        regulations: [
            'Master Direction on IT Governance, Risk, Controls & Assurance (2023)',
            'Digital Lending Guidelines (2022)',
            'Outsourcing of Financial Services Directions',
            'Cyber Security Framework for Banks',
            'KYC Master Direction (2016, updated 2023)',
            'Framework for Authorisation of Payment Systems'
        ],
        appliesTo: 'SCB, SFB, Payments Bank, NBFC Upper, NBFC Middle, NBFC Base, HFC',
        color: 'rbi'
    },
    {
        key: 'MeitY',
        name: 'MeitY',
        fullName: 'Ministry of Electronics & Information Technology',
        clauses: 12,
        icon: 'standard:data_model',
        focus: 'DPDP Act 2023, data protection, consent management, breach notification, data fiduciary duties',
        description: 'Governs digital personal data protection across all sectors. The DPDP Act 2023 introduces consent-based processing, data fiduciary obligations, and significant penalties for non-compliance.',
        regulations: [
            'Digital Personal Data Protection Act 2023 (DPDP)',
            'IT Act 2000 — Section 43A (Reasonable Security Practices)',
            'IT (Reasonable Security Practices) Rules 2011',
            'DPDP Rules — Consent Manager Framework',
            'Data Localisation Requirements'
        ],
        appliesTo: 'All entities processing personal data of Indian data principals',
        color: 'meity'
    },
    {
        key: 'SEBI',
        name: 'SEBI',
        fullName: 'Securities & Exchange Board of India',
        clauses: 4,
        icon: 'standard:investment_account',
        focus: 'Algo trading controls, cyber resilience, market intermediary technology risk management',
        description: 'Regulates capital market intermediaries including brokers, AMCs, and depositories. SEBI mandates cyber resilience frameworks and strict controls on algorithmic/AI-driven trading systems.',
        regulations: [
            'Cyber Security & Cyber Resilience Framework (2023)',
            'Algorithmic Trading Circular (2012, updated 2023)',
            'Technology Risk Management Guidelines for Market Infrastructure Institutions'
        ],
        appliesTo: 'AMC, Broker, Market Infrastructure Institutions',
        color: 'sebi'
    },
    {
        key: 'IRDAI',
        name: 'IRDAI',
        fullName: 'Insurance Regulatory & Development Authority of India',
        clauses: 4,
        icon: 'standard:entitlement',
        focus: 'AI/ML in insurance underwriting, fair pricing, claim settlement automation, product suitability',
        description: 'Regulates insurance companies and intermediaries. IRDAI has issued specific guidance on AI/ML usage in underwriting, pricing, and claims — requiring explainability and fairness safeguards.',
        regulations: [
            'IRDAI AI/ML Usage Guidelines (2024)',
            'IRDAI IT Governance Guidelines',
            'IRDAI Outsourcing Guidelines',
            'Insurance Product Suitability Framework'
        ],
        appliesTo: 'Insurer, Insurance Intermediaries',
        color: 'irdai'
    },
    {
        key: 'CERT-In',
        name: 'CERT-In',
        fullName: 'Indian Computer Emergency Response Team',
        clauses: 3,
        icon: 'standard:shield',
        focus: 'Cyber incident reporting (6-hour mandatory), vulnerability disclosure, security audit requirements',
        description: 'National nodal agency for cyber security. CERT-In mandates 6-hour incident reporting for all entities, making it one of the strictest cyber disclosure regimes globally. Applies to every AI agent deployment.',
        regulations: [
            'Directions under Section 70B of IT Act (April 2022)',
            '6-Hour Mandatory Incident Reporting',
            'Vulnerability Disclosure & Coordination Policy'
        ],
        appliesTo: 'All entities — universal applicability',
        color: 'certin'
    },
    {
        key: 'TRAI',
        name: 'TRAI',
        fullName: 'Telecom Regulatory Authority of India',
        clauses: 1,
        icon: 'standard:call',
        focus: 'Consent for communication channels, DND compliance, unsolicited commercial communication controls',
        description: 'Regulates telecom and communication channels. Relevant when AI agents use SMS, voice calls, or WhatsApp for customer outreach — requires DND compliance and explicit consent.',
        regulations: [
            'Telecom Commercial Communications Customer Preference Regulations (TCCCPR) 2018'
        ],
        appliesTo: 'Agents using SMS, voice, or messaging channels for outreach',
        color: 'trai'
    },
    {
        key: 'UIDAI',
        name: 'UIDAI',
        fullName: 'Unique Identification Authority of India',
        clauses: 1,
        icon: 'standard:identity',
        focus: 'Aadhaar data handling, biometric/eKYC restrictions, virtual ID support, data vault requirements',
        description: 'Governs Aadhaar ecosystem. Any AI agent that processes Aadhaar numbers, biometrics, or eKYC data must comply with strict data vault requirements and cannot store raw Aadhaar data.',
        regulations: [
            'Aadhaar (Targeted Delivery of Financial and Other Subsidies) Act 2016',
            'Aadhaar Data Vault Circular',
            'Virtual ID / UID Token Framework'
        ],
        appliesTo: 'Agents processing Aadhaar, biometric, or eKYC data',
        color: 'uidai'
    }
];

export default class PramaanRegLibrary extends LightningElement {
    @track regulators = REGULATORS.map(r => ({ ...r, expanded: false }));
    @track selectedRegulator = null;

    get totalClauses() {
        return this.regulators.reduce((sum, r) => sum + r.clauses, 0);
    }

    get totalRegulators() {
        return this.regulators.length;
    }

    get hasSelection() {
        return this.selectedRegulator !== null;
    }

    get selectedReg() {
        if (this.selectedRegulator === null) return null;
        return this.regulators.find(r => r.key === this.selectedRegulator);
    }

    handleCardClick(event) {
        const key = event.currentTarget.dataset.key;
        if (this.selectedRegulator === key) {
            this.selectedRegulator = null;
        } else {
            this.selectedRegulator = key;
        }
    }

    handleCloseDetail() {
        this.selectedRegulator = null;
    }

    get regulatorCards() {
        return this.regulators.map(r => ({
            ...r,
            isSelected: r.key === this.selectedRegulator,
            cardClass: 'reg-card reg-card-' + r.color + (r.key === this.selectedRegulator ? ' reg-card-selected' : '')
        }));
    }
}
