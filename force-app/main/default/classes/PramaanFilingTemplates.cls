public with sharing class PramaanFilingTemplates {

    public class FilingTemplate {
        @AuraEnabled public String templateType;
        @AuraEnabled public String templateName;
        @AuraEnabled public String description;
        @AuraEnabled public String regulator;
        @AuraEnabled public String instrument;
        @AuraEnabled public List<TemplateSection> sections;
    }

    public class TemplateSection {
        @AuraEnabled public String sectionNumber;
        @AuraEnabled public String title;
        @AuraEnabled public String instruction;
        @AuraEnabled public Boolean required;

        public TemplateSection(String num, String t, String inst, Boolean req) {
            this.sectionNumber = num;
            this.title = t;
            this.instruction = inst;
            this.required = req;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FilingTemplate> getAvailableTemplates() {
        List<FilingTemplate> templates = new List<FilingTemplate>();
        templates.add(buildAIRiskCommitteeTemplate());
        templates.add(buildDPIATemplate());
        templates.add(buildModelRiskTemplate());
        templates.add(buildBoardNoteTemplate());
        templates.add(buildCyberSecurityTemplate());
        templates.add(buildRegulatoryComplianceCertTemplate());
        return templates;
    }

    public static FilingTemplate getTemplate(String templateType) {
        switch on templateType {
            when 'AI_RISK_COMMITTEE' { return buildAIRiskCommitteeTemplate(); }
            when 'DPIA' { return buildDPIATemplate(); }
            when 'MODEL_RISK' { return buildModelRiskTemplate(); }
            when 'BOARD_NOTE' { return buildBoardNoteTemplate(); }
            when 'CYBERSECURITY' { return buildCyberSecurityTemplate(); }
            when 'REG_COMPLIANCE_CERT' { return buildRegulatoryComplianceCertTemplate(); }
            when else { return buildAIRiskCommitteeTemplate(); }
        }
    }

    public class TemplateReadiness {
        @AuraEnabled public String templateType;
        @AuraEnabled public String templateName;
        @AuraEnabled public String description;
        @AuraEnabled public String regulator;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Integer totalSections;
        @AuraEnabled public Integer requiredSections;
        @AuraEnabled public Integer dataPointsAvailable;
        @AuraEnabled public Integer dataPointsTotal;
        @AuraEnabled public Integer readinessPercent;
        @AuraEnabled public String readinessLabel;
        @AuraEnabled public Boolean alreadyGenerated;
    }

    public static List<String> detectRequiredTemplates(Set<String> applicableRegulators, String riskTier) {
        List<String> required = new List<String>();

        required.add('BOARD_NOTE');

        if (applicableRegulators.contains('RBI')) {
            required.add('AI_RISK_COMMITTEE');
        }

        if (applicableRegulators.contains('MeitY')) {
            required.add('DPIA');
        }

        if (applicableRegulators.contains('RBI') &&
            (riskTier == 'High' || riskTier == 'Medium')) {
            required.add('MODEL_RISK');
        }

        if (applicableRegulators.contains('CERT-In') ||
            applicableRegulators.contains('RBI')) {
            required.add('CYBERSECURITY');
        }

        if (applicableRegulators.size() > 1) {
            required.add('REG_COMPLIANCE_CERT');
        }

        return required;
    }

    public static List<TemplateReadiness> assessReadiness(
        Id packId, Set<String> applicableRegulators, String riskTier,
        AI_Use_Case__c uc, Set<String> generatedTypes
    ) {
        List<String> requiredTypes = detectRequiredTemplates(applicableRegulators, riskTier);
        List<TemplateReadiness> readiness = new List<TemplateReadiness>();

        for (FilingTemplate tmpl : getAvailableTemplates()) {
            TemplateReadiness tr = new TemplateReadiness();
            tr.templateType = tmpl.templateType;
            tr.templateName = tmpl.templateName;
            tr.description = tmpl.description;
            tr.regulator = tmpl.regulator;
            tr.required = requiredTypes.contains(tmpl.templateType);
            tr.totalSections = tmpl.sections.size();
            tr.requiredSections = 0;
            for (TemplateSection s : tmpl.sections) {
                if (s.required) tr.requiredSections++;
            }
            tr.alreadyGenerated = generatedTypes.contains(tmpl.templateType);

            Integer available = 0;
            Integer total = 5;
            if (uc.Name != null) available++;
            if (uc.Risk_Tier__c != null) available++;
            if (uc.Function__c != null) available++;
            if (uc.Data_Categories__c != null) available++;
            if (uc.Audience__c != null) available++;

            if (tmpl.templateType == 'DPIA') {
                total += 3;
                if (uc.Decision_Impact__c != null) available++;
                if (uc.Autonomy__c != null) available++;
                if (uc.Sub_Sector__c != null) available++;
            } else if (tmpl.templateType == 'CYBERSECURITY') {
                total += 2;
                if (uc.Agent_API_Name__c != null) available++;
                if (uc.Channels__c != null) available++;
            } else if (tmpl.templateType == 'MODEL_RISK') {
                total += 2;
                if (uc.Autonomy__c != null) available++;
                if (uc.Decision_Impact__c != null) available++;
            } else {
                total += 2;
                if (uc.Sub_Sector__c != null) available++;
                if (uc.Autonomy__c != null) available++;
            }

            tr.dataPointsAvailable = available;
            tr.dataPointsTotal = total;
            tr.readinessPercent = total > 0 ? (Integer) Math.round((Decimal.valueOf(available) / total) * 100) : 0;
            if (tr.readinessPercent >= 80) {
                tr.readinessLabel = 'Ready';
            } else if (tr.readinessPercent >= 50) {
                tr.readinessLabel = 'Partial';
            } else {
                tr.readinessLabel = 'Incomplete';
            }
            readiness.add(tr);
        }
        return readiness;
    }

    public static String buildLLMPrompt(FilingTemplate tmpl) {
        String prompt = 'You are generating a formal regulatory filing document. Follow this EXACT template structure.\n';
        prompt += 'Template: ' + tmpl.templateName + '\n';
        prompt += 'Regulator: ' + tmpl.regulator + '\n';
        prompt += 'Governing Instrument: ' + tmpl.instrument + '\n\n';
        prompt += 'MANDATORY SECTIONS (use these exact headings and numbering):\n\n';
        for (TemplateSection s : tmpl.sections) {
            prompt += s.sectionNumber + '. ' + s.title.toUpperCase();
            if (s.required) prompt += ' [MANDATORY]';
            prompt += '\n';
            prompt += 'Instructions: ' + s.instruction + '\n\n';
        }
        prompt += 'FORMAT REQUIREMENTS:\n';
        prompt += '- Use the exact section numbers and headings above\n';
        prompt += '- Write in formal regulatory language suitable for submission to ' + tmpl.regulator + '\n';
        prompt += '- Include specific clause references and regulation citations\n';
        prompt += '- Use dates in DD-MMM-YYYY format\n';
        prompt += '- Mark any section where data is insufficient as "[TO BE COMPLETED]"\n';
        prompt += '- Do not use markdown formatting — use plain text with indentation\n';
        prompt += '- Include a document control header with Filing Reference, Date, Version\n';
        return prompt;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEMPLATE 1: AI Risk Committee Submission
    // Based on RBI FREE-AI Committee Report + RBI IT Governance framework
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private static FilingTemplate buildAIRiskCommitteeTemplate() {
        FilingTemplate t = new FilingTemplate();
        t.templateType = 'AI_RISK_COMMITTEE';
        t.templateName = 'AI Risk Committee – Use Case Approval Filing';
        t.description = 'Standard submission to the Board-level AI Risk Committee for approval of a new AI/ML use case, per RBI FREE-AI framework and IT Governance directions.';
        t.regulator = 'RBI';
        t.instrument = 'FREE-AI Committee Report; IT Governance, Risk, Resilience and Assurance Framework Directions, 2026';
        t.sections = new List<TemplateSection>{
            new TemplateSection('1', 'Document Control',
                'Filing Reference (auto-generated), Date of Submission, Document Version, Classification (Confidential), Prepared By, Reviewed By, Approved By fields. Include revision history table.', true),
            new TemplateSection('2', 'Executive Summary',
                'One-page summary: AI use case name, business purpose, risk tier classification, key regulatory exposure, compliance posture (% met), and clear recommendation (Approve / Approve with Conditions / Defer). Maximum 400 words.', true),
            new TemplateSection('3', 'Use Case Description',
                '3.1 Business Objective — what problem this agent solves and for whom.\n3.2 Functional Description — what the agent does step-by-step.\n3.3 Deployment Scope — channels, customer segments, transaction types, volume estimates.\n3.4 Decision Authority — what decisions the agent makes autonomously vs. referred to human.\n3.5 Data Consumed — categories of data accessed, sources, PII/sensitive flags.', true),
            new TemplateSection('4', 'Risk Classification',
                '4.1 Risk Tier — as per bank\'s AI Risk Tiering Framework (High/Medium/Low) with score breakdown.\n4.2 Risk Factors — enumerate each scored dimension: Decision Impact, Autonomy Level, Data Sensitivity, Customer Vulnerability, Regulatory Exposure.\n4.3 Hard Triggers — any automatic High-tier triggers (e.g., credit decisioning, vulnerable customers, cross-border data).\n4.4 Risk Appetite Alignment — how this use case fits within the bank\'s stated AI risk appetite.', true),
            new TemplateSection('5', 'Regulatory Applicability Map',
                'Table format: Regulator | Instrument | Clause Reference | Obligation Summary | Compliance Status (Met/Gap/Partial) | Evidence Reference.\nGroup by regulator. For each applicable regulation, cite the specific section and explain why it applies to this use case.', true),
            new TemplateSection('6', 'Compliance Gap Analysis',
                'For each Gap or Partial clause:\n6.1 Clause Reference and Obligation\n6.2 Current State — what is in place today\n6.3 Gap Description — what is missing\n6.4 Remediation Action — specific steps to close the gap\n6.5 Responsible Owner — team/role accountable\n6.6 Target Date — when remediation will be complete\n6.7 Residual Risk — if gap is accepted, state the residual risk.', true),
            new TemplateSection('7', 'Model Governance & Explainability',
                '7.1 Model/Algorithm Description — architecture, training approach, or rule-based logic.\n7.2 Explainability Assessment — can decisions be explained to affected customers per RBI RBC Directions §DA?\n7.3 Bias & Fairness Testing — methodology, results, protected attributes tested.\n7.4 Performance Monitoring — KPIs, drift detection, retraining triggers.\n7.5 Model Validation Status — independent validation results if applicable.', true),
            new TemplateSection('8', 'Data Protection & Privacy',
                '8.1 Data Protection Impact Assessment summary — per DPDP Act 2023.\n8.2 Lawful Basis for Processing — consent, legitimate use, or other DPDP basis.\n8.3 Data Principal Rights — how right to access, correction, erasure, grievance redressal are supported.\n8.4 Cross-Border Data Transfer — if applicable, adequacy assessment or SCC basis.\n8.5 Data Retention & Deletion — retention schedule aligned with RBI record-keeping requirements.\n8.6 Consent Management — mechanism for obtaining, recording, and withdrawing consent.', true),
            new TemplateSection('9', 'Security Controls',
                '9.1 Authentication & Authorisation — how the agent authenticates, what permissions it has.\n9.2 Data Encryption — in transit and at rest.\n9.3 Prompt Injection / Adversarial Defences — safeguards against manipulation.\n9.4 Audit Logging — what is logged, retention period, tamper-evidence.\n9.5 Incident Response — integration with CERT-In 6-hour reporting mandate.\n9.6 Penetration Testing — schedule and last results.', true),
            new TemplateSection('10', 'Human Oversight & Escalation',
                '10.1 Human-in-the-Loop Design — at what points does a human intervene?\n10.2 Escalation Matrix — triggers for escalation, responsible roles.\n10.3 Override Mechanism — how can a human override agent decisions?\n10.4 Customer Complaint Pathway — integration with Internal Ombudsman per RBI IO Directions 2026.', true),
            new TemplateSection('11', 'Outsourcing & Third-Party Risk',
                '11.1 Third-Party Dependencies — cloud provider, model provider, API dependencies.\n11.2 Outsourcing Risk Assessment — per RBI Outsourcing Directions 2025.\n11.3 Contractual Safeguards — data processing agreements, audit rights, exit clauses.\n11.4 Concentration Risk — dependency on single provider.', true),
            new TemplateSection('12', 'Remediation Roadmap',
                'Priority-ordered table: Priority (P1/P2/P3) | Action Item | Owner | Target Date | Dependency | Status.\nAll Gap clauses must have corresponding action items. Include budget estimate if applicable.', true),
            new TemplateSection('13', 'Sign-Off Matrix',
                'Table: Reviewer Role | Name | Decision (Approve/Reject/Rework) | Date | Comments.\nMinimum reviewers based on risk tier: Low = AI Risk Committee + Security; Medium = + Compliance + Legal; High = + Architecture.', true),
            new TemplateSection('A', 'Appendix A: Detailed Clause-by-Clause Mapping',
                'Full mapping table with all evaluated clauses including N/A with justification for non-applicability.', false),
            new TemplateSection('B', 'Appendix B: Agent Technical Specification',
                'Agent configuration snapshot: topics, actions, data objects accessed, API integrations, channels.', false),
            new TemplateSection('C', 'Appendix C: Audit Trail Extract',
                'Summary of governance events from Pramaan audit chain for this filing.', false)
        };
        return t;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEMPLATE 2: Data Protection Impact Assessment (DPIA)
    // Per DPDP Act 2023, DPDP Rules 2025, and MeitY guidelines
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private static FilingTemplate buildDPIATemplate() {
        FilingTemplate t = new FilingTemplate();
        t.templateType = 'DPIA';
        t.templateName = 'Data Protection Impact Assessment (DPIA)';
        t.description = 'Mandatory DPIA for AI systems processing personal data, per DPDP Act 2023 §10 and DPDP Rules 2025.';
        t.regulator = 'MeitY';
        t.instrument = 'Digital Personal Data Protection Act, 2023; DPDP Rules, 2025 (G.S.R. 846(E))';
        t.sections = new List<TemplateSection>{
            new TemplateSection('1', 'Document Control & DPIA Reference',
                'DPIA Reference Number, Date, Version, Data Fiduciary Name, DPO Contact, Assessment Scope, Previous DPIA Reference (if update).', true),
            new TemplateSection('2', 'Processing Activity Description',
                '2.1 Nature of Processing — what the AI agent does with personal data.\n2.2 Purpose Specification — specific, clear purpose per DPDP §4.\n2.3 Categories of Data Principals — customers, employees, third parties.\n2.4 Categories of Personal Data — enumerate all data types (identity, financial, biometric, behavioral).\n2.5 Volume & Scale — estimated number of data principals affected.\n2.6 Data Flow Diagram — describe the flow from collection to deletion.', true),
            new TemplateSection('3', 'Lawful Basis Assessment',
                '3.1 Primary Basis — consent (§6) or legitimate use (§7). For each data category, state basis.\n3.2 Consent Mechanism — if consent-based: how obtained, format, granularity, withdrawal process.\n3.3 Legitimate Use Justification — if applicable: which specific legitimate use under §7 applies.\n3.4 Purpose Limitation — demonstrate processing is limited to stated purpose.', true),
            new TemplateSection('4', 'Data Principal Rights Implementation',
                '4.1 Right to Access (§11) — how data principals can access their data.\n4.2 Right to Correction (§12) — mechanism for correcting inaccurate data.\n4.3 Right to Erasure (§12) — deletion process and timeline.\n4.4 Right to Grievance Redressal (§13) — internal DPO process.\n4.5 Right to Nominate (§14) — handling of deceased/incapacitated data principals.\n4.6 Response Timeline — maximum response time for each right (per Rules).', true),
            new TemplateSection('5', 'Risk Assessment',
                '5.1 Risks to Data Principals — privacy risks, discrimination risks, financial harm risks.\n5.2 Likelihood and Severity Matrix — for each risk, assess probability and impact.\n5.3 Automated Decision-Making Risks — if agent makes decisions affecting data principals, assess fairness and explainability risks.\n5.4 Children\'s Data — if applicable, additional safeguards per DPDP §9.', true),
            new TemplateSection('6', 'Security Safeguards',
                '6.1 Technical Measures — encryption, access controls, anonymisation, pseudonymisation.\n6.2 Organisational Measures — training, policies, access reviews.\n6.3 Breach Notification Plan — per DPDP §8, notify Data Protection Board within prescribed time.\n6.4 CERT-In Integration — 6-hour incident reporting compliance.\n6.5 Data Localisation — compliance with RBI data localisation requirements (RBI/2017-18/153).', true),
            new TemplateSection('7', 'Cross-Border Transfer Assessment',
                '7.1 Transfer Destinations — countries where data may be transferred.\n7.2 Adequacy Assessment — per DPDP §16, is the destination on the approved list?\n7.3 Contractual Safeguards — SCCs or equivalent protection.\n7.4 Government Access Risks — assessment per destination country laws.', true),
            new TemplateSection('8', 'Data Retention & Deletion Schedule',
                '8.1 Retention Periods — by data category, aligned with RBI record-keeping (minimum 8 years for financial records).\n8.2 Deletion Mechanism — how data is purged after retention period or consent withdrawal.\n8.3 Backup & Archive Treatment — how backups are handled for deleted data.', true),
            new TemplateSection('9', 'Mitigation Measures',
                'For each identified risk: Risk | Mitigation Measure | Responsible Owner | Implementation Date | Residual Risk.\nInclude both technical and procedural mitigations.', true),
            new TemplateSection('10', 'DPO Sign-Off & Review Schedule',
                'DPO assessment and sign-off. Next review date (annual or on material change). Board/Management acknowledgement.', true)
        };
        return t;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEMPLATE 3: Model Risk Management Report
    // Per RBI Draft Guidance on Model Risk Management (PR 2026-2027/528)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private static FilingTemplate buildModelRiskTemplate() {
        FilingTemplate t = new FilingTemplate();
        t.templateType = 'MODEL_RISK';
        t.templateName = 'Model Risk Management Report';
        t.description = 'Model risk assessment per RBI Draft Guidance on Model Risk Management, covering model governance, validation, and ongoing monitoring.';
        t.regulator = 'RBI';
        t.instrument = 'Draft guidance on Model Risk Management (PR 2026-2027/528)';
        t.sections = new List<TemplateSection>{
            new TemplateSection('1', 'Document Control',
                'Model Name/ID, Model Owner, Submission Date, Version, Classification Tier, Previous Assessment Date.', true),
            new TemplateSection('2', 'Model Inventory Registration',
                '2.1 Model Purpose & Scope — business use, materiality classification.\n2.2 Model Type — ML/AI/rule-based/hybrid, algorithm family.\n2.3 Model Tier — per bank\'s model tiering (Tier 1 Critical, Tier 2 Significant, Tier 3 Standard).\n2.4 Model Lineage — predecessor models, change history.', true),
            new TemplateSection('3', 'Model Development Documentation',
                '3.1 Development Methodology — data selection, feature engineering, algorithm selection rationale.\n3.2 Training Data — sources, size, representativeness, vintage.\n3.3 Assumptions & Limitations — key assumptions, known limitations, boundary conditions.\n3.4 Performance Metrics — accuracy, precision, recall, AUC, or business-specific KPIs.\n3.5 Benchmark Comparison — performance vs. challenger models or rule-based alternatives.', true),
            new TemplateSection('4', 'Model Validation',
                '4.1 Independent Validation — who validated, methodology, scope.\n4.2 Backtesting Results — out-of-sample performance, stability tests.\n4.3 Sensitivity Analysis — key input sensitivities, stress scenarios.\n4.4 Conceptual Soundness — theoretical basis assessment.', true),
            new TemplateSection('5', 'Bias & Fairness Assessment',
                '5.1 Protected Attributes Tested — caste, religion, gender, geography, age, disability.\n5.2 Fairness Metrics — demographic parity, equalised odds, calibration by group.\n5.3 Bias Mitigation — actions taken to address identified bias.\n5.4 Ongoing Monitoring — automated fairness dashboards, alert thresholds.', true),
            new TemplateSection('6', 'Explainability & Transparency',
                '6.1 Explainability Method — SHAP, LIME, feature importance, rule extraction.\n6.2 Customer-Facing Explanations — per RBI RBC Directions §DA, can decisions be explained to affected parties?\n6.3 Regulatory Explanation Capability — can the model\'s logic be explained to RBI examiners?', true),
            new TemplateSection('7', 'Ongoing Monitoring Plan',
                '7.1 Performance Monitoring — KPIs tracked, frequency, thresholds for action.\n7.2 Data Drift Detection — input distribution monitoring, concept drift detection.\n7.3 Model Retraining Triggers — what triggers retraining or recalibration.\n7.4 Incident Escalation — model failure scenarios and escalation path.', true),
            new TemplateSection('8', 'Risk Assessment & Residual Risk',
                'Model Risk Score, key risk factors, mitigating controls, residual risk acceptance (if any).', true),
            new TemplateSection('9', 'Sign-Off',
                'Model Owner sign-off, Model Validation sign-off, Model Risk Committee approval, CRO acknowledgement.', true)
        };
        return t;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEMPLATE 4: Board/Executive AI Governance Note
    // For Board AI Risk Committee or CXO-level approval
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private static FilingTemplate buildBoardNoteTemplate() {
        FilingTemplate t = new FilingTemplate();
        t.templateType = 'BOARD_NOTE';
        t.templateName = 'Board Note – AI Use Case Approval';
        t.description = 'Executive summary note for Board-level AI Risk Committee, suitable for inclusion in Board meeting agenda papers.';
        t.regulator = 'Internal Governance';
        t.instrument = 'RBI Corporate Governance Guidelines; Bank AI Governance Policy';
        t.sections = new List<TemplateSection>{
            new TemplateSection('1', 'Agenda Item Reference',
                'Board Meeting Date, Agenda Item Number, Subject Line, Presented By, Department.', true),
            new TemplateSection('2', 'Proposal Summary',
                'In 200 words or less: What is being proposed, why, and what approval is sought. Clear statement of the ask.', true),
            new TemplateSection('3', 'Background & Business Case',
                '3.1 Business Problem — what customer/operational problem this solves.\n3.2 Expected Benefits — quantified where possible (efficiency gain, customer experience improvement, cost reduction).\n3.3 Strategic Alignment — how this aligns with the bank\'s digital and AI strategy.', true),
            new TemplateSection('4', 'AI Use Case Overview',
                '4.1 Agent Description — what it does, which channels, which customers.\n4.2 Technology Stack — platform (Salesforce Agentforce), model/AI type.\n4.3 Deployment Plan — phased rollout, pilot scope, go-live timeline.', true),
            new TemplateSection('5', 'Risk Summary',
                '5.1 Risk Tier — classification and rationale.\n5.2 Top 3 Risks — highest-impact risks with current mitigation status.\n5.3 Regulatory Exposure — which regulators and key obligations.', true),
            new TemplateSection('6', 'Compliance Posture',
                'One-paragraph summary + table: Total Clauses | Met | Gaps | N/A. Highlight any critical gaps that must be closed before go-live.', true),
            new TemplateSection('7', 'Resource Requirements',
                'Team, budget, infrastructure, timeline to production. Any incremental spend requiring Board approval.', false),
            new TemplateSection('8', 'Recommendation',
                'Clear recommendation: Approve / Approve with Conditions / Defer. If conditional, list conditions.', true),
            new TemplateSection('9', 'Resolution',
                'Draft Board resolution text for approval, including any conditions or delegated authorities.', true)
        };
        return t;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEMPLATE 5: Cybersecurity Compliance Report
    // Per RBI CTRA Framework 2026 + CERT-In Directions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private static FilingTemplate buildCyberSecurityTemplate() {
        FilingTemplate t = new FilingTemplate();
        t.templateType = 'CYBERSECURITY';
        t.templateName = 'Cybersecurity Compliance Assessment – AI System';
        t.description = 'Cybersecurity assessment for AI agent deployment per RBI CTRA Framework 2026 and CERT-In Directions.';
        t.regulator = 'RBI / CERT-In';
        t.instrument = 'Cybersecurity, Technology: Risk, Resilience and Assurance Framework Directions, 2026 (RBI/DoS/2026-27/410); CERT-In Directions under s.70B(6) IT Act';
        t.sections = new List<TemplateSection>{
            new TemplateSection('1', 'Document Control',
                'Assessment Reference, Date, System Name, CISO Sign-Off, Classification.', true),
            new TemplateSection('2', 'System Description',
                '2.1 AI Agent Architecture — components, integrations, data flows.\n2.2 Network Topology — where the agent runs, network zones, external connectivity.\n2.3 Data Classification — data types processed, sensitivity levels per RBI classification.', true),
            new TemplateSection('3', 'Threat Assessment',
                '3.1 Threat Landscape — AI-specific threats (prompt injection, model extraction, data poisoning, adversarial inputs).\n3.2 Attack Surface Analysis — entry points, API exposure, user interaction channels.\n3.3 Threat Modelling — STRIDE or equivalent for the AI agent.', true),
            new TemplateSection('4', 'Security Controls Assessment',
                '4.1 Identity & Access Management — authentication mechanism, least privilege, MFA.\n4.2 Data Protection — encryption at rest (AES-256), in transit (TLS 1.2+), tokenisation.\n4.3 Input Validation — prompt injection defences, input sanitisation.\n4.4 Output Controls — PII masking, hallucination safeguards, response filtering.\n4.5 API Security — rate limiting, authentication, OWASP API Top 10 compliance.\n4.6 Logging & Monitoring — SIEM integration, anomaly detection, audit trail integrity.', true),
            new TemplateSection('5', 'Incident Response Readiness',
                '5.1 CERT-In Compliance — 6-hour reporting capability for AI security incidents.\n5.2 AI-Specific Incident Playbook — model compromise, data leak, adversarial attack response.\n5.3 Communication Plan — internal escalation, regulatory notification, customer notification.\n5.4 Recovery Procedures — model rollback, kill switch, manual fallback.', true),
            new TemplateSection('6', 'Vulnerability Assessment & Penetration Testing',
                '6.1 VAPT Schedule — last test date, next scheduled test.\n6.2 AI-Specific Testing — adversarial testing, red-teaming results.\n6.3 Remediation Status — open findings, severity, target closure dates.', true),
            new TemplateSection('7', 'Compliance Mapping',
                'Table mapping RBI CTRA controls to implementation status for this AI agent. Include CERT-In directive compliance points.', true),
            new TemplateSection('8', 'Risk Rating & Recommendations',
                'Overall cyber risk rating (High/Medium/Low), residual risks, recommended actions before go-live.', true),
            new TemplateSection('9', 'CISO Certification',
                'CISO attestation that the AI system meets the bank\'s cybersecurity standards and applicable regulatory requirements.', true)
        };
        return t;
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEMPLATE 6: Regulatory Compliance Certificate
    // Cross-regulator compliance attestation
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private static FilingTemplate buildRegulatoryComplianceCertTemplate() {
        FilingTemplate t = new FilingTemplate();
        t.templateType = 'REG_COMPLIANCE_CERT';
        t.templateName = 'Regulatory Compliance Certificate – AI Agent';
        t.description = 'Cross-regulator compliance attestation covering RBI, MeitY/DPDP, SEBI, IRDAI, CERT-In obligations for AI deployment.';
        t.regulator = 'Multi-Regulator';
        t.instrument = 'Applicable RBI Directions, DPDP Act 2023, SEBI Circulars, IRDAI Guidelines, CERT-In Directions';
        t.sections = new List<TemplateSection>{
            new TemplateSection('1', 'Certificate Header',
                'Certificate Number, Issue Date, AI Agent Name, Governance Pack Reference, Certifying Officer, Validity Period.', true),
            new TemplateSection('2', 'Scope of Certification',
                'What this certificate covers: AI agent name, version, deployment scope, customer segments, channels, data processed.', true),
            new TemplateSection('3', 'Regulatory Applicability Summary',
                'Table: Regulator | Number of Applicable Clauses | Met | Gap | Compliance % | Key Instruments.\nOne row per regulator. Include total row.', true),
            new TemplateSection('4', 'RBI Compliance Attestation',
                '4.1 IT Governance Framework — compliant / non-compliant with specific clause references.\n4.2 FREE-AI Framework — alignment status.\n4.3 Outsourcing Directions — third-party risk assessment status.\n4.4 KYC Directions — if applicable.\n4.5 Digital Lending Guidelines — if applicable.\n4.6 Model Risk Management — validation status.', true),
            new TemplateSection('5', 'DPDP Act Compliance Attestation',
                '5.1 Consent Management — implemented / not implemented.\n5.2 Data Principal Rights — implemented / not implemented.\n5.3 DPIA Completed — yes/no, reference number.\n5.4 Cross-Border Transfers — compliant / N/A.\n5.5 Breach Notification Mechanism — in place / not in place.', true),
            new TemplateSection('6', 'SEBI Compliance Attestation',
                '6.1 AI/ML Disclosure Requirements — met / not applicable.\n6.2 Cybersecurity Framework Compliance — status.\n6.3 Intermediary Conduct Standards — if applicable.', true),
            new TemplateSection('7', 'IRDAI Compliance Attestation',
                '7.1 Policyholder Protection — if applicable.\n7.2 Information Sharing Requirements — status.\n7.3 Cybersecurity Guidelines — status.', true),
            new TemplateSection('8', 'CERT-In / Security Compliance',
                '8.1 Incident Reporting Readiness — 6-hour mandate compliance.\n8.2 AI-Specific Threat Mitigations — status.\n8.3 Aadhaar Data Vault Compliance — if applicable.', true),
            new TemplateSection('9', 'Material Gaps & Conditions',
                'List any material gaps that exist at time of certification, with remediation timeline and risk acceptance if applicable.', true),
            new TemplateSection('10', 'Certification Statement',
                'Formal statement: "Based on the assessment conducted, I certify that [Agent Name] [meets / meets with conditions / does not meet] the applicable regulatory requirements..." Signed by Compliance Officer, countersigned by CISO.', true)
        };
        return t;
    }
}
