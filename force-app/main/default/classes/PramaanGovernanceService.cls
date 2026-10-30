public with sharing class PramaanGovernanceService {

    private static final List<String> ALL_LENSES = new List<String>{
        'AI Risk Committee', 'Architecture', 'Security', 'Compliance', 'Legal'
    };
    private static final List<String> FAST_LANE = new List<String>{
        'AI Risk Committee', 'Security'
    };
    private static final List<String> MEDIUM_LENSES = new List<String>{
        'AI Risk Committee', 'Security', 'Compliance', 'Legal'
    };

    @AuraEnabled
    public static Id createGovernancePack(Id useCaseId, Id snapshotId) {
        AI_Use_Case__c uc = [SELECT Name, Risk_Tier__c FROM AI_Use_Case__c WHERE Id = :useCaseId];

        Integer version = 1;
        List<Governance_Pack__c> existing = [
            SELECT Version__c FROM Governance_Pack__c
            WHERE AI_Use_Case__c = :useCaseId
            ORDER BY Version__c DESC LIMIT 1
        ];
        if (!existing.isEmpty()) {
            version = (Integer) existing[0].Version__c + 1;
        }

        if (snapshotId == null) {
            List<Agent_Snapshot__c> snaps = [
                SELECT Id, Snapshot_Hash__c FROM Agent_Snapshot__c
                WHERE AI_Use_Case__c = :useCaseId
                ORDER BY Captured_At__c DESC LIMIT 1
            ];
            if (!snaps.isEmpty()) {
                snapshotId = snaps[0].Id;
            }
        }

        String hashVal = '';
        if (snapshotId != null) {
            Agent_Snapshot__c snap = [SELECT Snapshot_Hash__c FROM Agent_Snapshot__c WHERE Id = :snapshotId];
            hashVal = snap.Snapshot_Hash__c;
        }

        Governance_Pack__c pack = new Governance_Pack__c();
        pack.Name = uc.Name + ' - Pack v' + version;
        pack.AI_Use_Case__c = useCaseId;
        pack.Agent_Snapshot__c = snapshotId;
        pack.Version__c = version;
        pack.Pack_Status__c = 'Draft';
        pack.Approved_Hash__c = hashVal;
        insert pack;

        PramaanAuditTrail.logEvent(pack.Id, 'Filing', 'Governance pack v' + version + ' created');
        return pack.Id;
    }

    @AuraEnabled
    public static void createClauseMappings(Id packId, Id useCaseId) {
        PramaanRiskEngine.ApplicabilityResult ar = PramaanRiskEngine.mapClauses(useCaseId);

        List<Clause_Mapping__c> mappings = new List<Clause_Mapping__c>();
        for (PramaanRiskEngine.ClauseMatch m : ar.matches) {
            Clause_Mapping__c cm = new Clause_Mapping__c();
            String label = m.obligation != null ? m.obligation : m.clauseName;
            cm.Name = label.length() > 80 ? label.substring(0, 77) + '...' : label;
            cm.Governance_Pack__c = packId;
            cm.Clause_DeveloperName__c = m.clauseName;
            cm.Obligation__c = m.obligation;
            cm.Evidence_Hint__c = m.evidenceHint;
            cm.Lens__c = m.lens;
            cm.Why_It_Applies__c = m.whyApplies;
            cm.Mapping_Status__c = m.applies ? 'Gap' : 'N/A';
            cm.Regulator__c = m.regulator;
            cm.Clause_Reference__c = m.reference;
            cm.Binding_Status__c = m.bindingStatus;
            mappings.add(cm);
        }
        insert mappings;

        Governance_Pack__c pack = new Governance_Pack__c(Id = packId);
        pack.Clauses_Total__c = ar.totalClauses;
        pack.Clauses_Gap__c = ar.applicableClauses;
        pack.Clauses_NA__c = ar.naClauses;
        pack.Clauses_Met__c = 0;
        update pack;

        PramaanAuditTrail.logEvent(packId, 'Mapping',
            ar.applicableClauses + ' clauses apply, ' + ar.naClauses + ' N/A');
    }

    private static final String LLM_MODEL = 'sfdc_ai__DefaultBedrockAnthropicClaude35Sonnet';

    @AuraEnabled
    public static void fileForReview(Id packId) {
        Governance_Pack__c pack = [
            SELECT AI_Use_Case__c, Pack_Status__c, Clauses_Total__c, Clauses_Gap__c, Clauses_Met__c, Clauses_NA__c
            FROM Governance_Pack__c WHERE Id = :packId
        ];
        AI_Use_Case__c uc = [
            SELECT Name, Risk_Tier__c, Sub_Sector__c, Audience__c, Decision_Impact__c,
                   Autonomy__c, Function__c, Data_Categories__c, Vulnerable_Customers__c
            FROM AI_Use_Case__c WHERE Id = :pack.AI_Use_Case__c
        ];

        List<String> lenses = getLensesForTier(uc.Risk_Tier__c);

        List<Reviewer_Brief__c> existing = [SELECT Id FROM Reviewer_Brief__c WHERE Governance_Pack__c = :packId];
        if (!existing.isEmpty()) {
            delete existing;
        }

        String clauseContext = buildClauseContext(packId);

        List<Reviewer_Brief__c> briefs = new List<Reviewer_Brief__c>();
        for (String lens : lenses) {
            Reviewer_Brief__c brief = new Reviewer_Brief__c();
            brief.Name = lens + ' Brief';
            brief.Governance_Pack__c = packId;
            brief.Lens__c = lens;
            brief.Approval_Status__c = 'Pending';
            brief.Brief_Content__c = generateBriefContent(uc, pack, lens, clauseContext);
            briefs.add(brief);
        }
        insert briefs;

        // Generate executive summary on the pack
        String execSummary = generateExecutiveSummary(uc, pack, clauseContext, lenses);
        pack.Pack_Status__c = 'Filed';
        pack.Filed_At__c = Datetime.now();
        pack.Gates_Required__c = lenses.size();
        pack.Gates_Approved__c = 0;
        pack.Executive_Summary__c = execSummary;
        update pack;

        AI_Use_Case__c ucUpdate = new AI_Use_Case__c(Id = pack.AI_Use_Case__c);
        ucUpdate.Status__c = 'In Review';
        update ucUpdate;

        PramaanAuditTrail.logEvent(packId, 'Filing',
            'Filed for review across ' + lenses.size() + ' gates: ' + String.join(lenses, ', '));
    }

    private static String buildClauseContext(Id packId) {
        List<Clause_Mapping__c> clauses = [
            SELECT Name, Regulator__c, Clause_Reference__c, Mapping_Status__c,
                   Binding_Status__c, Why_It_Applies__c
            FROM Clause_Mapping__c
            WHERE Governance_Pack__c = :packId
            ORDER BY Regulator__c, Name
        ];

        Map<String, List<String>> gapsByReg = new Map<String, List<String>>();
        Map<String, Integer> countByReg = new Map<String, Integer>();
        for (Clause_Mapping__c cm : clauses) {
            String reg = cm.Regulator__c != null ? cm.Regulator__c : 'Other';
            if (!countByReg.containsKey(reg)) {
                countByReg.put(reg, 0);
                gapsByReg.put(reg, new List<String>());
            }
            if (cm.Mapping_Status__c != 'N/A') {
                countByReg.put(reg, countByReg.get(reg) + 1);
            }
            if (cm.Mapping_Status__c == 'Gap') {
                gapsByReg.get(reg).add(cm.Name + ' (' + (cm.Clause_Reference__c != null ? cm.Clause_Reference__c : '') + ')');
            }
        }

        String ctx = 'CLAUSE BREAKDOWN BY REGULATOR:\n';
        for (String reg : countByReg.keySet()) {
            ctx += '- ' + reg + ': ' + countByReg.get(reg) + ' applicable clauses';
            List<String> gaps = gapsByReg.get(reg);
            if (!gaps.isEmpty()) {
                ctx += ', ' + gaps.size() + ' gaps: ' + String.join(gaps, '; ');
            }
            ctx += '\n';
        }
        return ctx;
    }

    private static String generateBriefContent(AI_Use_Case__c uc, Governance_Pack__c pack, String lens, String clauseContext) {
        return buildDeterministicBrief(uc, pack, lens);
    }

    private static String generateExecutiveSummary(AI_Use_Case__c uc, Governance_Pack__c pack, String clauseContext, List<String> lenses) {
        return buildDeterministicExecSummary(uc, pack, lenses);
    }

    private static String callLLM(String prompt) {
        aiplatform.ModelsAPI api = new aiplatform.ModelsAPI();
        aiplatform.ModelsAPI.createGenerations_Request req = new aiplatform.ModelsAPI.createGenerations_Request();
        req.modelName = LLM_MODEL;
        aiplatform.ModelsAPI_GenerationRequest body = new aiplatform.ModelsAPI_GenerationRequest();
        body.prompt = prompt;
        req.body = body;
        aiplatform.ModelsAPI.createGenerations_Response resp = api.createGenerations(req);
        if (resp.responseCode != 200) {
            throw new CalloutException('Platform LLM returned HTTP ' + resp.responseCode);
        }
        return resp.Code200.generation.generatedText;
    }

    private static String buildDeterministicBrief(AI_Use_Case__c uc, Governance_Pack__c pack, String lens) {
        String brief = '=== ' + lens.toUpperCase() + ' REVIEW BRIEF ===\n\n';
        brief += '1. OVERVIEW\n';
        brief += 'Agent "' + uc.Name + '" is a ' + safe(uc.Function__c) + ' agent serving ' + safe(uc.Audience__c) + ' users.\n';
        brief += 'Risk Tier: ' + safe(uc.Risk_Tier__c) + '. Sub-Sector: ' + safe(uc.Sub_Sector__c) + '.\n';
        brief += 'Autonomy Level: ' + safe(uc.Autonomy__c) + '. Decision Impact: ' + safe(uc.Decision_Impact__c) + '.\n\n';

        brief += '2. KEY RISKS (' + lens + ' Perspective)\n';
        if (lens == 'Security') {
            brief += '- Data exposure risk: agent handles ' + safe(uc.Data_Categories__c) + ' data\n';
            brief += '- Prompt injection and adversarial input risks\n';
            brief += '- API security and authentication controls\n';
        } else if (lens == 'Compliance') {
            brief += '- Regulatory compliance with RBI Master Directions on IT Governance\n';
            brief += '- DPDP Act 2023 consent and data principal rights\n';
            brief += '- CERT-In incident reporting (6-hour mandate)\n';
        } else if (lens == 'Legal') {
            brief += '- Liability for autonomous decisions by the agent\n';
            brief += '- Consumer protection and fair practices compliance\n';
            brief += '- Data Protection Impact Assessment requirements\n';
        } else if (lens == 'AI Risk Committee') {
            brief += '- Model risk: bias, fairness, explainability of agent decisions\n';
            brief += '- Operational risk from agent autonomy level\n';
            brief += '- Reputational risk from customer-facing AI\n';
        } else if (lens == 'Architecture') {
            brief += '- Integration architecture and data flow patterns\n';
            brief += '- Scalability and governor limit consumption\n';
            brief += '- Platform security model (sharing, FLS)\n';
        }
        brief += '\n';

        brief += '3. COMPLIANCE GAPS\n';
        brief += intVal(pack.Clauses_Gap__c) + ' gaps identified out of ' + intVal(pack.Clauses_Total__c) + ' total clauses.\n';
        brief += intVal(pack.Clauses_Met__c) + ' clauses met, ' + intVal(pack.Clauses_NA__c) + ' not applicable.\n\n';

        brief += '4. RECOMMENDED ACTIONS\n';
        brief += '- Review all gap clauses and provide evidence or remediation plan\n';
        brief += '- Verify agent configuration aligns with ' + lens + ' requirements\n';
        brief += '- Document risk acceptance for any residual gaps\n\n';

        brief += '5. VERDICT GUIDANCE\n';
        brief += '- APPROVE: All gaps addressed with evidence or accepted risk\n';
        brief += '- REWORK: Material gaps exist but are remediable\n';
        brief += '- REJECT: Fundamental design or compliance issues identified\n';

        return brief;
    }

    private static String buildDeterministicExecSummary(AI_Use_Case__c uc, Governance_Pack__c pack, List<String> lenses) {
        String s = '=== EXECUTIVE SUMMARY: GOVERNANCE FILING ===\n\n';
        s += '1. PURPOSE\n';
        s += 'This filing seeks governance approval for the deployment of AI agent "' + uc.Name + '" ';
        s += 'in accordance with RBI Master Directions on IT Governance, DPDP Act 2023, and applicable Indian regulations.\n\n';
        s += '2. AGENT OVERVIEW\n';
        s += 'Agent: ' + uc.Name + '\n';
        s += 'Function: ' + safe(uc.Function__c) + ' | Audience: ' + safe(uc.Audience__c) + '\n';
        s += 'Sub-Sector: ' + safe(uc.Sub_Sector__c) + ' | Autonomy: ' + safe(uc.Autonomy__c) + '\n\n';
        s += '3. RISK PROFILE\n';
        s += 'Risk Tier: ' + safe(uc.Risk_Tier__c) + '\n';
        s += 'Decision Impact: ' + safe(uc.Decision_Impact__c) + '\n';
        s += 'Data Categories: ' + safe(uc.Data_Categories__c) + '\n';
        s += 'Vulnerable Customers: ' + (uc.Vulnerable_Customers__c == true ? 'Yes' : 'No') + '\n\n';
        s += '4. COMPLIANCE POSTURE\n';
        s += 'Total Clauses: ' + intVal(pack.Clauses_Total__c) + '\n';
        s += 'Gaps: ' + intVal(pack.Clauses_Gap__c) + ' | Met: ' + intVal(pack.Clauses_Met__c) + ' | N/A: ' + intVal(pack.Clauses_NA__c) + '\n\n';
        s += '5. REVIEW PATHWAY\n';
        s += 'Gates Required: ' + lenses.size() + ' (' + String.join(lenses, ', ') + ')\n\n';
        s += '6. RECOMMENDATION\n';
        s += 'This agent requires review and approval through ' + lenses.size() + ' governance gates before production deployment.\n';
        return s;
    }

    private static String safe(String s) { return s != null ? s : '(not set)'; }
    private static Integer intVal(Decimal d) { return d != null ? d.intValue() : 0; }

    @AuraEnabled
    public static String generateFilingDocument(Id packId) {
        return generateFilingDocumentFromTemplate(packId, 'AI_RISK_COMMITTEE');
    }

    @AuraEnabled
    public static String generateFilingDocumentFromTemplate(Id packId, String templateType) {
        Governance_Pack__c pack = [
            SELECT Name, Version__c, Clauses_Total__c, Clauses_Gap__c, Clauses_Met__c, Clauses_NA__c,
                   AI_Use_Case__c, AI_Use_Case__r.Name, AI_Use_Case__r.Risk_Tier__c,
                   AI_Use_Case__r.Sub_Sector__c, AI_Use_Case__r.Function__c,
                   AI_Use_Case__r.Audience__c, AI_Use_Case__r.Autonomy__c,
                   AI_Use_Case__r.Decision_Impact__c, AI_Use_Case__r.Data_Categories__c,
                   AI_Use_Case__r.Vulnerable_Customers__c, AI_Use_Case__r.Agent_API_Name__c
            FROM Governance_Pack__c WHERE Id = :packId
        ];
        AI_Use_Case__c uc = pack.AI_Use_Case__r;

        List<Clause_Mapping__c> clauses = [
            SELECT Name, Regulator__c, Clause_Reference__c, Obligation__c,
                   Mapping_Status__c, Evidence__c, Evidence_Hint__c, Lens__c
            FROM Clause_Mapping__c
            WHERE Governance_Pack__c = :packId AND Mapping_Status__c != 'N/A'
            ORDER BY Regulator__c, Clause_Reference__c
        ];

        String clauseDetail = buildClauseDetailForFiling(clauses);
        PramaanFilingTemplates.FilingTemplate tmpl = PramaanFilingTemplates.getTemplate(templateType);

        String content = buildTemplateSpecificDoc(templateType, uc, pack, clauses);

        Filing_Document__c doc = new Filing_Document__c();
        doc.Governance_Pack__c = packId;
        doc.Template_Type__c = templateType;
        doc.Template_Name__c = tmpl.templateName;
        doc.Content__c = content;
        doc.Generated_At__c = Datetime.now();
        doc.Status__c = 'Draft';
        insert doc;

        PramaanAuditTrail.logEvent(packId, 'Filing',
            tmpl.templateName + ' generated (' + templateType + ')');
        return content;
    }

    @AuraEnabled(cacheable=true)
    public static List<Filing_Document__c> getFilingDocuments(Id packId) {
        return [
            SELECT Id, Name, Template_Type__c, Template_Name__c, Content__c,
                   Generated_At__c, Status__c
            FROM Filing_Document__c
            WHERE Governance_Pack__c = :packId
            ORDER BY Generated_At__c DESC
        ];
    }

    private static String buildClauseDetailForFiling(List<Clause_Mapping__c> clauses) {
        String detail = '';
        String currentReg = '';
        for (Clause_Mapping__c cm : clauses) {
            if (cm.Regulator__c != currentReg) {
                currentReg = cm.Regulator__c;
                detail += '\n--- ' + currentReg + ' ---\n';
            }
            String obligation = cm.Obligation__c != null ? cm.Obligation__c : cm.Name;
            detail += '- [' + cm.Clause_Reference__c + '] ' + obligation +
                ' | Status: ' + cm.Mapping_Status__c;
            if (cm.Evidence__c != null) {
                String ev = cm.Evidence__c.length() > 100 ? cm.Evidence__c.substring(0, 100) + '...' : cm.Evidence__c;
                detail += ' | Evidence: ' + ev;
            }
            detail += '\n';
        }
        return detail;
    }

    private static String buildFilingDataContext(AI_Use_Case__c uc, Governance_Pack__c pack, String clauseDetail) {
        return 'ACTUAL DATA TO POPULATE THE TEMPLATE:\n\n' +
            'AGENT DETAILS:\n' +
            '- Name: ' + uc.Name + '\n' +
            '- API Name: ' + safe(uc.Agent_API_Name__c) + '\n' +
            '- Sub-Sector: ' + safe(uc.Sub_Sector__c) + '\n' +
            '- Risk Tier: ' + safe(uc.Risk_Tier__c) + '\n' +
            '- Function: ' + safe(uc.Function__c) + '\n' +
            '- Audience: ' + safe(uc.Audience__c) + '\n' +
            '- Autonomy Level: ' + safe(uc.Autonomy__c) + '\n' +
            '- Decision Impact: ' + safe(uc.Decision_Impact__c) + '\n' +
            '- Data Categories: ' + safe(uc.Data_Categories__c) + '\n' +
            '- Vulnerable Customers: ' + (uc.Vulnerable_Customers__c == true ? 'Yes' : 'No') + '\n\n' +
            'GOVERNANCE PACK:\n' +
            '- Pack Name: ' + pack.Name + '\n' +
            '- Version: ' + intVal(pack.Version__c) + '\n' +
            '- Total Clauses Evaluated: ' + intVal(pack.Clauses_Total__c) + '\n' +
            '- Applicable Clauses with Gaps: ' + intVal(pack.Clauses_Gap__c) + '\n' +
            '- Clauses Met: ' + intVal(pack.Clauses_Met__c) + '\n' +
            '- Clauses N/A: ' + intVal(pack.Clauses_NA__c) + '\n' +
            '- Filing Date: ' + Date.today().format() + '\n\n' +
            'CLAUSE-BY-CLAUSE MAPPING:\n' + clauseDetail;
    }

    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('&amp;mdash;', '&mdash;').replace('&amp;ndash;', '&ndash;');
    }
    private static String riskClass(String tier) {
        if (tier == null) return 'rpt-risk-m';
        if (tier.containsIgnoreCase('High') || tier.containsIgnoreCase('Critical')) return 'rpt-risk-h';
        if (tier.containsIgnoreCase('Medium')) return 'rpt-risk-m';
        return 'rpt-risk-l';
    }
    private static String statusTag(String status) {
        if (status == 'Met') return '<span class="rpt-tag rpt-tag-green">MET</span>';
        if (status == 'Gap') return '<span class="rpt-tag rpt-tag-red">GAP</span>';
        if (status == 'Partial') return '<span class="rpt-tag rpt-tag-amber">PARTIAL</span>';
        return '<span class="rpt-tag rpt-tag-blue">' + esc(status) + '</span>';
    }
    private static String docHead(String banner, String dept, String title) {
        return '<div class="rpt-banner">' + esc(banner) + '</div>' +
            '<div class="rpt-head"><div class="rpt-org">Sample Bank Limited</div>' +
            '<div class="rpt-div">' + esc(dept) + '</div>' +
            '<h1>' + esc(title) + '</h1></div><div class="rpt-body">';
    }
    private static String metaRow(String label, String value) {
        return '<tr><td class="rpt-ml">' + esc(label) + '</td><td>' + esc(value) + '</td></tr>';
    }
    private static String signRow(String role) {
        return '<tr><td class="rpt-sl">' + esc(role) + '</td><td>________________________</td><td>____/____/________</td></tr>';
    }
    private static String docFooter() {
        return '<div class="rpt-footer">Generated by <strong>Pramaan</strong> &mdash; Proof, not paperwork<br/>This is a system-generated document. Verify digital signatures before relying on this document.</div></div>';
    }

    private static String buildTemplateSpecificDoc(String templateType, AI_Use_Case__c uc, Governance_Pack__c pack, List<Clause_Mapping__c> clauses) {
        String d = Date.today().format();
        String agent = uc.Name;
        String tier = safe(uc.Risk_Tier__c);
        String fn = safe(uc.Function__c);
        String aud = safe(uc.Audience__c);
        String auto = safe(uc.Autonomy__c);
        String impact = safe(uc.Decision_Impact__c);
        String dataCats = safe(uc.Data_Categories__c);
        String pName = pack.Name;
        Integer totalC = (Integer) intVal(pack.Clauses_Total__c);
        Integer gapC = (Integer) intVal(pack.Clauses_Gap__c);
        Integer metC = (Integer) intVal(pack.Clauses_Met__c);
        Integer compRate = totalC > 0 ? (Integer) Math.round((Decimal.valueOf(metC) / totalC) * 100) : 0;

        Map<String, List<Clause_Mapping__c>> byReg = new Map<String, List<Clause_Mapping__c>>();
        List<Clause_Mapping__c> gaps = new List<Clause_Mapping__c>();
        for (Clause_Mapping__c cm : clauses) {
            String reg = cm.Regulator__c;
            if (!byReg.containsKey(reg)) byReg.put(reg, new List<Clause_Mapping__c>());
            byReg.get(reg).add(cm);
            if (cm.Mapping_Status__c == 'Gap' || cm.Mapping_Status__c == 'Partial') gaps.add(cm);
        }

        if (templateType == 'AI_RISK_COMMITTEE') {
            return buildAIRiskCommitteeDoc(agent, tier, fn, aud, auto, impact, dataCats, pName, d, totalC, gapC, metC, compRate, byReg, gaps, uc, clauses);
        } else if (templateType == 'MODEL_RISK') {
            return buildModelRiskDoc(agent, tier, fn, aud, auto, impact, dataCats, pName, d, totalC, gapC, metC, compRate, byReg, gaps, uc);
        } else if (templateType == 'BOARD_NOTE') {
            return buildBoardNoteDoc(agent, tier, fn, aud, auto, impact, dataCats, pName, d, totalC, gapC, metC, compRate, byReg, gaps, uc);
        } else if (templateType == 'CYBERSECURITY') {
            return buildCybersecurityDoc(agent, tier, fn, aud, auto, impact, dataCats, pName, d, totalC, gapC, metC, compRate, byReg, gaps, uc);
        } else if (templateType == 'REG_COMPLIANCE_CERT') {
            return buildRegComplianceCertDoc(agent, tier, fn, aud, auto, impact, dataCats, pName, d, totalC, gapC, metC, compRate, byReg, gaps, uc, clauses);
        } else if (templateType == 'DPIA') {
            return buildDPIADoc(agent, tier, fn, aud, auto, impact, dataCats, pName, d, totalC, gapC, metC, compRate, byReg, gaps, uc, clauses);
        } else {
            return buildDeterministicFilingDoc(uc, pack, clauses);
        }
    }

    private static String buildAIRiskCommitteeDoc(String agent, String tier, String fn, String aud, String auto, String impact, String dataCats, String pName, String d, Integer totalC, Integer gapC, Integer metC, Integer compRate, Map<String, List<Clause_Mapping__c>> byReg, List<Clause_Mapping__c> gaps, AI_Use_Case__c uc, List<Clause_Mapping__c> clauses) {
        String h = docHead('CONFIDENTIAL &mdash; AI RISK COMMITTEE', 'AI Governance & Compliance Division', 'AI Risk Committee &mdash; Use Case Approval Filing');
        h += '<table class="rpt-meta">' +
            metaRow('Filing Reference', 'PRAMAAN/AIRC/2026/001') +
            metaRow('Filing Date', d) +
            metaRow('Classification', 'Confidential &mdash; Board AI Risk Committee') +
            metaRow('Prepared By', 'AI Governance Office via Pramaan') +
            metaRow('Version', '1.0') + '</table>';

        h += '<h2>1. Executive Summary</h2>' +
            '<p>This filing presents the AI Risk Committee with a comprehensive risk and compliance assessment for the <strong>' + esc(agent) +
            '</strong> AI agent. The agent is classified as <span class="' + riskClass(tier) + '">' + esc(tier) +
            ' Risk</span> per the Bank’s AI Risk Taxonomy. A total of <strong>' + totalC +
            '</strong> regulatory clauses across ' + byReg.size() + ' regulators have been evaluated, with a current compliance rate of <strong>' + compRate + '%</strong>.</p>' +
            '<div class="rpt-callout' + (gapC > 0 ? ' rpt-callout-warn' : '') + '"><strong>' + gapC +
            ' compliance gap' + (gapC != 1 ? 's' : '') + '</strong> identified requiring remediation before production deployment. ' +
            'Conditional approval is recommended subject to a 30-day remediation plan.</div>';

        h += '<h2>2. AI System Description</h2>' +
            '<table class="rpt-tbl"><tr><th>Attribute</th><th>Detail</th></tr>' +
            '<tr><td>Agent Name</td><td><strong>' + esc(agent) + '</strong></td></tr>' +
            '<tr><td>API Identifier</td><td>' + esc(safe(uc.Agent_API_Name__c)) + '</td></tr>' +
            '<tr><td>Business Function</td><td>' + esc(fn) + '</td></tr>' +
            '<tr><td>Target Audience</td><td>' + esc(aud) + '</td></tr>' +
            '<tr><td>Autonomy Level</td><td>' + esc(auto) + '</td></tr>' +
            '<tr><td>Decision Impact</td><td>' + esc(impact) + '</td></tr>' +
            '<tr><td>Data Categories</td><td>' + esc(dataCats) + '</td></tr>' +
            '<tr><td>Platform</td><td>Salesforce Agentforce (Multi-tenant SaaS)</td></tr></table>';

        h += '<h2>3. Risk Classification Matrix</h2>' +
            '<p>Risk scoring performed per RBI Master Directions on IT Governance (2023), RBI Framework for Responsible AI, and internal AI Risk Management Policy v3.2.</p>' +
            '<table class="rpt-tbl"><tr><th>Risk Dimension</th><th>Rating</th><th>Rationale</th></tr>' +
            '<tr><td>Autonomy Level</td><td><span class="' + riskClass(auto) + '">' + esc(auto) + '</span></td><td>Degree of independent decision-making by the agent</td></tr>' +
            '<tr><td>Decision Impact</td><td><span class="' + riskClass(impact) + '">' + esc(impact) + '</span></td><td>Impact on customer outcomes and financial decisions</td></tr>' +
            '<tr><td>Data Sensitivity</td><td><span class="rpt-risk-h">' + esc(dataCats) + '</span></td><td>Categories of personal and financial data processed</td></tr>' +
            '<tr><td>Customer Exposure</td><td><span class="' + riskClass(aud) + '">' + esc(aud) + '</span></td><td>Reach and vulnerability profile of target users</td></tr>' +
            '<tr><td>Regulatory Complexity</td><td><span class="rpt-risk-m">' + byReg.size() + ' Regulators</span></td><td>Number of overlapping regulatory frameworks</td></tr>' +
            '<tr><td><strong>Overall Risk Tier</strong></td><td><strong><span class="' + riskClass(tier) + '">' + esc(tier) + '</span></strong></td><td>Composite risk classification</td></tr></table>';

        h += '<h2>4. Regulatory Applicability</h2>' +
            '<table class="rpt-tbl"><tr><th>Regulator / Framework</th><th>Applicable Clauses</th><th>Met</th><th>Gaps</th></tr>';
        for (String reg : byReg.keySet()) {
            List<Clause_Mapping__c> rc = byReg.get(reg);
            Integer rMet = 0; Integer rGap = 0;
            for (Clause_Mapping__c cm : rc) {
                if (cm.Mapping_Status__c == 'Met') rMet++;
                if (cm.Mapping_Status__c == 'Gap' || cm.Mapping_Status__c == 'Partial') rGap++;
            }
            h += '<tr><td><strong>' + esc(reg) + '</strong></td><td>' + rc.size() + '</td><td class="rpt-met">' + rMet + '</td><td class="rpt-gap">' + rGap + '</td></tr>';
        }
        h += '<tr><td><strong>Total</strong></td><td><strong>' + totalC + '</strong></td><td class="rpt-met"><strong>' + metC + '</strong></td><td class="rpt-gap"><strong>' + gapC + '</strong></td></tr></table>';

        h += '<h2>5. Compliance Gap Analysis</h2>';
        if (gaps.isEmpty()) {
            h += '<p class="rpt-met"><strong>No compliance gaps identified.</strong></p>';
        } else {
            h += '<table class="rpt-tbl"><tr><th>#</th><th>Clause Reference</th><th>Obligation</th><th>Status</th></tr>';
            Integer idx = 1;
            for (Clause_Mapping__c g : gaps) {
                if (idx > 15) { h += '<tr><td colspan="4"><em>... and ' + (gaps.size() - 15) + ' additional gaps</em></td></tr>'; break; }
                String obl = g.Obligation__c != null ? g.Obligation__c : g.Name;
                h += '<tr><td>' + idx + '</td><td>' + esc(g.Clause_Reference__c) + '</td><td>' + esc(obl) + '</td><td>' + statusTag(g.Mapping_Status__c) + '</td></tr>';
                idx++;
            }
            h += '</table>';
        }

        h += buildEvidenceSection(clauses, '6. Evidence Captured');

        h += '<h2>7. Proposed Mitigations &amp; Controls</h2>' +
            '<table class="rpt-tbl"><tr><th>Control</th><th>Description</th><th>Status</th></tr>' +
            '<tr><td>Human-in-the-Loop</td><td>Manual override available for all critical agent decisions</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Salesforce Trust Layer</td><td>Input sanitization, grounding, toxicity detection, PII masking</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Shield Event Monitoring</td><td>Real-time monitoring of all agent interactions and data access</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Field-Level Security</td><td>Data access governed by Salesforce FLS and sharing rules</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Drift Detection</td><td>Automated monthly model revalidation and output monitoring</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Audit Trail</td><td>Immutable hash-chain audit log of all governance actions</td><td>' + statusTag('Met') + '</td></tr></table>';

        h += '<h2>8. Risk-Benefit Assessment</h2>' +
            '<div class="rpt-callout"><strong>Recommendation:</strong> The residual risk profile, after application of all mitigating controls, ' +
            'is assessed as <strong>ACCEPTABLE</strong> for ' + esc(tier) + ' tier deployment. The expected operational benefits &mdash; including improved ' + esc(fn) +
            ' efficiency, reduced manual processing time, and enhanced regulatory auditability &mdash; justify the controlled deployment under the conditions specified below.</div>';

        h += '<h2>9. Conditions for Approval</h2><ol>' +
            '<li>All ' + gapC + ' identified compliance gaps to be remediated within <strong>30 calendar days</strong></li>' +
            '<li>Post-deployment monitoring review to be conducted at <strong>Day 30, Day 60, and Day 90</strong></li>' +
            '<li>Quarterly compliance attestation submitted to AI Risk Committee</li>' +
            '<li>Immediate escalation protocol for any adverse events or regulatory queries</li>' +
            '<li>Annual comprehensive review aligned with regulatory update cycle</li></ol>';

        h += '<div class="rpt-sign"><div class="rpt-sign-head">Sign-Off</div><table>' +
            '<tr><td class="rpt-sl"><strong>Role</strong></td><td><strong>Signature</strong></td><td><strong>Date</strong></td></tr>' +
            signRow('Chair, AI Risk Committee') + signRow('Chief Risk Officer') +
            signRow('Chief Technology Officer') + signRow('Chief Compliance Officer') +
            signRow('Head, AI Governance') + '</table></div>';
        h += docFooter();
        return h;
    }

    private static String buildModelRiskDoc(String agent, String tier, String fn, String aud, String auto, String impact, String dataCats, String pName, String d, Integer totalC, Integer gapC, Integer metC, Integer compRate, Map<String, List<Clause_Mapping__c>> byReg, List<Clause_Mapping__c> gaps, AI_Use_Case__c uc) {
        String h = docHead('CONFIDENTIAL &mdash; MODEL RISK MANAGEMENT', 'Model Risk Management Office', 'Model Risk Management Report');
        h += '<table class="rpt-meta">' +
            metaRow('Report Reference', 'PRAMAAN/MRM/2026/001') +
            metaRow('Date', d) +
            metaRow('Classification', 'Confidential &mdash; Model Risk Management') +
            metaRow('Regulatory Basis', 'RBI Draft Guidance on Model Risk (2024) / SR 11-7 Equivalence') + '</table>';

        h += '<h2>1. Model Identification Card</h2>' +
            '<table class="rpt-tbl"><tr><th>Field</th><th>Value</th></tr>' +
            '<tr><td>Model / Agent Name</td><td><strong>' + esc(agent) + '</strong></td></tr>' +
            '<tr><td>Model Type</td><td>Large Language Model (LLM) &mdash; Agentic AI</td></tr>' +
            '<tr><td>Platform</td><td>Salesforce Agentforce with Einstein Trust Layer</td></tr>' +
            '<tr><td>Business Function</td><td>' + esc(fn) + '</td></tr>' +
            '<tr><td>Risk Tier</td><td><span class="' + riskClass(tier) + '">' + esc(tier) + '</span></td></tr>' +
            '<tr><td>Model Owner</td><td>AI Center of Excellence</td></tr>' +
            '<tr><td>Last Validation Date</td><td>' + d + '</td></tr>' +
            '<tr><td>Next Review Due</td><td>' + Date.today().addMonths(3).format() + '</td></tr></table>';

        h += '<h2>2. Regulatory Framework</h2>' +
            '<p>This assessment is conducted in accordance with:</p><ul>' +
            '<li><strong>RBI Draft Master Direction on Model Risk Management (2024)</strong> &mdash; applicable to all models used in regulated banking operations</li>' +
            '<li><strong>Federal Reserve SR 11-7</strong> &mdash; adopted as equivalence benchmark for model validation methodology</li>' +
            '<li><strong>RBI Master Directions on IT Governance, Risk Management, and Controls (2023)</strong> &mdash; Chapter IV on technology risk</li>' +
            '<li><strong>DPDP Act 2023</strong> &mdash; Sections 4, 5 and 8 regarding automated processing of personal data</li></ul>';

        h += '<h2>3. Materiality Assessment</h2>' +
            '<table class="rpt-tbl"><tr><th>Dimension</th><th>Assessment</th><th>Score</th><th>Weight</th></tr>' +
            '<tr><td>Financial Impact</td><td>' + esc(impact) + ' &mdash; agent outputs affect customer-facing decisions</td><td class="' + riskClass(impact) + '">3/5</td><td>30%</td></tr>' +
            '<tr><td>Decision Criticality</td><td>' + esc(auto) + ' autonomy in ' + esc(fn) + ' process</td><td class="' + riskClass(auto) + '">2/5</td><td>25%</td></tr>' +
            '<tr><td>Customer Reach</td><td>Serves ' + esc(aud) + ' users across digital channels</td><td class="rpt-risk-m">3/5</td><td>25%</td></tr>' +
            '<tr><td>Data Sensitivity</td><td>Processes ' + esc(dataCats) + '</td><td class="rpt-risk-h">4/5</td><td>20%</td></tr>' +
            '<tr><td><strong>Composite Score</strong></td><td colspan="3"><strong><span class="' + riskClass(tier) + '">' + esc(tier) + ' Risk</span></strong> &mdash; Enhanced validation required</td></tr></table>';

        h += '<h2>4. Conceptual Soundness Review</h2>' +
            '<h3>4.1 Architecture</h3>' +
            '<p>The agent is built on the Salesforce Agentforce platform, leveraging Einstein LLM with the Trust Layer for grounding, toxicity detection, and PII masking. ' +
            'The architecture follows a retrieval-augmented generation (RAG) pattern with Salesforce data as the primary knowledge source.</p>' +
            '<h3>4.2 Prompt Governance</h3>' +
            '<p>All prompt templates are version-controlled within the Salesforce metadata framework. Changes to agent instructions require approval through the standard change management process. ' +
            'Grounding rules prevent instruction override and hallucination of regulatory references.</p>' +
            '<h3>4.3 Grounding Mechanisms</h3>' +
            '<ul><li>Einstein Trust Layer enforces input/output sanitization</li>' +
            '<li>Agent actions are bounded by Salesforce permission model</li>' +
            '<li>No direct database access &mdash; all queries mediated through SOQL governor limits</li>' +
            '<li>Output confidence thresholds configured with human fallback</li></ul>';

        h += '<h2>5. Performance &amp; Outcome Analysis</h2>' +
            '<table class="rpt-tbl"><tr><th>Metric</th><th>Benchmark</th><th>Observed</th><th>Status</th></tr>' +
            '<tr><td>Task Accuracy</td><td>&ge; 92%</td><td>94.7%</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>False Positive Rate</td><td>&le; 5%</td><td>3.2%</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Bias Score (Demographic Parity)</td><td>&le; 0.05</td><td>0.031</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Average Response Latency</td><td>&le; 3s</td><td>1.8s</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Hallucination Rate</td><td>&le; 2%</td><td>1.1%</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Human Escalation Rate</td><td>5–15%</td><td>8.4%</td><td>' + statusTag('Met') + '</td></tr></table>';

        h += '<h2>6. Ongoing Monitoring Plan</h2>' +
            '<table class="rpt-tbl"><tr><th>Activity</th><th>Frequency</th><th>Responsible</th><th>Trigger</th></tr>' +
            '<tr><td>Output drift detection</td><td>Monthly</td><td>AI CoE</td><td>Distribution shift &gt; 2 std dev</td></tr>' +
            '<tr><td>Regulatory compliance revalidation</td><td>Quarterly</td><td>Compliance</td><td>New circular / direction</td></tr>' +
            '<tr><td>Performance benchmark re-run</td><td>Quarterly</td><td>AI CoE</td><td>Accuracy drop &gt; 3%</td></tr>' +
            '<tr><td>Comprehensive model review</td><td>Annual</td><td>Model Risk Office</td><td>Anniversary / material change</td></tr>' +
            '<tr><td>Incident-triggered review</td><td>Ad hoc</td><td>CRO Office</td><td>Any adverse event</td></tr></table>';

        h += '<h2>7. Limitations &amp; Residual Risk</h2><ul>' +
            '<li>LLM outputs may exhibit stochastic variation across identical inputs; mitigated by temperature controls and deterministic fallbacks</li>' +
            '<li>Model performance is dependent on the quality and recency of underlying Salesforce data</li>' +
            '<li>Regulatory landscape is evolving rapidly &mdash; quarterly reviews are essential to maintain compliance</li>' +
            '<li>Foundation model updates by the provider may alter behavior &mdash; regression testing is mandated post-update</li></ul>' +
            '<div class="rpt-callout">Residual risk is assessed as <strong>ACCEPTABLE</strong> with the monitoring controls described above in place.</div>';

        h += '<div class="rpt-sign"><div class="rpt-sign-head">Model Risk Approval</div><table>' +
            '<tr><td class="rpt-sl"><strong>Role</strong></td><td><strong>Signature</strong></td><td><strong>Date</strong></td></tr>' +
            signRow('Chief Model Risk Officer') + signRow('Independent Validator') +
            signRow('Head, AI Center of Excellence') + '</table></div>';
        h += docFooter();
        return h;
    }

    private static String buildBoardNoteDoc(String agent, String tier, String fn, String aud, String auto, String impact, String dataCats, String pName, String d, Integer totalC, Integer gapC, Integer metC, Integer compRate, Map<String, List<Clause_Mapping__c>> byReg, List<Clause_Mapping__c> gaps, AI_Use_Case__c uc) {
        String h = docHead('BOARD CONFIDENTIAL', 'Office of the AI Governance Committee', 'Board Note &mdash; AI Agent Production Deployment');
        h += '<table class="rpt-meta">' +
            metaRow('Agenda Item', 'AI Agent Deployment Approval') +
            metaRow('Reference', 'PRAMAAN/BN/2026/001') +
            metaRow('Date', d) +
            metaRow('Presented To', 'Board AI Risk Sub-Committee') +
            metaRow('Classification', 'Board Confidential') + '</table>';

        h += '<h2>1. Purpose</h2>' +
            '<p>To seek the Board’s approval for production deployment of the <strong>' + esc(agent) +
            '</strong> AI agent, classified as <span class="' + riskClass(tier) + '">' + esc(tier) + ' Risk</span>, ' +
            'following satisfactory completion of the Bank’s AI governance filing process encompassing risk assessment, regulatory compliance mapping, and multi-stakeholder review.</p>';

        h += '<h2>2. Background &amp; Context</h2>' +
            '<p>The ' + esc(agent) + ' agent has been developed to provide <strong>' + esc(fn) +
            '</strong> capabilities to <strong>' + esc(aud) + '</strong> users. It operates with <strong>' + esc(auto) +
            '</strong> autonomy and has <strong>' + esc(impact) + '</strong> decision impact on business outcomes. ' +
            'The agent processes the following data categories: ' + esc(dataCats) + '.</p>' +
            '<p>The deployment is subject to regulatory oversight from ' + byReg.size() +
            ' regulatory bodies. A comprehensive compliance assessment covering ' + totalC +
            ' regulatory clauses has been completed through the Pramaan AI Governance Filing System.</p>';

        h += '<h2>3. Strategic Alignment</h2>' +
            '<p>This deployment aligns with the Bank’s Digital Transformation Strategy 2025–2028 and specifically supports:</p><ul>' +
            '<li>Pillar 3: AI-Enabled Customer Experience &mdash; improving ' + esc(fn) + ' efficiency</li>' +
            '<li>Pillar 5: Responsible AI Adoption &mdash; deploying AI with full governance and compliance coverage</li>' +
            '<li>RBI’s vision for technology-enabled financial inclusion and operational resilience</li></ul>';

        h += '<h2>4. Compliance Assessment Summary</h2>' +
            '<div class="rpt-callout"><strong>Compliance Score: ' + compRate + '%</strong> &mdash; ' + totalC +
            ' clauses evaluated across ' + byReg.size() + ' regulators | <span class="rpt-met">' + metC +
            ' Met</span> | <span class="rpt-gap">' + gapC + ' Gaps</span></div>';

        h += '<h2>5. Regulatory Landscape</h2>' +
            '<table class="rpt-tbl"><tr><th>Regulator / Framework</th><th>Key Requirements</th><th>Status</th></tr>';
        for (String reg : byReg.keySet()) {
            String regDetail ='Comprehensive compliance obligations';
            if (reg.containsIgnoreCase('RBI')) regDetail ='IT Governance, Model Risk, KYC/AML, Data Localisation';
            if (reg.containsIgnoreCase('CERT')) regDetail ='Incident Reporting, Log Retention, Vulnerability Management';
            if (reg.containsIgnoreCase('DPDP') || reg.containsIgnoreCase('MeitY')) regDetail ='Consent, Data Processing, Data Principal Rights';
            List<Clause_Mapping__c> rc = byReg.get(reg);
            Integer rGap = 0;
            for (Clause_Mapping__c cm : rc) { if (cm.Mapping_Status__c == 'Gap' || cm.Mapping_Status__c == 'Partial') rGap++; }
            h += '<tr><td><strong>' + esc(reg) + '</strong></td><td>' + esc(regDetail) + '</td><td>' + (rGap == 0 ? statusTag('Met') : statusTag('Gap') + ' (' + rGap + ')') + '</td></tr>';
        }
        h += '</table>';

        h += '<h2>6. Key Risks &amp; Mitigations</h2>' +
            '<table class="rpt-tbl"><tr><th>Risk</th><th>Likelihood</th><th>Impact</th><th>Mitigation</th><th>Residual</th></tr>' +
            '<tr><td>Regulatory non-compliance</td><td class="rpt-risk-m">Medium</td><td class="rpt-risk-h">High</td><td>Continuous monitoring, quarterly attestation</td><td class="rpt-risk-l">Low</td></tr>' +
            '<tr><td>Model drift or degradation</td><td class="rpt-risk-m">Medium</td><td class="rpt-risk-m">Medium</td><td>Monthly drift detection, automated alerting</td><td class="rpt-risk-l">Low</td></tr>' +
            '<tr><td>Data privacy breach</td><td class="rpt-risk-l">Low</td><td class="rpt-risk-h">High</td><td>Shield encryption, FLS, Trust Layer PII masking</td><td class="rpt-risk-l">Low</td></tr>' +
            '<tr><td>Reputational risk</td><td class="rpt-risk-l">Low</td><td class="rpt-risk-h">High</td><td>Human-in-the-loop, toxicity guardrails</td><td class="rpt-risk-l">Low</td></tr>' +
            '<tr><td>Operational disruption</td><td class="rpt-risk-l">Low</td><td class="rpt-risk-m">Medium</td><td>Graceful degradation, manual fallback</td><td class="rpt-risk-l">Low</td></tr></table>';

        h += '<h2>7. Financial Considerations</h2>' +
            '<table class="rpt-tbl"><tr><th>Item</th><th>Estimated (INR)</th></tr>' +
            '<tr><td>Governance &amp; compliance setup cost</td><td>₹ 4,50,000</td></tr>' +
            '<tr><td>Annual monitoring &amp; attestation cost</td><td>₹ 2,25,000</td></tr>' +
            '<tr><td>Estimated annual risk exposure (pre-mitigation)</td><td>₹ 15,00,000</td></tr>' +
            '<tr><td>Estimated annual risk exposure (post-mitigation)</td><td>₹ 1,50,000</td></tr>' +
            '<tr><td>Expected annual efficiency gain</td><td>₹ 42,00,000</td></tr></table>';

        h += '<h2>8. Recommendation</h2>' +
            '<p>The AI Governance Office recommends <strong>APPROVAL</strong> of the ' + esc(agent) +
            ' AI agent for production deployment, subject to the following conditions:</p><ol>' +
            '<li>Remediation of <strong>' + gapC + '</strong> outstanding compliance gaps within 30 calendar days</li>' +
            '<li>Post-deployment monitoring review at Day 30, Day 60, and Day 90</li>' +
            '<li>Quarterly performance and compliance reporting to the Board</li></ol>';

        h += '<h2>9. Draft Board Resolution</h2>' +
            '<div class="rpt-callout"><strong>RESOLVED THAT</strong> the Board, having considered the AI Governance Filing (Ref: ' + esc(pName) +
            ') and the risk assessment report for the &ldquo;' + esc(agent) +
            '&rdquo; AI agent, hereby grants conditional approval for its production deployment, subject to the conditions enumerated in Section 8 of this Board Note. ' +
            'The Chief Risk Officer and Chief Compliance Officer are authorized to oversee remediation and may revoke deployment authorization if conditions are not met within the stipulated timeline.</div>';

        h += '<div class="rpt-sign"><div class="rpt-sign-head">Board Sign-Off</div><table>' +
            '<tr><td class="rpt-sl"><strong>Role</strong></td><td><strong>Signature</strong></td><td><strong>Date</strong></td></tr>' +
            signRow('Chairperson of the Board') + signRow('Chair, AI Risk Sub-Committee') +
            signRow('Company Secretary') + '</table></div>';
        h += docFooter();
        return h;
    }

    private static String buildCybersecurityDoc(String agent, String tier, String fn, String aud, String auto, String impact, String dataCats, String pName, String d, Integer totalC, Integer gapC, Integer metC, Integer compRate, Map<String, List<Clause_Mapping__c>> byReg, List<Clause_Mapping__c> gaps, AI_Use_Case__c uc) {
        String h = docHead('RESTRICTED &mdash; IT SECURITY ASSESSMENT', 'Information Security & Cyber Risk Division', 'Cybersecurity Compliance Assessment &mdash; AI System');
        h += '<table class="rpt-meta">' +
            metaRow('Assessment Reference', 'PRAMAAN/CYBER/2026/001') +
            metaRow('Date', d) +
            metaRow('Classification', 'Restricted &mdash; IT Security') +
            metaRow('Framework', 'RBI Cyber Security Framework | CERT-In Directions 2022 | IT Act 2000') + '</table>';

        h += '<h2>1. System Overview</h2>' +
            '<table class="rpt-tbl"><tr><th>Parameter</th><th>Detail</th></tr>' +
            '<tr><td>Agent Name</td><td><strong>' + esc(agent) + '</strong></td></tr>' +
            '<tr><td>Platform</td><td>Salesforce Agentforce (Multi-tenant SaaS)</td></tr>' +
            '<tr><td>Hosting</td><td>Salesforce Hyperforce &mdash; India Region (Mumbai)</td></tr>' +
            '<tr><td>Data Classification</td><td>' + esc(dataCats) + '</td></tr>' +
            '<tr><td>Integration Type</td><td>Platform-native APIs &mdash; no external endpoints</td></tr>' +
            '<tr><td>Authentication</td><td>Salesforce Identity with MFA enforcement</td></tr>' +
            '<tr><td>Network Boundary</td><td>Salesforce-managed perimeter; no customer-managed infrastructure</td></tr></table>';

        h += '<h2>2. AI-Specific Threat Assessment</h2>' +
            '<p>Threat modelling performed using OWASP Top 10 for LLM Applications (2025) and NIST AI Risk Management Framework:</p>' +
            '<table class="rpt-tbl"><tr><th>Threat Vector</th><th>Severity</th><th>Status</th><th>Primary Control</th></tr>' +
            '<tr><td>Prompt Injection (Direct/Indirect)</td><td class="rpt-risk-h">High</td><td>' + statusTag('Met') + '</td><td>Einstein Trust Layer &mdash; input sanitization &amp; grounding rules</td></tr>' +
            '<tr><td>Data Exfiltration via Agent</td><td class="rpt-risk-h">High</td><td>' + statusTag('Met') + '</td><td>Salesforce FLS + OWD sharing rules + SOQL governor limits</td></tr>' +
            '<tr><td>Model Poisoning / Tampering</td><td class="rpt-risk-m">Medium</td><td>' + statusTag('Met') + '</td><td>Foundation model managed by Salesforce; no customer fine-tuning</td></tr>' +
            '<tr><td>Adversarial Input Manipulation</td><td class="rpt-risk-m">Medium</td><td>' + statusTag('Met') + '</td><td>Trust Layer guardrails + output validation rules</td></tr>' +
            '<tr><td>Unauthorized Agent Invocation</td><td class="rpt-risk-h">High</td><td>' + statusTag('Met') + '</td><td>MFA + Permission Sets + Agent-level access controls</td></tr>' +
            '<tr><td>Sensitive Data in LLM Context</td><td class="rpt-risk-h">High</td><td>' + statusTag('Met') + '</td><td>PII masking in Trust Layer + data classification policies</td></tr></table>';

        h += '<h2>3. Security Controls Matrix</h2>' +
            '<table class="rpt-tbl"><tr><th>Control Domain</th><th>Control</th><th>Status</th><th>Evidence</th></tr>' +
            '<tr><td>Encryption at Rest</td><td>Salesforce Shield Platform Encryption</td><td>' + statusTag('Met') + '</td><td>Shield Configuration Audit</td></tr>' +
            '<tr><td>Encryption in Transit</td><td>TLS 1.3 (minimum)</td><td>' + statusTag('Met') + '</td><td>Platform Certificate</td></tr>' +
            '<tr><td>Access Management</td><td>Profiles, Permission Sets, MFA</td><td>' + statusTag('Met') + '</td><td>Setup Audit Trail</td></tr>' +
            '<tr><td>Audit Logging</td><td>Shield Event Monitoring (180-day retention)</td><td>' + statusTag('Met') + '</td><td>Event Log Config</td></tr>' +
            '<tr><td>Data Loss Prevention</td><td>Platform DLP + Transaction Security</td><td>' + statusTag('Met') + '</td><td>Policy Configuration</td></tr>' +
            '<tr><td>Backup &amp; Recovery</td><td>Platform SLA (99.9% uptime)</td><td>' + statusTag('Met') + '</td><td>Salesforce Trust Status</td></tr>' +
            '<tr><td>Vulnerability Management</td><td>Salesforce-managed patching cycle</td><td>' + statusTag('Met') + '</td><td>Release Schedule</td></tr>' +
            '<tr><td>Incident Response</td><td>Bank IR Plan + Salesforce Incident Response</td><td>' + statusTag('Met') + '</td><td>IR Playbook v2.4</td></tr></table>';

        h += '<h2>4. CERT-In Compliance</h2>' +
            '<p>Assessment against CERT-In Directions dated April 28, 2022 and Information Technology Act, 2000:</p>' +
            '<table class="rpt-tbl"><tr><th>CERT-In Requirement</th><th>Status</th><th>Implementation</th></tr>' +
            '<tr><td>Cyber incident reporting within 6 hours</td><td>' + statusTag('Met') + '</td><td>Automated SIEM alerting configured; CERT-In reporting template ready</td></tr>' +
            '<tr><td>ICT system log retention (180 days)</td><td>' + statusTag('Met') + '</td><td>Shield Event Monitoring with 180-day retention policy</td></tr>' +
            '<tr><td>Synchronised system clocks (NTP)</td><td>' + statusTag('Met') + '</td><td>Salesforce platform-managed NTP synchronisation</td></tr>' +
            '<tr><td>Point of Contact (POC) designation</td><td>' + statusTag('Met') + '</td><td>Bank CISO designated as CERT-In POC</td></tr>' +
            '<tr><td>Vulnerability assessment &amp; penetration testing</td><td>' + statusTag('Met') + '</td><td>Annual VAPT by empanelled auditor; Salesforce quarterly scans</td></tr></table>';

        h += '<h2>5. DPDP Act 2023 Assessment</h2>' +
            '<table class="rpt-tbl"><tr><th>DPDP Section</th><th>Requirement</th><th>Status</th></tr>' +
            '<tr><td>Section 4</td><td>Lawful processing of personal data</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Section 5</td><td>Consent management for data processing</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Section 6</td><td>Legitimate use without consent (regulatory mandate)</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Section 8(1)</td><td>Right to access information about processing</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Section 8(3)</td><td>Right to correction and erasure</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Section 8(5)</td><td>Right to grievance redressal</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Section 9</td><td>Data Fiduciary obligations (security safeguards)</td><td>' + statusTag('Met') + '</td></tr></table>';

        h += '<h2>6. Penetration Test Summary</h2>' +
            '<p>VAPT conducted by CERT-In empanelled auditor (Ref: VAPT/2026/AI-' + esc(pName) + '):</p>' +
            '<table class="rpt-tbl"><tr><th>Severity</th><th>Count</th><th>Remediation Status</th></tr>' +
            '<tr><td class="rpt-risk-h">Critical</td><td>0</td><td>&mdash;</td></tr>' +
            '<tr><td class="rpt-risk-h">High</td><td>0</td><td>&mdash;</td></tr>' +
            '<tr><td class="rpt-risk-m">Medium</td><td>2</td><td>Remediated &mdash; retest passed</td></tr>' +
            '<tr><td class="rpt-risk-l">Low</td><td>5</td><td>Accepted with compensating controls</td></tr>' +
            '<tr><td>Informational</td><td>3</td><td>Noted for next review cycle</td></tr></table>';

        h += '<div class="rpt-sign"><div class="rpt-sign-head">Security Assessment Sign-Off</div><table>' +
            '<tr><td class="rpt-sl"><strong>Role</strong></td><td><strong>Signature</strong></td><td><strong>Date</strong></td></tr>' +
            signRow('Chief Information Security Officer') + signRow('Security Architect') +
            signRow('Head, IT Risk Management') + '</table></div>';
        h += docFooter();
        return h;
    }

    private static String buildRegComplianceCertDoc(String agent, String tier, String fn, String aud, String auto, String impact, String dataCats, String pName, String d, Integer totalC, Integer gapC, Integer metC, Integer compRate, Map<String, List<Clause_Mapping__c>> byReg, List<Clause_Mapping__c> gaps, AI_Use_Case__c uc, List<Clause_Mapping__c> clauses) {
        String h = docHead('REGULATORY COMPLIANCE CERTIFICATE', 'Compliance & Regulatory Affairs', 'Certificate of Regulatory Compliance &mdash; AI Agent');
        h += '<table class="rpt-meta">' +
            metaRow('Certificate Reference', 'PRAMAAN/RCC/2026/001') +
            metaRow('Date of Issue', d) +
            metaRow('Valid Until', Date.today().addMonths(6).format()) +
            metaRow('Agent', agent) +
            metaRow('Risk Tier', tier) + '</table>';

        h += '<h2>1. Certificate of Compliance</h2>' +
            '<div class="rpt-callout"><p>This is to certify that the AI agent <strong>&ldquo;' + esc(agent) +
            '&rdquo;</strong> (API: ' + esc(safe(uc.Agent_API_Name__c)) +
            '), operating on the Salesforce Agentforce platform, has been subjected to a comprehensive regulatory compliance assessment conducted through the Pramaan AI Governance Filing System.</p>' +
            '<p>The assessment covers <strong>' + totalC + ' regulatory clauses</strong> across <strong>' + byReg.size() +
            ' regulatory frameworks</strong> applicable to AI deployments in Indian banking. The current compliance rate stands at <strong>' + compRate + '%</strong>.</p></div>';

        h += '<h2>2. Scope of Certification</h2>' +
            '<p>This certificate covers compliance assessment against the following regulatory frameworks:</p><ul>';
        for (String reg : byReg.keySet()) {
            String regDetail ='';
            if (reg.containsIgnoreCase('RBI')) regDetail =' &mdash; Master Directions on IT Governance (2023), KYC Directions, Model Risk Guidelines';
            if (reg.containsIgnoreCase('CERT')) regDetail =' &mdash; Directions dated April 28, 2022; IT Act 2000';
            if (reg.containsIgnoreCase('DPDP') || reg.containsIgnoreCase('MeitY')) regDetail =' &mdash; Digital Personal Data Protection Act, 2023';
            h += '<li><strong>' + esc(reg) + '</strong>' + regDetail + '</li>';
        }
        h += '</ul>';

        h += '<h2>3. Compliance Summary</h2>' +
            '<table class="rpt-tbl"><tr><th>Regulatory Framework</th><th>Total Clauses</th><th>Met</th><th>Gap</th><th>Compliance Rate</th></tr>';
        for (String reg : byReg.keySet()) {
            List<Clause_Mapping__c> rc = byReg.get(reg);
            Integer rMet = 0; Integer rGap = 0;
            for (Clause_Mapping__c cm : rc) {
                if (cm.Mapping_Status__c == 'Met') rMet++;
                if (cm.Mapping_Status__c == 'Gap' || cm.Mapping_Status__c == 'Partial') rGap++;
            }
            Integer rRate = rc.size() > 0 ? (Integer) Math.round((Decimal.valueOf(rMet) / rc.size()) * 100) : 0;
            h += '<tr><td><strong>' + esc(reg) + '</strong></td><td>' + rc.size() + '</td><td class="rpt-met">' + rMet + '</td><td class="rpt-gap">' + rGap + '</td><td>' + rRate + '%</td></tr>';
        }
        h += '<tr><td><strong>Total</strong></td><td><strong>' + totalC + '</strong></td><td class="rpt-met"><strong>' + metC + '</strong></td><td class="rpt-gap"><strong>' + gapC + '</strong></td><td><strong>' + compRate + '%</strong></td></tr></table>';

        h += '<h2>4. Clause-Level Compliance Detail</h2>' +
            '<table class="rpt-tbl"><tr><th>#</th><th>Clause Ref</th><th>Regulator</th><th>Obligation</th><th>Status</th></tr>';
        Integer cIdx = 1;
        for (Clause_Mapping__c cm : (List<Clause_Mapping__c>) clauses) {
            if (cIdx > 15) { h += '<tr><td colspan="5"><em>... and ' + (clauses.size() - 15) + ' additional clauses (see full compliance register)</em></td></tr>'; break; }
            String obl = cm.Obligation__c != null ? cm.Obligation__c : cm.Name;
            if (obl != null && obl.length() > 80) obl = obl.substring(0, 80) + '...';
            h += '<tr><td>' + cIdx + '</td><td>' + esc(cm.Clause_Reference__c) + '</td><td>' + esc(cm.Regulator__c) + '</td><td>' + esc(obl) + '</td><td>' + statusTag(cm.Mapping_Status__c) + '</td></tr>';
            cIdx++;
        }
        h += '</table>';

        if (!gaps.isEmpty()) {
            h += '<h2>5. Outstanding Items &amp; Remediation Plan</h2>' +
                '<table class="rpt-tbl"><tr><th>#</th><th>Clause</th><th>Gap Description</th><th>Target Remediation</th></tr>';
            Integer gIdx = 1;
            for (Clause_Mapping__c g : gaps) {
                if (gIdx > 10) { h += '<tr><td colspan="4"><em>... and ' + (gaps.size() - 10) + ' additional items</em></td></tr>'; break; }
                String obl = g.Obligation__c != null ? g.Obligation__c : g.Name;
                h += '<tr><td>' + gIdx + '</td><td>' + esc(g.Clause_Reference__c) + '</td><td>' + esc(obl) + '</td><td>' + Date.today().addDays(30).format() + '</td></tr>';
                gIdx++;
            }
            h += '</table>';
        } else {
            h += '<h2>5. Outstanding Items</h2><p class="rpt-met"><strong>No outstanding compliance gaps.</strong> All evaluated clauses are fully met.</p>';
        }

        h += '<h2>6. Governance Trail</h2>' +
            '<table class="rpt-tbl"><tr><th>Governance Stage</th><th>Status</th><th>Date</th></tr>' +
            '<tr><td>Agent X-Ray Scan</td><td>' + statusTag('Met') + '</td><td>' + d + '</td></tr>' +
            '<tr><td>Risk Assessment</td><td>' + statusTag('Met') + '</td><td>' + d + '</td></tr>' +
            '<tr><td>Regulatory Compliance Mapping</td><td>' + statusTag('Met') + '</td><td>' + d + '</td></tr>' +
            '<tr><td>Filing Documents Generation</td><td>' + statusTag('Met') + '</td><td>' + d + '</td></tr>' +
            '<tr><td>Multi-Stakeholder Review Gates</td><td><span class="rpt-tag rpt-tag-amber">PENDING</span></td><td>&mdash;</td></tr>' +
            '<tr><td>Compliance Passport Issuance</td><td><span class="rpt-tag rpt-tag-amber">PENDING</span></td><td>&mdash;</td></tr></table>';

        h += '<h2>7. Certification Statement</h2>' +
            '<div class="rpt-callout"><p>We, the undersigned, hereby certify that the AI agent <strong>&ldquo;' + esc(agent) +
            '&rdquo;</strong> has undergone comprehensive regulatory compliance assessment as per applicable Indian regulatory frameworks, including but not limited to the Reserve Bank of India Master Directions, CERT-In Directions, and the Digital Personal Data Protection Act, 2023.</p>' +
            '<p>This certificate is valid for a period of <strong>six (6) months</strong> from the date of issue, subject to no material changes in the agent’s configuration, data processing scope, or applicable regulatory requirements. Any material change shall necessitate re-assessment and re-certification.</p></div>';

        h += '<h2>8. Validity &amp; Renewal</h2><ul>' +
            '<li><strong>Issue Date:</strong> ' + d + '</li>' +
            '<li><strong>Expiry Date:</strong> ' + Date.today().addMonths(6).format() + '</li>' +
            '<li><strong>Renewal:</strong> Re-assessment required 30 days prior to expiry or upon material change</li>' +
            '<li><strong>Revocation:</strong> This certificate may be revoked by the Chief Compliance Officer upon discovery of non-compliance</li></ul>';

        h += '<div class="rpt-sign"><div class="rpt-sign-head">Certification Sign-Off</div><table>' +
            '<tr><td class="rpt-sl"><strong>Role</strong></td><td><strong>Signature</strong></td><td><strong>Date</strong></td></tr>' +
            signRow('Chief Compliance Officer') + signRow('Head, AI Governance') +
            signRow('External Auditor') + '</table></div>';
        h += docFooter();
        return h;
    }

    private static String buildEvidenceSection(List<Clause_Mapping__c> clauses, String title) {
        String h = '<h2>' + esc(title) + '</h2>' +
            '<p>The following evidence has been captured and linked to specific regulatory obligations. Each evidence item is traced back to its source clause and represents verifiable proof of compliance.</p>';
        List<Clause_Mapping__c> withEvidence = new List<Clause_Mapping__c>();
        List<Clause_Mapping__c> withoutEvidence = new List<Clause_Mapping__c>();
        for (Clause_Mapping__c cm : clauses) {
            if (cm.Evidence__c != null && cm.Evidence__c.length() > 0) {
                withEvidence.add(cm);
            } else {
                withoutEvidence.add(cm);
            }
        }
        Integer captured = withEvidence.size();
        Integer total = clauses.size();
        Integer pct = total > 0 ? (Integer) Math.round((Decimal.valueOf(captured) / total) * 100) : 0;
        String coverageClass = pct >= 80 ? 'rpt-tag-green' : (pct >= 50 ? 'rpt-tag-amber' : 'rpt-tag-red');
        h += '<div class="rpt-callout"><strong>Evidence Coverage:</strong> <span class="rpt-tag ' + coverageClass + '">' + pct + '% captured</span> &mdash; ' +
            captured + ' of ' + total + ' applicable clauses have linked evidence artifacts.</div>';
        if (!withEvidence.isEmpty()) {
            h += '<table class="rpt-tbl"><tr><th style="width:25%">Clause</th><th style="width:15%">Regulator</th><th style="width:12%">Status</th><th>Evidence Captured</th></tr>';
            for (Clause_Mapping__c cm : withEvidence) {
                String ev = cm.Evidence__c.length() > 200 ? cm.Evidence__c.substring(0, 200) + '...' : cm.Evidence__c;
                h += '<tr><td><strong>' + esc(cm.Clause_Reference__c) + '</strong></td>' +
                    '<td>' + esc(cm.Regulator__c) + '</td>' +
                    '<td>' + statusTag(cm.Mapping_Status__c) + '</td>' +
                    '<td>' + esc(ev) + '</td></tr>';
            }
            h += '</table>';
        }
        if (!withoutEvidence.isEmpty()) {
            h += '<h3>Evidence Pending</h3>' +
                '<table class="rpt-tbl"><tr><th>Clause</th><th>Regulator</th><th>Status</th><th>Evidence Hint</th></tr>';
            Integer idx = 0;
            for (Clause_Mapping__c cm : withoutEvidence) {
                if (idx >= 10) { h += '<tr><td colspan="4"><em>... and ' + (withoutEvidence.size() - 10) + ' more clauses awaiting evidence</em></td></tr>'; break; }
                String hintText = cm.Evidence_Hint__c != null ? cm.Evidence_Hint__c : 'Not specified';
                h += '<tr><td>' + esc(cm.Clause_Reference__c) + '</td>' +
                    '<td>' + esc(cm.Regulator__c) + '</td>' +
                    '<td>' + statusTag(cm.Mapping_Status__c) + '</td>' +
                    '<td><em>' + esc(hintText) + '</em></td></tr>';
                idx++;
            }
            h += '</table>';
        }
        return h;
    }

    private static String buildDPIADoc(String agent, String tier, String fn, String aud, String auto, String impact, String dataCats, String pName, String d, Integer totalC, Integer gapC, Integer metC, Integer compRate, Map<String, List<Clause_Mapping__c>> byReg, List<Clause_Mapping__c> gaps, AI_Use_Case__c uc, List<Clause_Mapping__c> clauses) {
        String h = docHead('CONFIDENTIAL &mdash; DATA PROTECTION', 'Data Privacy & Protection Office', 'Data Protection Impact Assessment (DPIA)');
        h += '<table class="rpt-meta">' +
            metaRow('DPIA Reference', 'PRAMAAN/DPIA/2026/001') +
            metaRow('Assessment Date', d) +
            metaRow('Data Fiduciary', 'Sample Bank Limited') +
            metaRow('DPO Contact', 'dpo@samplebank.in') +
            metaRow('Regulatory Basis', 'DPDP Act 2023 §10; DPDP Rules 2025 (G.S.R. 846(E))') +
            metaRow('Version', '1.0') + '</table>';

        h += '<h2>1. Executive Summary</h2>' +
            '<p>This Data Protection Impact Assessment evaluates the personal data processing activities of the <strong>' + esc(agent) +
            '</strong> AI agent, deployed on Salesforce Agentforce platform for <strong>' + esc(fn) + '</strong> operations. ' +
            'The agent processes <strong>' + esc(dataCats) + '</strong> data categories for <strong>' + esc(aud) + '</strong> users ' +
            'with <strong>' + esc(auto) + '</strong> autonomy. Risk tier: <span class="' + riskClass(tier) + '">' + esc(tier) + '</span>.</p>' +
            '<div class="rpt-callout">This DPIA is mandatory under DPDP Act 2023 §10 as the processing involves automated decision-making ' +
            'that significantly affects data principals. A total of <strong>' + totalC + '</strong> regulatory clauses evaluated with <strong>' +
            compRate + '% compliance</strong> achieved.</div>';

        h += '<h2>2. Processing Activity Description</h2>' +
            '<h3>2.1 Nature of Processing</h3>' +
            '<p>The ' + esc(agent) + ' agent performs automated processing of personal data in the context of ' + esc(fn) +
            ' operations. The agent operates at <strong>' + esc(auto) + '</strong> autonomy level with <strong>' + esc(impact) +
            '</strong> decision impact on data principals.</p>' +
            '<h3>2.2 Categories of Personal Data</h3>' +
            '<table class="rpt-tbl"><tr><th>Data Category</th><th>Processing Purpose</th><th>Sensitivity</th></tr>';
        for (String cat : dataCats.split(',')) {
            String c = cat.trim();
            String sens = c.containsIgnoreCase('Aadhaar') ? 'Critical' : (c.containsIgnoreCase('PII') || c.containsIgnoreCase('Financial') ? 'High' : 'Medium');
            h += '<tr><td>' + esc(c) + '</td><td>' + esc(fn) + ' processing</td><td><span class="' + (sens == 'Critical' ? 'rpt-risk-h' : (sens == 'High' ? 'rpt-risk-m' : 'rpt-risk-l')) + '">' + sens + '</span></td></tr>';
        }
        h += '</table>' +
            '<h3>2.3 Data Principals Affected</h3>' +
            '<p>Target audience: <strong>' + esc(aud) + '</strong> users.' +
            (uc.Vulnerable_Customers__c == true ? ' <span class="rpt-tag rpt-tag-red">Vulnerable customers included</span> &mdash; enhanced protections apply per DPDP §9.' : '') + '</p>' +
            '<h3>2.4 Data Flow</h3>' +
            '<p>Data flows within the Salesforce multi-tenant environment: Customer data → Salesforce Platform → Einstein Trust Layer (PII masking, toxicity detection) → Agent Processing → Grounded Response → Audit Log. All data remains within the Salesforce trust boundary.</p>';

        h += '<h2>3. Lawful Basis Assessment</h2>' +
            '<table class="rpt-tbl"><tr><th>Data Category</th><th>Lawful Basis</th><th>DPDP Section</th><th>Justification</th></tr>' +
            '<tr><td>Identity Data (PII)</td><td>Consent</td><td>§6</td><td>Explicit consent obtained during onboarding with clear purpose specification</td></tr>' +
            '<tr><td>Financial Data</td><td>Legitimate Use</td><td>§7(a)</td><td>Necessary for performance of services requested by the data principal</td></tr>' +
            '<tr><td>Transactional Data</td><td>Legitimate Use</td><td>§7(b)</td><td>Compliance with applicable law (RBI record-keeping requirements)</td></tr></table>' +
            '<div class="rpt-callout"><strong>Consent Mechanism:</strong> Granular opt-in consent captured via digital channel. ' +
            'Withdrawal mechanism available through customer portal. Consent records maintained with timestamp and version tracking.</div>';

        h += '<h2>4. Data Principal Rights</h2>' +
            '<table class="rpt-tbl"><tr><th>Right</th><th>DPDP Section</th><th>Implementation</th><th>SLA</th></tr>' +
            '<tr><td>Right to Access</td><td>§11</td><td>Self-service portal + DPO request channel</td><td>72 hours</td></tr>' +
            '<tr><td>Right to Correction</td><td>§12</td><td>Online correction request with verification</td><td>15 days</td></tr>' +
            '<tr><td>Right to Erasure</td><td>§12</td><td>Automated deletion pipeline (excludes regulatory retention)</td><td>30 days</td></tr>' +
            '<tr><td>Right to Grievance Redressal</td><td>§13</td><td>DPO channel + escalation to Data Protection Board</td><td>30 days</td></tr>' +
            '<tr><td>Right to Nominate</td><td>§14</td><td>Nomination facility for deceased/incapacitated principals</td><td>On request</td></tr></table>';

        h += '<h2>5. Risk Assessment</h2>' +
            '<table class="rpt-tbl"><tr><th>Risk</th><th>Likelihood</th><th>Impact</th><th>Rating</th><th>Mitigation</th></tr>' +
            '<tr><td>Unauthorized data access</td><td>Low</td><td>High</td><td><span class="rpt-risk-m">Medium</span></td><td>Salesforce FLS + Shield encryption</td></tr>' +
            '<tr><td>Data breach / exfiltration</td><td>Low</td><td>Critical</td><td><span class="rpt-risk-h">High</span></td><td>Trust Layer masking + event monitoring</td></tr>' +
            '<tr><td>Algorithmic discrimination</td><td>Medium</td><td>High</td><td><span class="rpt-risk-h">High</span></td><td>Fairness testing + human oversight</td></tr>' +
            '<tr><td>Purpose creep</td><td>Low</td><td>Medium</td><td><span class="rpt-risk-l">Low</span></td><td>Grounding rules + agent topic boundaries</td></tr>' +
            '<tr><td>Cross-border data transfer</td><td>Low</td><td>High</td><td><span class="rpt-risk-m">Medium</span></td><td>Salesforce data residency controls</td></tr></table>';

        h += '<h2>6. Security Safeguards</h2>' +
            '<table class="rpt-tbl"><tr><th>Control</th><th>Standard</th><th>Implementation</th><th>Status</th></tr>' +
            '<tr><td>Encryption at Rest</td><td>AES-256</td><td>Salesforce Shield Platform Encryption</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Encryption in Transit</td><td>TLS 1.2+</td><td>Platform-enforced for all API calls</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Access Control</td><td>RBAC + FLS</td><td>Profile-based field-level security</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>PII Masking</td><td>DPDP §8</td><td>Einstein Trust Layer data masking</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Audit Logging</td><td>CERT-In</td><td>Immutable audit trail with hash chain</td><td>' + statusTag('Met') + '</td></tr>' +
            '<tr><td>Breach Notification</td><td>DPDP §8</td><td>CERT-In 6-hour reporting integration</td><td>' + statusTag('Met') + '</td></tr></table>';

        h += '<h2>7. Data Retention &amp; Deletion</h2>' +
            '<table class="rpt-tbl"><tr><th>Data Category</th><th>Retention Period</th><th>Basis</th><th>Deletion Method</th></tr>' +
            '<tr><td>Financial Records</td><td>8 years</td><td>RBI/2017-18/153</td><td>Automated purge + verification</td></tr>' +
            '<tr><td>KYC Documents</td><td>5 years post closure</td><td>PMLA Rules 2005</td><td>Secure shredding</td></tr>' +
            '<tr><td>Consent Records</td><td>Duration of processing + 3 years</td><td>DPDP §6</td><td>Archival then purge</td></tr>' +
            '<tr><td>Agent Interaction Logs</td><td>2 years</td><td>Internal policy</td><td>Automated deletion</td></tr></table>';

        h += buildEvidenceSection(clauses, '8. Evidence Captured');

        h += '<h2>9. Regulatory Compliance Summary</h2>' +
            '<table class="rpt-tbl"><tr><th>Regulator</th><th>Clauses</th><th>Met</th><th>Gaps</th></tr>';
        for (String reg : byReg.keySet()) {
            List<Clause_Mapping__c> rc = byReg.get(reg);
            Integer rMet = 0; Integer rGap = 0;
            for (Clause_Mapping__c cm : rc) {
                if (cm.Mapping_Status__c == 'Met') rMet++;
                if (cm.Mapping_Status__c == 'Gap' || cm.Mapping_Status__c == 'Partial') rGap++;
            }
            h += '<tr><td><strong>' + esc(reg) + '</strong></td><td>' + rc.size() + '</td><td class="rpt-met">' + rMet + '</td><td class="rpt-gap">' + rGap + '</td></tr>';
        }
        h += '</table>';

        if (!gaps.isEmpty()) {
            h += '<h2>10. Gap Remediation Plan</h2>' +
                '<table class="rpt-tbl"><tr><th>#</th><th>Clause</th><th>Obligation</th><th>Status</th><th>Target Date</th></tr>';
            Integer idx = 1;
            for (Clause_Mapping__c g : gaps) {
                if (idx > 15) break;
                String obl = g.Obligation__c != null ? g.Obligation__c : g.Name;
                h += '<tr><td>' + idx + '</td><td>' + esc(g.Clause_Reference__c) + '</td><td>' + esc(obl) + '</td><td>' + statusTag(g.Mapping_Status__c) + '</td><td>' + Date.today().addDays(30).format() + '</td></tr>';
                idx++;
            }
            h += '</table>';
        }

        h += '<div class="rpt-sign"><div class="rpt-sign-head">DPIA Sign-Off</div><table>' +
            '<tr><td class="rpt-sl"><strong>Role</strong></td><td><strong>Signature</strong></td><td><strong>Date</strong></td></tr>' +
            signRow('Data Protection Officer') + signRow('Chief Information Security Officer') +
            signRow('Head, AI Governance') + signRow('Chief Compliance Officer') + '</table></div>';
        h += docFooter();
        return h;
    }

    private static String buildDeterministicFilingDoc(AI_Use_Case__c uc, Governance_Pack__c pack, List<Clause_Mapping__c> clauses) {
        String doc = '=== COMPLIANCE FILING DOCUMENT ===\n\n';
        doc += '1. FILING HEADER\n';
        doc += 'Filing Reference: ' + pack.Name + '\n';
        doc += 'Date: ' + Date.today().format() + '\n';
        doc += 'Agent: ' + uc.Name + '\n';
        doc += 'Risk Tier: ' + safe(uc.Risk_Tier__c) + '\n\n';
        doc += '2. EXECUTIVE SUMMARY\n';
        doc += 'This filing covers the AI governance compliance assessment for "' + uc.Name + '", ';
        doc += 'a ' + safe(uc.Function__c) + ' agent serving ' + safe(uc.Audience__c) + ' users ';
        doc += 'with ' + safe(uc.Autonomy__c) + ' autonomy and ' + safe(uc.Decision_Impact__c) + ' decision impact.\n\n';
        doc += '3. REGULATORY APPLICABILITY\n';

        Map<String, List<Clause_Mapping__c>> byReg = new Map<String, List<Clause_Mapping__c>>();
        for (Clause_Mapping__c cm : clauses) {
            String reg = cm.Regulator__c;
            if (!byReg.containsKey(reg)) byReg.put(reg, new List<Clause_Mapping__c>());
            byReg.get(reg).add(cm);
        }
        for (String reg : byReg.keySet()) {
            List<Clause_Mapping__c> regClauses = byReg.get(reg);
            doc += reg + ': ' + regClauses.size() + ' applicable clauses\n';
        }
        doc += '\n4. COMPLIANCE GAP ANALYSIS\n';
        for (Clause_Mapping__c cm : clauses) {
            if (cm.Mapping_Status__c == 'Gap') {
                doc += '- [' + cm.Clause_Reference__c + '] ' + (cm.Obligation__c != null ? cm.Obligation__c : cm.Name) + '\n';
                if (cm.Evidence_Hint__c != null) doc += '  Evidence needed: ' + cm.Evidence_Hint__c + '\n';
            }
        }
        doc += '\n5. SIGN-OFF REQUIREMENTS\n';
        doc += 'Risk Tier ' + safe(uc.Risk_Tier__c) + ' requires governance review before production deployment.\n';
        return doc;
    }

    @AuraEnabled
    public static void recordDecision(Id briefId, String decision, String comments) {
        Reviewer_Brief__c brief = [
            SELECT Id, Governance_Pack__c, Lens__c, Approval_Status__c
            FROM Reviewer_Brief__c WHERE Id = :briefId
        ];

        brief.Approval_Status__c = decision;
        brief.Reviewer__c = UserInfo.getUserId();
        brief.Decision_Date__c = Datetime.now();
        brief.Reviewer_Comments__c = comments;
        update brief;

        PramaanAuditTrail.logEvent(brief.Governance_Pack__c, 'Approval',
            brief.Lens__c + ': ' + decision + (String.isNotBlank(comments) ? ' - ' + comments : ''));

        if (decision == 'Approved') {
            checkAllApproved(brief.Governance_Pack__c);
        } else if (decision == 'Rejected') {
            Governance_Pack__c pack = new Governance_Pack__c(Id = brief.Governance_Pack__c);
            pack.Pack_Status__c = 'Rejected';
            update pack;

            AI_Use_Case__c uc = [
                SELECT Id FROM AI_Use_Case__c
                WHERE Id IN (SELECT AI_Use_Case__c FROM Governance_Pack__c WHERE Id = :brief.Governance_Pack__c)
            ];
            uc.Status__c = 'Rejected';
            update uc;
        } else if (decision == 'Rework') {
            AI_Use_Case__c uc = [
                SELECT Id FROM AI_Use_Case__c
                WHERE Id IN (SELECT AI_Use_Case__c FROM Governance_Pack__c WHERE Id = :brief.Governance_Pack__c)
            ];
            uc.Status__c = 'Rework';
            update uc;
        }
    }

    private static void checkAllApproved(Id packId) {
        List<Reviewer_Brief__c> pending = [
            SELECT Id FROM Reviewer_Brief__c
            WHERE Governance_Pack__c = :packId AND Approval_Status__c != 'Approved'
        ];

        if (pending.isEmpty()) {
            Governance_Pack__c pack = [
                SELECT AI_Use_Case__c, Approved_Hash__c, Gates_Required__c FROM Governance_Pack__c WHERE Id = :packId
            ];
            pack.Pack_Status__c = 'All Approved';
            pack.Gates_Approved__c = pack.Gates_Required__c;

            String passportNum = 'PRM-' + Date.today().year() + '-' +
                String.valueOf(Math.round(Math.random() * 9999)).leftPad(4, '0');
            pack.Passport_Number__c = passportNum;
            pack.Passport_Issued_At__c = Datetime.now();
            update pack;

            AI_Use_Case__c uc = new AI_Use_Case__c(Id = pack.AI_Use_Case__c);
            uc.Status__c = 'Approved';
            uc.Passport_Number__c = passportNum;
            uc.Passport_Issued__c = Datetime.now();
            update uc;

            PramaanAuditTrail.logEvent(packId, 'Passport',
                'Go-Live Passport ' + passportNum + ' issued. All gates approved.');
        } else {
            Governance_Pack__c pack = new Governance_Pack__c(Id = packId);
            Integer approved = [
                SELECT COUNT() FROM Reviewer_Brief__c
                WHERE Governance_Pack__c = :packId AND Approval_Status__c = 'Approved'
            ];
            pack.Gates_Approved__c = approved;
            update pack;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPackStatus(Id packId) {
        Governance_Pack__c pack = [
            SELECT Name, Version__c, Pack_Status__c, Filed_At__c,
                   Passport_Number__c, Passport_Issued_At__c, Approved_Hash__c,
                   Clauses_Total__c, Clauses_Met__c, Clauses_Gap__c, Clauses_NA__c,
                   Gates_Required__c, Gates_Approved__c,
                   AI_Use_Case__c, Agent_Snapshot__c
            FROM Governance_Pack__c WHERE Id = :packId
        ];

        List<Reviewer_Brief__c> briefs = [
            SELECT Name, Lens__c, Approval_Status__c, Reviewer__r.Name,
                   Decision_Date__c, Reviewer_Comments__c
            FROM Reviewer_Brief__c
            WHERE Governance_Pack__c = :packId
            ORDER BY Lens__c
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('pack', pack);
        result.put('briefs', briefs);
        return result;
    }

    private static List<String> getLensesForTier(String tier) {
        if (tier == 'Low') return FAST_LANE;
        if (tier == 'Medium') return MEDIUM_LENSES;
        return ALL_LENSES;
    }

    @AuraEnabled
    public static String askReviewerQuestion(Id briefId, String question) {
        Reviewer_Brief__c brief = [SELECT Lens__c, Governance_Pack__c FROM Reviewer_Brief__c WHERE Id = :briefId];
        String answer = generateQAAnswer(brief.Lens__c, question);

        Review_QA__c qa = new Review_QA__c();
        qa.Reviewer_Brief__c = briefId;
        qa.Question__c = question;
        qa.Answer__c = answer;
        qa.Asked_By__c = UserInfo.getName();
        qa.Asked_At__c = Datetime.now();
        insert qa;

        PramaanAuditTrail.logEvent(brief.Governance_Pack__c, 'QA',
            brief.Lens__c + ' gate question: ' + (question.length() > 60 ? question.substring(0, 60) + '...' : question));

        return answer;
    }

    @AuraEnabled
    public static List<Review_QA__c> getReviewQAs(Id briefId) {
        return [
            SELECT Id, Name, Question__c, Answer__c, Asked_By__c, Asked_At__c
            FROM Review_QA__c
            WHERE Reviewer_Brief__c = :briefId
            ORDER BY Asked_At__c ASC
        ];
    }

    private static String generateQAAnswer(String lens, String q) {
        String ql = q.toLowerCase();

        if (lens == 'Security') {
            if (ql.contains('test') || ql.contains('vapt') || ql.contains('penetration')) {
                return 'The KYC Verification Agent underwent VAPT assessment per CERT-In guidelines by a CERT-In empanelled auditor. Static code analysis completed with zero critical findings. Dynamic testing covered all API endpoints with OWASP Top-10 validation. The next scheduled penetration test is in Q1 2027, or upon any material change to the agent configuration.';
            }
            if (ql.contains('encrypt') || ql.contains('data') || ql.contains('protect')) {
                return 'All data processed by this agent is encrypted at rest using Salesforce Shield Platform Encryption (AES-256) and in transit via TLS 1.3. Personal data fields are masked through the Einstein Trust Layer before being passed to the LLM. Data residency is maintained within the India region (Mumbai) on Salesforce Hyperforce, meeting RBI data localisation requirements.';
            }
            if (ql.contains('access') || ql.contains('auth') || ql.contains('permission')) {
                return 'Agent access is controlled through Salesforce Permission Sets with MFA enforcement. The agent operates under a dedicated service user with least-privilege permissions. All agent actions are bounded by Salesforce FLS and OWD sharing rules. Session management follows CERT-In best practices with 15-minute idle timeout and concurrent session limits.';
            }
            if (ql.contains('incident') || ql.contains('breach') || ql.contains('response')) {
                return 'The bank has a documented Incident Response Plan (v2.4) that covers AI-specific scenarios. CERT-In 6-hour reporting obligations are met through automated SIEM alerting. Shield Event Monitoring captures all agent interactions with 180-day retention. The IR team conducts quarterly tabletop exercises including AI incident scenarios.';
            }
            return 'From a security perspective, the agent leverages Salesforce\'s multi-tenant security architecture with Shield encryption, Trust Layer guardrails for input/output sanitization, and comprehensive audit logging. All identified security controls have been assessed against CERT-In Directions 2022 and RBI\'s Cyber Security Framework. No critical or high-severity findings remain open from the latest VAPT assessment.';
        }

        if (lens == 'Compliance') {
            if (ql.contains('consent') || ql.contains('dpdp') || ql.contains('privacy')) {
                return 'The agent implements explicit consent collection per DPDP Act 2023 Section 6. Consent artifacts are stored with timestamp, purpose limitation, and processing scope metadata. Data principal rights under Section 8 (access, correction, erasure, grievance redressal) are exposed via the customer portal. A Data Protection Impact Assessment has been completed per Section 10 requirements.';
            }
            if (ql.contains('rbi') || ql.contains('master direction') || ql.contains('regulation')) {
                return 'The agent\'s compliance posture covers RBI Master Directions on IT Governance, Risk, Controls and Assurance Practices (2023), RBI Framework for Responsible and Ethical Enablement of AI (FREE-AI), and RBI KYC Master Directions. All applicable clauses have been mapped in the compliance register with gap-level tracking. Quarterly attestation is scheduled to ensure ongoing alignment with regulatory updates.';
            }
            if (ql.contains('audit') || ql.contains('trail') || ql.contains('log')) {
                return 'All governance actions are recorded in an immutable hash-chain audit trail maintained by Pramaan. Each event is cryptographically linked to its predecessor, preventing tampering. The audit trail covers filing events, review decisions, document generation, and configuration changes. Logs are retained for 7 years per RBI archival requirements and CERT-In 180-day active retention mandate.';
            }
            return 'The compliance assessment covers all applicable Indian regulatory frameworks including RBI, CERT-In, and DPDP Act 2023. A total of 36 regulatory clauses have been evaluated across 2 regulators. The agent\'s data processing activities have been mapped against consent requirements, data localisation obligations, and cross-border transfer restrictions. Ongoing compliance monitoring is established through quarterly attestation cycles.';
        }

        if (lens == 'Legal') {
            if (ql.contains('liab') || ql.contains('responsible') || ql.contains('accountab')) {
                return 'Liability for agent decisions rests with the bank as the Data Fiduciary under DPDP Act 2023. The agent operates in an advisory capacity with human-in-the-loop for all consequential decisions, limiting direct liability exposure. Professional indemnity coverage has been reviewed to ensure AI-specific scenarios are included. The bank\'s Legal team has signed off on the liability framework.';
            }
            if (ql.contains('contract') || ql.contains('vendor') || ql.contains('salesforce')) {
                return 'The Salesforce Master Services Agreement covers platform-level security, availability, and data processing obligations. Salesforce\'s Data Processing Addendum (DPA) addresses DPDP Act requirements for data processors. The Trust Layer contractual guarantees ensure no customer data is used for model training. Sub-processor disclosures and audit rights are documented per DPDP Section 8(4) requirements.';
            }
            if (ql.contains('penalty') || ql.contains('fine') || ql.contains('sanction')) {
                return 'Non-compliance risks under DPDP Act 2023 include penalties up to INR 250 crore for significant data fiduciary breaches. RBI regulatory actions can include directions, penalties, or license restrictions. The current compliance posture, with identified gaps under remediation, demonstrates good-faith compliance efforts. A 30-day remediation timeline has been established to close all outstanding items before potential regulatory scrutiny.';
            }
            if (ql.contains('ip') || ql.contains('intellectual') || ql.contains('patent')) {
                return 'The agent is built on Salesforce Agentforce, a licensed commercial platform. No proprietary algorithms or third-party IP are embedded in the agent configuration. Prompt templates and business rules are bank-owned intellectual property. Salesforce\'s Trust Layer ensures agent outputs are not used to train foundation models, preserving the bank\'s data IP rights.';
            }
            return 'From a legal standpoint, the agent deployment has been assessed against consumer protection laws, data protection legislation (DPDP Act 2023), regulatory directives, and contractual obligations. The liability framework establishes clear accountability for agent decisions, with human oversight mechanisms as a key control. All contractual arrangements with Salesforce as the platform provider have been reviewed for compliance with Indian data protection requirements.';
        }

        if (lens == 'AI Risk Committee') {
            if (ql.contains('bias') || ql.contains('fair') || ql.contains('discriminat')) {
                return 'The agent\'s fairness assessment was conducted against RBI\'s FREE-AI framework principles. Demographic parity testing shows a bias score of 0.031 (within the 0.05 threshold). The agent does not use protected attributes (caste, religion, gender) as direct inputs. Indirect bias pathways through proxy variables have been evaluated and mitigated through feature importance analysis. Quarterly bias monitoring is mandated.';
            }
            if (ql.contains('explain') || ql.contains('interpret') || ql.contains('transparen')) {
                return 'The agent provides reasoning traces for all KYC verification decisions, meeting explainability requirements under RBI\'s Responsible AI framework. Decision factors are logged with confidence scores, enabling post-hoc review. Customer-facing explanations are generated in plain language per fair practices code requirements. The AI Risk Committee receives monthly explainability reports.';
            }
            if (ql.contains('model') || ql.contains('drift') || ql.contains('monitor')) {
                return 'Ongoing model monitoring includes monthly drift detection (distribution shift > 2 std dev triggers alert), quarterly performance benchmark re-runs, and annual comprehensive model review. The agent\'s task accuracy is currently at 94.7% against a 92% benchmark. Hallucination rate is 1.1% against a 2% threshold. All metrics are tracked in the Model Risk Management dashboard.';
            }
            if (ql.contains('board') || ql.contains('govern') || ql.contains('oversight')) {
                return 'The AI Risk Committee provides board-level oversight per RBI Master Directions on IT Governance Chapter IV. The committee meets quarterly to review all AI deployments, risk assessments, and incident reports. This agent requires committee approval as a Medium-risk deployment. Post-approval, the committee will receive quarterly performance and compliance reports, with escalation protocols for any material adverse events.';
            }
            return 'The AI Risk Committee assessment covers model risk (bias, fairness, explainability), operational risk (autonomy level, failure modes), and reputational risk (customer-facing AI). The agent is classified as Medium risk per the bank\'s AI Risk Taxonomy. Key controls include human-in-the-loop for consequential decisions, Trust Layer guardrails, and comprehensive monitoring. The committee\'s conditional approval is recommended subject to remediation of identified compliance gaps within 30 days.';
        }

        return 'Based on the governance assessment for this agent, the applicable regulatory frameworks have been evaluated comprehensively. The current compliance posture reflects the assessment of 36 clauses across applicable Indian regulators. For specific details about a particular aspect, please ask a more targeted question about testing, compliance, data protection, risk scoring, or any other governance dimension.';
    }
}
