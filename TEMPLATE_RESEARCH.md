# Indian Regulatory Compliance Document Templates for AI Governance
Working reference for Pramaan — template structures by regulator.

---

## 1. RBI — AI Risk Committee Board Note

**Source:** RBI Master Direction on IT Governance, Risk Management, Data Security and Business Continuity (7 Nov 2023, effective 1 Apr 2024). RBI/DoS/2023-24/119. Also: Responsible Business Conduct Directions, 2025 (RBI/DOR/2025-26/170).

RBI does NOT prescribe a fixed filing template. Instead, it mandates governance structures with quarterly board-level reporting. Banks self-design their Board Notes. The accepted industry format for an AI Risk Committee submission:

### Template: AI Risk Committee — Board Note

```
BOARD NOTE / AI RISK COMMITTEE SUBMISSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECTION 1 — FILING HEADER
  1.1  Document Reference Number
  1.2  Filing Entity (Bank Name, RBI Registration No.)
  1.3  Date of Submission
  1.4  Submitted By (Name, Title)
  1.5  Committee: AI Risk Committee / ITSC / Board
  1.6  Classification: Confidential
  1.7  Version & Supersession Notice

SECTION 2 — EXECUTIVE SUMMARY
  2.1  AI System/Agent Name and Purpose
  2.2  Business Function Served
  2.3  Risk Tier Classification (Critical/High/Medium/Low)
  2.4  Key Findings Summary (2-3 bullet points)
  2.5  Recommendation to Committee

SECTION 3 — AI SYSTEM DESCRIPTION
  3.1  System/Agent Name and Identifier
  3.2  Business Objective and Use Case
  3.3  Technology Stack (Model type, platform, vendor)
  3.4  Data Sources and Categories Processed
  3.5  Decision Autonomy Level (Advisory / Semi-autonomous / Autonomous)
  3.6  Customer-Facing? (Y/N) — Customer Segments Impacted
  3.7  Deployment Architecture
  3.8  Integration Points with Core Banking

SECTION 4 — RISK ASSESSMENT
  4.1  Risk Scoring Methodology Used
  4.2  Overall Risk Score and Tier
  4.3  Risk Factor Breakdown:
       a) Data Sensitivity Risk
       b) Decision Impact Risk
       c) Autonomy Risk
       d) Customer Harm Potential
       e) Model Risk (bias, drift, explainability)
       f) Operational Risk (availability, fallback)
  4.4  Hard Trigger Analysis (auto-escalation conditions)
  4.5  Comparison with Risk Appetite Statement

SECTION 5 — REGULATORY COMPLIANCE MAP
  5.1  Applicable Regulations (by regulator)
  5.2  Clause-by-Clause Compliance Status:
       | Regulator | Clause Ref | Obligation | Status | Evidence |
  5.3  Gap Analysis — Outstanding Non-Compliances
  5.4  Remediation Plan with Timelines

SECTION 6 — DATA GOVERNANCE
  6.1  Personal Data Processed (categories, volume)
  6.2  Consent Mechanism
  6.3  Data Localization Compliance (RBI Storage Directions)
  6.4  Cross-Border Data Transfer (if any)
  6.5  Data Retention and Deletion Policy
  6.6  DPDP Act Compliance Status

SECTION 7 — MODEL GOVERNANCE
  7.1  Model Validation Status (independent validation report ref)
  7.2  Bias Testing Results
  7.3  Explainability Assessment
  7.4  Performance Metrics (accuracy, false positive/negative rates)
  7.5  Model Drift Monitoring Approach
  7.6  Fallback/Override Mechanism

SECTION 8 — SECURITY ASSESSMENT
  8.1  Vulnerability Assessment Findings
  8.2  Penetration Testing Results (ref to latest report)
  8.3  Access Control Summary
  8.4  Encryption Standards (data at rest, in transit)
  8.5  Incident Response Readiness
  8.6  CERT-In Reporting Preparedness

SECTION 9 — OPERATIONAL CONTROLS
  9.1  Human Override Mechanism
  9.2  Escalation Procedures
  9.3  Business Continuity Plan
  9.4  Disaster Recovery — RTO/RPO
  9.5  Change Management Process
  9.6  Outsourcing Arrangements (if any — per RBI Outsourcing Directions)

SECTION 10 — AUDIT TRAIL & ACCOUNTABILITY
  10.1  Logging Completeness (decisions, inputs, outputs)
  10.2  Audit Trail Tamper-Proofing (hash chain integrity)
  10.3  Retention Period
  10.4  Information Systems Audit Reference

SECTION 11 — SIGN-OFF REQUIREMENTS
  11.1  Reviewer Sign-Offs Required:
        □ Legal
        □ Compliance
        □ Security / CISO
        □ Risk Management
        □ Architecture CoE
  11.2  Each Sign-Off Block:
        - Reviewer Name & Title
        - Date
        - Decision: Approved / Conditionally Approved / Rejected
        - Conditions (if any)
        - Digital Signature / Approval Reference

SECTION 12 — APPENDICES
  A — Agent X-Ray / Technical Scan Report
  B — Full Regulatory Clause Mapping Table
  C — Risk Scoring Detailed Worksheet
  D — Data Flow Diagram
  E — Audit Event Log Extract
  F — Previous Version Comparison (if resubmission)
```

**Key RBI Circular References:**
- RBI/DoS/2023-24/119 — IT Governance Master Direction (Ch IV: Risk Management)
- RBI/DOR/2025-26/170 — Responsible Business Conduct Directions (AI-specific)
- RBI/2017-18/153 — Storage of Payment System Data
- RBI/DOR/2025-26/169 — KYC Directions 2025

---

## 2. MeitY / DPDP Act — Data Protection Impact Assessment (DPIA)

**Source:** Digital Personal Data Protection Act, 2023 (Act 22 of 2023), Section 10; DPDP Rules, 2025 (G.S.R. 846(E)). Significant Data Fiduciaries must conduct DPIA before processing that "is likely to pose a significant risk." The Act doesn't prescribe an exact template — following ICO (UK) and EU GDPR Art 35 DPIA structure adapted for DPDP Act:

### Template: Data Protection Impact Assessment (DPIA)

```
DATA PROTECTION IMPACT ASSESSMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECTION 1 — IDENTIFICATION
  1.1  DPIA Reference Number
  1.2  Date of Assessment
  1.3  Data Fiduciary Name & Registration
  1.4  AI System / Process Being Assessed
  1.5  Data Protection Officer Name & Contact
  1.6  Assessment Conducted By

SECTION 2 — PROCESSING DESCRIPTION
  2.1  Nature of Processing (what data, how processed)
  2.2  Purpose of Processing (business justification)
  2.3  Scope (volume, geography, data categories)
  2.4  Context (relationship with data principals)
  2.5  AI/Algorithmic Processing Details:
       - Model type and decision logic
       - Automated decision-making (Y/N)
       - Profiling (Y/N)
  2.6  Data Sources
  2.7  Recipients / Data Processors
  2.8  Data Storage Duration
  2.9  Cross-Border Transfers

SECTION 3 — LAWFUL BASIS AND CONSENT
  3.1  Lawful Basis for Processing (Sec 4: Consent / Sec 7: Legitimate Uses)
  3.2  Consent Mechanism Description
  3.3  Consent Manager Details (if applicable, Sec 6)
  3.4  Notice to Data Principal (Sec 5 compliance — itemized)
  3.5  Purpose Limitation Assessment

SECTION 4 — NECESSITY AND PROPORTIONALITY
  4.1  Is this processing necessary for the stated purpose?
  4.2  Can the purpose be achieved with less data?
  4.3  Data Minimization Assessment
  4.4  Accuracy Mechanisms
  4.5  Storage Limitation Compliance

SECTION 5 — RISK IDENTIFICATION
  5.1  Risk to Data Principals:
       - Unauthorized access / breach
       - Inaccurate decisions by AI
       - Discrimination / bias
       - Loss of autonomy / manipulation
       - Financial harm
       - Reputational harm
  5.2  Risk Likelihood (High/Medium/Low per risk)
  5.3  Risk Severity (High/Medium/Low per risk)

SECTION 6 — RISK MITIGATION MEASURES
  6.1  Security Safeguards (Sec 8(4)):
       | Risk | Mitigation Measure | Residual Risk |
  6.2  Access Controls
  6.3  Encryption and Anonymization
  6.4  Breach Notification Preparedness (Sec 8(6))
  6.5  AI-Specific Mitigations:
       - Bias testing schedule
       - Human override mechanism
       - Explainability measures
       - Model monitoring

SECTION 7 — DATA PRINCIPAL RIGHTS
  7.1  Right to Access (Sec 11) — mechanism
  7.2  Right to Correction and Erasure (Sec 12) — mechanism
  7.3  Right to Grievance Redressal (Sec 13) — mechanism
  7.4  Right to Nominate (Sec 14) — mechanism
  7.5  Children's Data Protections (Sec 9) — applicability & controls

SECTION 8 — COMPLIANCE DECLARATION
  8.1  Summary of Residual Risks (accepted)
  8.2  DPO Recommendation
  8.3  Sign-Off:
       - Data Protection Officer
       - Business Owner
       - CISO
       - Legal
  8.4  Review Date (mandatory periodic review)

APPENDIX A — Data Flow Diagram
APPENDIX B — Processing Register Entry
APPENDIX C — Consent Notice Text
```

**Key DPDP Act Sections:**
- Sec 4 — Consent as grounds for processing
- Sec 5 — Notice requirements
- Sec 8(4) — Security safeguards obligation
- Sec 8(6) — Breach notification to Board and data principals
- Sec 10 — Additional obligations of Significant Data Fiduciaries (DPIA, audit)
- Sec 9 — Children's data protections

---

## 3. SEBI — AI/ML Disclosure & Governance Filing

**Source:** SEBI circulars SEBI/HO/MIRSD/DOS2/CIR/P/2019/10 (4 Jan 2019) and SEBI/HO/IMD/DF5/CIR/P/2019/63 (9 May 2019) on AI/ML reporting for MIIs and fund managers. SEBI Cybersecurity Framework (SEBI/HO/ITD-1/2024/113). SEBI consultation paper on responsible AI (Jun 2025). Also: SEBI (Intermediaries) Regulations, 2008, Chapter IIIB, Reg 16C.

SEBI mandates that MIIs and intermediaries using AI/ML report on these systems. The prescribed format (from 2019 circulars):

### Template: SEBI AI/ML System Disclosure

```
AI/ML SYSTEM DISCLOSURE & COMPLIANCE REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECTION 1 — IDENTIFICATION
  1.1  Intermediary Name & SEBI Registration Number
  1.2  Reporting Period
  1.3  AI/ML System Name and Version
  1.4  Date of Deployment
  1.5  Business Area (Trading / Advisory / Risk / Compliance / Operations)

SECTION 2 — SYSTEM DESCRIPTION
  2.1  Purpose and Objective
  2.2  Type of AI/ML (Supervised/Unsupervised/Reinforcement/Generative/Agentic)
  2.3  Model Architecture Summary
  2.4  Training Data Description
  2.5  Input Features and Data Sources
  2.6  Output / Decision Type
  2.7  Human-in-the-Loop? (Y/N — describe)

SECTION 3 — GOVERNANCE FRAMEWORK
  3.1  Board/Committee Oversight
  3.2  Model Risk Management Policy Reference
  3.3  Model Validation — Independent Review Conducted? (Y/N, date)
  3.4  Change Management Process
  3.5  Responsible Person (Name, Designation)

SECTION 4 — RISK AND CONTROLS
  4.1  Key Risks Identified
  4.2  Controls in Place:
       | Risk | Control | Testing Frequency |
  4.3  Bias / Fairness Assessment Results
  4.4  Explainability Level
  4.5  Cybersecurity Controls (per SEBI Cyber Framework)

SECTION 5 — PERFORMANCE MONITORING
  5.1  Key Performance Metrics
  5.2  Model Drift Monitoring Results
  5.3  Incident Log (model failures, incorrect outputs)
  5.4  Retraining Schedule

SECTION 6 — INVESTOR IMPACT
  6.1  Customer-Facing? (Y/N)
  6.2  Impact on Investment Decisions
  6.3  Disclosure to Investors (what was disclosed)
  6.4  Complaint Handling Mechanism

SECTION 7 — CERTIFICATION
  7.1  Compliance Officer Certification
  7.2  CTO / Head of Technology Certification
  7.3  Internal Audit Assessment Reference
```

---

## 4. IRDAI — AI Governance for Insurance

**Source:** Information and Cybersecurity Guidelines, 2026 (IRDAI/GA&HR/CIR/MISC/51/4/2026). IRDAI Maintenance of Information Regulations, 2025 (IRDAI/Reg/4/211/2025). Master Circular on Protection of Policyholders' Interests, 2024.

IRDAI has not issued a dedicated AI template but requires technology risk disclosures under cybersecurity guidelines and policyholder protection regulations.

### Template: IRDAI AI/Technology Risk Disclosure

```
AI/TECHNOLOGY RISK DISCLOSURE — INSURANCE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SECTION 1 — IDENTIFICATION
  1.1  Insurer Name & IRDAI Registration
  1.2  AI System / Agent Name
  1.3  Business Function (Underwriting / Claims / Distribution / Fraud)
  1.4  Date of Assessment

SECTION 2 — SYSTEM OVERVIEW
  2.1  Purpose and Business Case
  2.2  Technology Description
  2.3  Data Used (policyholder data categories)
  2.4  Automated Decision-Making Scope

SECTION 3 — POLICYHOLDER IMPACT
  3.1  Impact on Policy Pricing
  3.2  Impact on Claims Adjudication
  3.3  Fairness Assessment (no unfair discrimination)
  3.4  Transparency to Policyholders
  3.5  Grievance Mechanism

SECTION 4 — INFORMATION SECURITY
  4.1  Compliance with IRDAI Cybersecurity Guidelines
  4.2  Data Protection Measures
  4.3  Access Controls
  4.4  Incident Response Readiness

SECTION 5 — REGULATORY COMPLIANCE
  5.1  Compliance with Policyholder Protection Regulations
  5.2  Information Sharing Compliance (Reg 2025)
  5.3  Outsourcing Compliance (if third-party AI)

SECTION 6 — SIGN-OFF
  6.1  CISO
  6.2  Compliance Officer
  6.3  Appointed Actuary (if pricing/underwriting)
```

---

## 5. CERT-In — Incident Reporting (AI Systems)

**Source:** Directions under s.70B(6) of the IT Act (No. 20(3)/2022-CERT-In), 28 Apr 2022. CERT-In advisory CIAD-2026-0049 on AI Agents as Attack Vectors.

### Template: CERT-In Cyber Incident Report (AI Context)

```
CYBER INCIDENT REPORT
━━━━━━━━━━━━━━━━━━━━━

  1.  Entity Name and Sector
  2.  Date and Time of Incident Detection
  3.  Nature of Incident (prompt injection, data exfiltration, model manipulation, etc.)
  4.  Systems Affected (including AI agent identifiers)
  5.  Impact Assessment (data compromised, decisions affected)
  6.  Immediate Actions Taken
  7.  Root Cause (if known)
  8.  Reporting Timeline Compliance (6-hour mandatory reporting)
  9.  Contact Person

Note: CERT-In mandates incident reporting within 6 hours.
The AI-specific advisory adds: agent behavior logs, prompt history,
and tool-call audit trails should be preserved as forensic evidence.
```

---

## 6. Composite Template — AI Governance Compliance Pack

This is the unified template Pramaan should generate, combining all regulator requirements into a single filing-ready document:

### Template: AI Governance & Compliance Pack (Unified)

```
AI GOVERNANCE & COMPLIANCE FILING
PRAMAAN COMPLIANCE PACK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PART A — FILING HEADER
  A.1  Pack Reference / Passport Number
  A.2  Filing Entity
  A.3  Filing Date
  A.4  AI System / Agent Name
  A.5  Version Number
  A.6  Risk Tier
  A.7  Filing Status
  A.8  Previous Filing Reference (if resubmission)

PART B — EXECUTIVE SUMMARY
  (1 page max — for Board / C-suite)
  B.1  Agent Name and Purpose (2 sentences)
  B.2  Risk Classification and Score
  B.3  Regulatory Posture Summary (X of Y clauses met)
  B.4  Key Gaps Requiring Attention
  B.5  Recommendation (Approve / Conditional / Reject)

PART C — AI SYSTEM PROFILE
  C.1  System Description
  C.2  Business Function
  C.3  Technology Platform
  C.4  Data Categories Processed
  C.5  Decision Autonomy Level
  C.6  Customer Impact Scope
  C.7  Agent Metadata (X-Ray scan results)

PART D — RISK ASSESSMENT
  D.1  Methodology
  D.2  Risk Score Breakdown
  D.3  Risk Factors Table
  D.4  Hard Triggers Identified
  D.5  Risk Appetite Comparison

PART E — REGULATORY COMPLIANCE MAP
  E.1  Summary by Regulator:
       | Regulator | Applicable | Met | Gap | % |
  E.2  Detailed Clause-by-Clause Matrix:
       For each applicable clause:
       | Ref | Regulator | Instrument | Obligation | Status | Evidence | Gap Action |
  E.3  Non-Applicable Clauses (with rationale)

PART F — DATA PROTECTION ASSESSMENT (DPDP Act)
  F.1  Processing Description
  F.2  Lawful Basis
  F.3  Consent Mechanism
  F.4  Data Principal Rights Implementation
  F.5  Security Safeguards
  F.6  Cross-Border Assessment
  F.7  Children's Data (if applicable)
  F.8  DPO Sign-Off

PART G — SECURITY ASSESSMENT
  G.1  Vulnerability Assessment Summary
  G.2  Penetration Test Results Reference
  G.3  Access Control Matrix
  G.4  Encryption Standards
  G.5  CERT-In Readiness
  G.6  CISO Sign-Off

PART H — MODEL GOVERNANCE
  H.1  Model Validation Status
  H.2  Bias / Fairness Testing
  H.3  Explainability Assessment
  H.4  Performance Metrics
  H.5  Drift Monitoring
  H.6  Fallback Mechanism

PART I — OPERATIONAL CONTROLS
  I.1  Human Override Mechanism
  I.2  Escalation Procedures
  I.3  Business Continuity
  I.4  Change Management
  I.5  Outsourcing Assessment

PART J — AUDIT TRAIL
  J.1  Audit Chain Integrity Status (hash verified Y/N)
  J.2  Total Audit Events
  J.3  Event Log Summary
  J.4  Retention Policy

PART K — REVIEWER BRIEFS & SIGN-OFFS
  K.1  Legal Reviewer Brief & Decision
  K.2  Compliance Reviewer Brief & Decision
  K.3  Security Reviewer Brief & Decision
  K.4  Risk Reviewer Brief & Decision
  K.5  Architecture Reviewer Brief & Decision

  Each brief follows sub-template:
    K.x.1  Reviewer Name & Title
    K.x.2  Review Date
    K.x.3  Scope of Review (clauses reviewed)
    K.x.4  Key Findings
    K.x.5  Recommendation
    K.x.6  Conditions (if any)
    K.x.7  Decision: Approved / Conditionally Approved / Rejected
    K.x.8  Signature

PART L — REMEDIATION ROADMAP
  L.1  Gap Summary Table:
       | Gap | Clause | Severity | Owner | Target Date | Status |
  L.2  Prioritized Action Plan
  L.3  Next Review Date

APPENDICES
  App 1 — Agent X-Ray Technical Scan Report
  App 2 — Full Clause Mapping Data Export
  App 3 — Risk Scoring Worksheet
  App 4 — Data Flow Diagram
  App 5 — Audit Event Chain (full log)
  App 6 — Model Validation Report (ref)
  App 7 — Penetration Test Report (ref)
```

---

## Regulators in Pramaan's Clause Database

| Regulator | Clause Count | Key Instruments |
|-----------|-------------|-----------------|
| RBI       | 47          | IT Governance MD, RBC Directions 2025, KYC Directions, Digital Lending, Data Localization, Outsourcing, Model Risk, Internal Ombudsman, Digital Banking Channels, Authentication |
| MeitY     | 12          | DPDP Act 2023, DPDP Rules 2025 |
| SEBI      | 4           | AI/ML Reporting Circulars, Cybersecurity Framework, Intermediaries Reg 16C |
| IRDAI     | 4           | Cybersecurity Guidelines 2026, Information Sharing Reg 2025, Policyholder Protection |
| CERT-In   | 3           | IT Act s.70B Directions, AI Agent Attack Vector Advisory |
| UIDAI     | 1           | Aadhaar Act 2016, Data Vault requirements |
| TRAI      | 1           | Communication consent directions |

## Review Lenses (Reviewer Roles)

| Lens | Clause Count | Focus |
|------|-------------|-------|
| Compliance | 26 | Regulatory adherence, filing requirements, reporting obligations |
| Security | 18 | Cyber risk, access controls, encryption, incident response |
| Risk | 15 | Risk scoring, model risk, operational risk, customer harm |
| Legal | 9 | Data protection law, consent, liability, contractual obligations |
| Architecture | 8 | System design, integration, scalability, outsourcing |

---

## Implementation Notes for Pramaan

1. **Template Selection**: When generating a filing document, select the appropriate template based on which regulators have applicable clauses for the agent. RBI Board Note is always primary for banks.

2. **LLM Prompting**: Feed the template structure as a system prompt, with clause mapping data as context. The LLM fills in each section using actual compliance data.

3. **Template Storage**: Store templates as Custom Metadata or static resources in Salesforce. Each template has a `template_key` (e.g., `RBI_BOARD_NOTE`, `DPDP_DPIA`, `SEBI_AI_DISCLOSURE`, `COMPOSITE_PACK`).

4. **Reviewer Briefs**: Each lens reviewer gets a brief that contains ONLY the clauses and sections relevant to their lens, extracted from the full pack.

5. **Versioning**: Each filing is versioned. Resubmissions reference the previous version and highlight changes.
