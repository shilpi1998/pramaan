# Pramaan — Proof, Not Paperwork

**Salesforce-Native AI Governance & Compliance Filing System for Indian Banks**

Hack2Future 2026 | Theme 2: Compliance Filing | BFSI India

---

## The Problem

Indian banks have Agentforce use cases technically ready but stuck in governance queues — AI Risk Committee, Architecture CoE, Legal, Compliance, Security. RBI Master Directions, DPDP Act 2023, CERT-In Directions, and SEBI circulars add compliance layers that require 76+ regulatory clauses to be mapped, evidenced, and signed off before any AI agent reaches production.

Today, this process is manual: spreadsheets, email chains, Word documents passed between teams, and months-long review cycles. 38% of provisioned Agentforce accounts never build because the governance overhead is too high.

**Pramaan automates the entire governance filing pipeline** — from agent introspection to regulatory mapping to document generation to multi-gate review to tamper-proof audit trail — all natively on the Salesforce Platform.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRAMAAN DASHBOARD                            │
│                    (pramaanApp — LWC Shell)                         │
├─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬────────┤
│   Gov   │  Agent  │  Risk   │Compliance│ Filing │ Review  │Compli- │
│   Hub   │  X-Ray  │ Assess  │   Map   │  Docs  │  Gates  │ance    │
│         │         │         │         │        │         │Passport│
├─────────┴─────────┴─────────┴─────────┴────────┴─────────┴────────┤
│                     APEX SERVICE LAYER                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐               │
│  │ PramaanXRay  │ │PramaanRisk   │ │PramaanGov    │               │
│  │   Scanner    │ │  Engine      │ │  Service     │               │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘               │
│         │                │                │                        │
│  ┌──────┴───────┐ ┌──────┴───────┐ ┌──────┴───────┐               │
│  │PramaanLLM    │ │PramaanFiling │ │PramaanAudit  │               │
│  │  Service     │ │  Templates   │ │  Trail       │               │
│  └──────┬───────┘ └──────────────┘ └──────┬───────┘               │
│         │                                  │                       │
│  ┌──────┴─────────────────────────────────┴───────┐               │
│  │     Salesforce AI Platform (Einstein)           │               │
│  │     Claude 3.5 Sonnet via Bedrock              │               │
│  └────────────────────────────────────────────────┘               │
├───────────────────────────────────────────────────────────────────┤
│                     DATA MODEL                                     │
│  AI_Use_Case__c ──> Agent_Snapshot__c ──> Governance_Pack__c      │
│                                            ├── Clause_Mapping__c  │
│                                            ├── Filing_Document__c │
│                                            ├── Reviewer_Brief__c  │
│                                            └── Audit_Event__c     │
│  Reg_Clause__mdt (76 clauses across 7 regulators)                │
└───────────────────────────────────────────────────────────────────┘
```

---

## End-to-End Workflow

```
 ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
 │  AGENT   │───>│   RISK   │───>│COMPLIANCE│───>│  FILING  │
 │  X-RAY   │    │  ASSESS  │    │   MAP    │    │   DOCS   │
 └──────────┘    └──────────┘    └──────────┘    └──────────┘
      │               │               │               │
 Scan agent      Score risk      Map 76 clauses   Generate 6
 topology,       factors,        across RBI,      regulatory
 permissions,    determine       DPDP, CERT-In    documents
 data touches    tier (Low/      per regulator    from templates
                 Med/High)
      │               │               │               │
      v               v               v               v
 ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
 │  REVIEW  │───>│COMPLIANCE│───>│  AUDIT   │───>│ LEARNING │
 │  GATES   │    │ PASSPORT │    │  TRAIL   │    │   LOOP   │
 └──────────┘    └──────────┘    └──────────┘    └──────────┘
      │               │               │               │
 4 independent   Issued when     SHA-256 hash     Track reg
 review gates:   all gates       chain — every    updates,
 AI Risk Cttee,  cleared.        event tamper-    generate new
 Security,       Passport #,     proof with       templates,
 Compliance,     case brief,     sequence +       adapt to
 Legal           production OK   prev hash        changes
```

**Step 1 — Agent X-Ray:** Introspects a live Agentforce bot. Reads its `BotVersion` metadata, resolves topics, actions, and object/field permissions. Maps every data touch — which objects the agent reads/writes, which fields contain PII or financial data, whether actions are in-region only. Captures a point-in-time snapshot with a SHA-256 hash for integrity.

**Step 2 — Risk Assessment:** Scores the agent across 5 weighted factors — Audience (internal/customer), Decision Impact (advisory/decisioning/transactional), Human Oversight Level (human-in-loop/human-on-loop/autonomous), Data Sensitivity (PII, financial, biometric), and Vulnerable Customers. Hard triggers (autonomous + customer-facing, or financial decisioning) auto-elevate the tier. The LLM (Claude 3.5 Sonnet via Salesforce AI Platform) analyzes the agent profile against all 7 Indian regulators and identifies which regulations apply, estimated clause counts, and key risks.

**Step 3 — Compliance Map:** Maps all 76 regulatory clauses from the `Reg_Clause__mdt` metadata against the agent. Each clause includes the regulator, clause reference, obligation text, binding status, effective date, and an applicability rule evaluated against the agent's DNA. Clause statuses are tracked as Met, Gap, Partial, or N/A. The system identifies which filing templates are required based on applicable regulators and risk tier.

**Step 4 — Filing Documents:** Generates 6 regulatory filing documents from templates:

| Document | Purpose | Regulator |
|----------|---------|-----------|
| Board Note | AI agent production deployment approval for Board AI Risk Sub-Committee | RBI |
| AI Risk Committee Filing | Detailed risk assessment with clause-by-clause compliance mapping | RBI |
| Model Risk Management Report | Model validation, performance monitoring, and drift controls | RBI |
| Data Protection Impact Assessment (DPIA) | Privacy impact analysis with data flow mapping and rights assessment | DPDP Act |
| Cybersecurity Compliance Assessment | Security controls, incident response, and CERT-In readiness | CERT-In |
| Regulatory Compliance Certificate | Cross-regulator compliance attestation with evidence register | All |

Each document includes a detailed evidence register with 10 evidence items citing specific regulation sections (DPDP Act S6, S8, S9, S8(6), S10; RBI IT Gov S4.3; RBI FREE-AI; RBI KYC Directions; CERT-In Directions; RBI Model Risk), plus a governance artefacts table listing all 8 governance documents produced.

**Step 5 — Review Gates:** Four independent reviewer gates — AI Risk Committee, Security, Compliance, Legal. Each reviewer receives a pre-generated brief tailored to their lens (e.g., Security reviewers see permission analysis and data sensitivity; Compliance reviewers see clause coverage and regulatory gaps). Reviewers approve or reject with comments. All decisions are audit-logged.

**Step 6 — Compliance Passport:** When all gates clear, the system issues a Compliance Passport — a tamper-evident certificate showing the agent name, risk tier, passport number (PRM-YYYY-NNNN), gate sign-offs with reviewer names and dates, clause coverage statistics, and a case brief summary. The passport serves as the production deployment clearance.

**Step 7 — Audit Trail:** Every governance event — pack creation, clause mapping, document generation, review decisions, passport issuance — is logged with a SHA-256 hash chain. Each event stores: sequence number, event type, actor, payload, previous hash, and computed hash. Chain integrity can be verified at any time; any tampering breaks the chain.

**Step 8 — Learning Loop:** Monitors regulatory landscape changes and generates template suggestions for new compliance requirements. Tracks rejection patterns to improve future filings.

---

## LLM Integration

Pramaan uses **Claude 3.5 Sonnet** via the **Salesforce AI Platform (Einstein)** with Amazon Bedrock as the model provider.

- **Model ID:** `sfdc_ai__DefaultBedrockAnthropicClaude35Sonnet`
- **Integration:** Native Salesforce `aiplatform.ModelsAPI` — no external callouts, no API keys, runs within the Salesforce trust boundary
- **Use Case:** Regulatory applicability analysis — given an agent's DNA profile (sub-sector, audience, function, data categories, autonomy level), the LLM determines which of 7 Indian regulators apply, estimates clause counts, identifies key risks, and provides governance recommendations
- **Prompt Design:** Structured JSON output with specific schema enforcement — regulator, applicability, reasoning, estimated clauses, confidence level
- **Fallback:** Deterministic rule-based analysis engine provides equivalent results using codified regulatory logic, ensuring the system operates reliably regardless of LLM availability

---

## Data Model

### Core Objects

**`AI_Use_Case__c`** — The AI agent registration. Stores the agent's DNA: sub-sector (SCB, SFB, NBFC, etc.), audience, decision impact, autonomy level, data categories, channels, function, and regulatory metadata. Links to the Agentforce bot via `Agent_API_Name__c`.

**`Agent_Snapshot__c`** — Point-in-time capture of an agent's topology. Stores the full AI Bill of Materials (BOM) as JSON — topics, actions, object/field permissions, data touches. Includes computed metrics: object count, field count, PII field count, financial field count, read/write ratios. SHA-256 hash ensures snapshot integrity.

**`Governance_Pack__c`** — The central filing entity. Groups all compliance artifacts for a single agent version: clause mappings, filing documents, reviewer briefs, and audit events. Tracks pack status (Draft, In Review, Approved, Rejected), gate approval counts, clause coverage statistics, and passport issuance.

**`Clause_Mapping__c`** — Maps a single regulatory clause to a governance pack. Stores the clause reference, obligation text, regulator, mapping status (Met/Gap/Partial/N/A), evidence captured, lens assignment, and fix tracking. Created from `Reg_Clause__mdt` metadata during compliance mapping.

**`Filing_Document__c`** — Generated regulatory filing document. Stores the template type, rendered HTML content, status, and generation timestamp. Linked to the governance pack.

**`Reviewer_Brief__c`** — Pre-generated review brief for a specific lens (AI Risk Committee, Security, Compliance, Legal). Contains the brief content, approval status, reviewer assignment, decision date, and reviewer comments. Claims-based tracking monitors evidence completeness.

**`Audit_Event__c`** — Immutable audit log entry. SHA-256 hash chain with sequence number, event type, actor, payload, previous hash, and computed hash. Supports full chain verification.

**`Reg_Clause__mdt`** — Custom Metadata Type storing 76 regulatory clauses across 7 Indian regulators. Each clause includes: regulator, clause reference, obligation text, binding status, effective date, applicability rule, evidence hint, and lens assignment. Deployed as metadata — no data migration required.

### Regulatory Clause Coverage

| Regulator | Full Name | Clauses | Key Regulations |
|-----------|-----------|---------|-----------------|
| RBI | Reserve Bank of India | 51 | IT Governance Master Directions 2023, Digital Lending Guidelines, Fair Practices Code, FREE-AI Framework, KYC Directions, Model Risk Management |
| MeitY | Ministry of Electronics & IT | 12 | DPDP Act 2023 (Consent, Data Principal Rights, Security Safeguards, Breach Notification, DPIA), IndiaAI Mission |
| CERT-In | Indian Computer Emergency Response Team | 3 | CERT-In Directions 2022 (6-hour incident reporting, 180-day log retention) |
| SEBI | Securities & Exchange Board of India | 4 | AI/ML in Securities Trading, Algo Trading Disclosure |
| IRDAI | Insurance Regulatory & Development Authority | 4 | IT Governance Guidelines, AI in Underwriting/Claims |
| TRAI | Telecom Regulatory Authority of India | 1 | AI-powered Communication Regulations |
| UIDAI | Unique Identification Authority of India | 1 | Aadhaar Data Handling (masking, virtual ID, encrypted storage) |

---

## Agentforce Integration

Pramaan governs a live Agentforce bot: **KYC Verification Agent** (`KYC_Verification_Agent`).

### Agent Actions (GenAI Functions)

| Action | Apex Class | Purpose |
|--------|-----------|---------|
| Verify Aadhaar | `VerifyAadhaarAction` | Validates Aadhaar number via UIDAI e-KYC |
| Verify PAN Card | `VerifyPANAction` | PAN card verification and name matching |
| Verify Income | `VerifyIncomeAction` | Income document validation |
| Check Watchlist | `CheckWatchlistAction` | PEP/sanctions/RBI watchlist screening |
| Check Outstanding Balance | `CheckOutstandingAction` | Existing liability check |
| Check Credit Score | (GenAI Function) | Credit bureau score retrieval |
| Fetch Loan Products | `FetchLoanProductsAction` | Product eligibility matching |
| Calculate EMI | `CalculateEMIAction` | EMI computation for loan products |
| Create Payment Plan | `CreatePaymentPlanAction` | Payment schedule generation |
| Send Payment Reminder | `SendReminderAction` | Automated reminder dispatch |

### Agent X-Ray Capabilities

The X-Ray scanner performs deep introspection of the Agentforce bot:

1. **Topology Mapping** — Resolves `BotDefinition` → `BotVersion` → Topics → Actions. Identifies all GenAI functions, their input/output parameters, and invocation patterns.

2. **Permission Analysis** — Queries `ObjectPermissions` and `FieldPermissions` for the agent's profile. Maps which standard and custom objects the agent can read, create, edit, delete.

3. **Data Touch Mapping** — For every field the agent accesses, classifies it as PII (Name, Email, Phone, Aadhaar, PAN), Financial (Account Balance, Credit Score, Loan Amount), or Standard. Tracks read vs. write access.

4. **Security Scanning** — Runs PMD/ApexPMD static analysis and LWC Dependency Audit. Identifies findings like missing `with sharing`, hardcoded credentials, unescaped outputs, and cross-boundary data access.

5. **Snapshot Integrity** — Generates a SHA-256 hash of the entire X-Ray result. When a governance pack is filed, the snapshot hash is locked — any agent change after filing is detectable.

---

## Risk Scoring Engine

The risk engine uses a weighted scoring model with hard triggers:

```
┌─────────────────────────────────────────────────────┐
│                 RISK SCORING MODEL                   │
├──────────────────────┬──────────────────────────────┤
│ Factor               │ Scoring                      │
├──────────────────────┼──────────────────────────────┤
│ Audience             │ Internal=0, Partner=1,       │
│                      │ Customer=3                   │
├──────────────────────┼──────────────────────────────┤
│ Decision Impact      │ Advisory=0, Operational=1,   │
│                      │ Decisioning=2, Transactional=3│
├──────────────────────┼──────────────────────────────┤
│ Human Oversight      │ Human-in-loop=0,             │
│                      │ Human-on-loop=1,             │
│                      │ Autonomous=3                 │
├──────────────────────┼──────────────────────────────┤
│ Data Sensitivity     │ Non-personal=0, Personal=1,  │
│                      │ Financial=2, Biometric=3     │
├──────────────────────┼──────────────────────────────┤
│ Vulnerable Customers │ No=0, Yes=2                  │
├──────────────────────┼──────────────────────────────┤
│ TOTAL                │ 0-14 points                  │
├──────────────────────┼──────────────────────────────┤
│ Risk Tiers           │ Low: 0-3, Medium: 4-7,       │
│                      │ High: 8+                     │
├──────────────────────┼──────────────────────────────┤
│ Hard Triggers        │ Autonomous + Customer-facing │
│ (auto-elevate to     │ Financial Decisioning        │
│  High)               │ Biometric data processing    │
└──────────────────────┴──────────────────────────────┘
```

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Platform** | Salesforce (Lightning Platform) |
| **Frontend** | Lightning Web Components (LWC) |
| **Backend** | Apex (with sharing enforcement) |
| **AI/LLM** | Claude 3.5 Sonnet via Salesforce AI Platform (Amazon Bedrock) |
| **Agent Framework** | Agentforce (BotDefinition, GenAI Functions, Topics) |
| **Metadata** | Custom Metadata Types (`Reg_Clause__mdt`) for 76 regulatory clauses |
| **Security** | SHA-256 hash chains for audit integrity, FLS enforcement, with sharing |
| **Data Model** | 8 custom objects, 1 custom metadata type, 10 GenAI functions |

---

## Component Map

| Component | Type | Purpose |
|-----------|------|---------|
| `pramaanApp` | LWC | Main shell — tab navigation, flow orchestration |
| `pramaanMissionControl` | LWC | Governance Hub — dashboard with all use cases and filing status |
| `pramaanXRayScanner` | LWC | Agent X-Ray — topology viewer, data touch analysis, security scan |
| `pramaanAssess` | LWC | Risk Assessment — DNA editor, risk scoring, LLM regulatory analysis |
| `pramaanComplianceMap` | LWC | Compliance Map — clause mapping, gap analysis, document generation trigger |
| `pramaanFilingCenter` | LWC | Filing Documents — document viewer with rendered HTML reports |
| `pramaanReviewerLens` | LWC | Review Gates — 4-gate approval workflow with reviewer briefs |
| `pramaanGoLivePassport` | LWC | Compliance Passport — production clearance certificate |
| `pramaanAuditTrail` | LWC | Audit Trail — hash chain viewer with integrity verification |
| `pramaanLearningLoop` | LWC | Learning Loop — regulatory change tracker and template suggestions |
| `pramaanRegLibrary` | LWC | Regulation Library — browse all 76 clauses by regulator |
| `PramaanController` | Apex | Main controller — all `@AuraEnabled` methods for LWC |
| `PramaanXRay` | Apex | Agent introspection engine — bot metadata, permissions, data touches |
| `PramaanRiskEngine` | Apex | Risk scoring and clause applicability mapping |
| `PramaanLLMService` | Apex | LLM integration — regulatory analysis via Claude 3.5 Sonnet |
| `PramaanGovernanceService` | Apex | Pack lifecycle, clause mapping, filing document generation |
| `PramaanFilingTemplates` | Apex | Template detection and readiness assessment |
| `PramaanAuditTrail` | Apex | SHA-256 hash chain audit logging and verification |
| `PramaanLearningLoop` | Apex | Regulatory change detection and learning dashboard |

---

## Filing Document Generation Pipeline

```
  AI_Use_Case__c DNA          Reg_Clause__mdt (76 clauses)
        │                              │
        v                              v
  ┌─────────────┐            ┌─────────────────┐
  │ Risk Engine │            │ Clause Mapping   │
  │ (scoring +  │            │ (applicability   │
  │  tier)      │            │  rules engine)   │
  └──────┬──────┘            └────────┬─────────┘
         │                            │
         v                            v
  ┌──────────────────────────────────────┐
  │    PramaanFilingTemplates            │
  │    detectRequiredTemplates()         │
  │    ─────────────────────────         │
  │    Always: BOARD_NOTE, DPIA          │
  │    If RBI: AI_RISK_COMMITTEE         │
  │    If Med+: MODEL_RISK               │
  │    If CERT-In: CYBERSECURITY         │
  │    Always: REG_COMPLIANCE_CERT       │
  └──────────────┬───────────────────────┘
                 │
                 v
  ┌──────────────────────────────────────┐
  │    PramaanGovernanceService          │
  │    generateFilingDocumentFromTemplate │
  │    ──────────────────────────────     │
  │    For each template type:           │
  │    1. Load agent DNA + clauses       │
  │    2. Compute compliance metrics     │
  │    3. Build HTML document with:      │
  │       - Header (org, ref, date)      │
  │       - Executive Summary            │
  │       - Agent Profile                │
  │       - Regulatory Analysis          │
  │       - Clause-by-clause mapping     │
  │       - Evidence Register (10 items) │
  │       - Governance Artefacts         │
  │       - Sign-off Block               │
  └──────────────┬───────────────────────┘
                 │
                 v
         Filing_Document__c
         (HTML content stored)
```

---

## Audit Chain Integrity

Every governance action produces an immutable audit event with hash chain verification:

```
Event #1                    Event #2                    Event #3
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│ Seq: 1          │        │ Seq: 2          │        │ Seq: 3          │
│ Type: PACK_     │        │ Type: CLAUSE_   │        │ Type: DOC_      │
│       CREATED   │        │       MAPPED    │        │       GENERATED │
│ Actor: Admin    │        │ Actor: Admin    │        │ Actor: Admin    │
│ PrevHash: 0     │──SHA──>│ PrevHash: abc.. │──SHA──>│ PrevHash: def.. │
│ Hash: abc...    │  256   │ Hash: def...    │  256   │ Hash: ghi...    │
└─────────────────┘        └─────────────────┘        └─────────────────┘

Verification: Recompute each hash from (seq + type + actor + payload + prevHash).
If any event is modified, the chain breaks at that point.
```

---

## Deployment

```bash
# Authenticate to org
sf org login web --alias hack2future

# Deploy metadata (exclude genAiFunctions to avoid conflicts)
sf project deploy start \
  --source-dir "force-app/main/default/objects" \
  --source-dir "force-app/main/default/classes" \
  --source-dir "force-app/main/default/lwc" \
  --source-dir "force-app/main/default/customMetadata" \
  --source-dir "force-app/main/default/permissionsets" \
  --source-dir "force-app/main/default/tabs" \
  --target-org hack2future

# Assign permission set
sf org assign permset --name Pramaan_Admin --target-org hack2future
```

---

## Team

Built for Hack2Future 2026 — Theme 2: Compliance Filing (BFSI India)
