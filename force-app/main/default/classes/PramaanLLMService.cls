public with sharing class PramaanLLMService {

    private static final String LLM_MODEL = 'sfdc_ai__DefaultBedrockAnthropicClaude35Sonnet';

    public class LLMAnalysis {
        @AuraEnabled public String summary;
        @AuraEnabled public List<RegulatorInsight> regulators;
        @AuraEnabled public List<String> keyRisks;
        @AuraEnabled public String recommendation;
        @AuraEnabled public Boolean isLLMGenerated;
    }

    public class RegulatorInsight {
        @AuraEnabled public String regulator;
        @AuraEnabled public String fullName;
        @AuraEnabled public String applicability;
        @AuraEnabled public String reasoning;
        @AuraEnabled public Integer estimatedClauses;
        @AuraEnabled public String confidence;
        @AuraEnabled public String badgeClass;
    }

    @AuraEnabled
    public static LLMAnalysis analyzeRegulatory(Id useCaseId, String apiKey) {
        AI_Use_Case__c uc = [
            SELECT Name, Sub_Sector__c, Audience__c, Decision_Impact__c, Autonomy__c,
                   Data_Categories__c, Channels__c, Function__c, Vulnerable_Customers__c,
                   Purpose__c
            FROM AI_Use_Case__c WHERE Id = :useCaseId
        ];

        String prompt = buildAnalysisPrompt(uc);

        try {
            String llmResponse = callPlatformLLM(prompt);
            LLMAnalysis analysis = parseLLMResponse(llmResponse);
            analysis.isLLMGenerated = true;
            return analysis;
        } catch (Exception e) {
            System.debug('LLM call failed, using deterministic analysis: ' + e.getMessage());
            LLMAnalysis analysis = buildDeterministicAnalysis(uc);
            analysis.isLLMGenerated = false;
            return analysis;
        }
    }

    @TestVisible
    private static String buildAnalysisPrompt(AI_Use_Case__c uc) {
        return 'You are an AI governance expert for Indian banking and financial services. ' +
            'Analyze the following AI agent and determine which Indian regulators and regulations apply.\n\n' +
            'AGENT: ' + uc.Name + '\n' +
            'Sub-Sector: ' + safe(uc.Sub_Sector__c) + '\n' +
            'Purpose: ' + safe(uc.Purpose__c) + '\n' +
            'Audience: ' + safe(uc.Audience__c) + '\n' +
            'Decision Impact: ' + safe(uc.Decision_Impact__c) + '\n' +
            'Autonomy: ' + safe(uc.Autonomy__c) + '\n' +
            'Data Categories: ' + safe(uc.Data_Categories__c) + '\n' +
            'Channels: ' + safe(uc.Channels__c) + '\n' +
            'Function: ' + safe(uc.Function__c) + '\n' +
            'Vulnerable Customers: ' + (uc.Vulnerable_Customers__c ? 'Yes' : 'No') + '\n\n' +
            'REGULATORS: RBI (51 clauses), MeitY (12 clauses), SEBI (4 clauses), ' +
            'IRDAI (4 clauses), CERT-In (3 clauses), TRAI (1 clause), UIDAI (1 clause)\n\n' +
            'Respond with a JSON object (no markdown, no code fences) with this exact structure:\n' +
            '{\n' +
            '  "summary": "one paragraph overview",\n' +
            '  "regulators": [\n' +
            '    {"regulator": "RBI", "fullName": "Reserve Bank of India", "applicability": "Applies|Partial|Does Not Apply", "reasoning": "explanation", "estimatedClauses": 0, "confidence": "High|Medium|Low"},\n' +
            '    ... for all 7 regulators\n' +
            '  ],\n' +
            '  "keyRisks": ["risk1", "risk2"],\n' +
            '  "recommendation": "governance recommendation"\n' +
            '}';
    }

    private static String callPlatformLLM(String prompt) {
        aiplatform.ModelsAPI api = new aiplatform.ModelsAPI();
        aiplatform.ModelsAPI.createGenerations_Request req = new aiplatform.ModelsAPI.createGenerations_Request();
        req.modelName = LLM_MODEL;

        aiplatform.ModelsAPI_GenerationRequest body = new aiplatform.ModelsAPI_GenerationRequest();
        body.prompt = 'You are an AI governance expert for Indian banking. Respond with valid JSON only, no markdown fences.\n\n' + prompt;
        req.body = body;

        aiplatform.ModelsAPI.createGenerations_Response resp = api.createGenerations(req);

        if (resp.responseCode != 200) {
            throw new CalloutException('Platform LLM returned HTTP ' + resp.responseCode);
        }

        return resp.Code200.generation.generatedText;
    }

    private static LLMAnalysis parseLLMResponse(String jsonResponse) {
        jsonResponse = jsonResponse.trim();
        if (jsonResponse.startsWith('```')) {
            jsonResponse = jsonResponse.substringAfter('\n');
            jsonResponse = jsonResponse.substringBeforeLast('```');
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        LLMAnalysis analysis = new LLMAnalysis();
        analysis.summary = (String) parsed.get('summary');
        analysis.recommendation = (String) parsed.get('recommendation');
        analysis.keyRisks = new List<String>();
        analysis.regulators = new List<RegulatorInsight>();

        List<Object> risks = (List<Object>) parsed.get('keyRisks');
        if (risks != null) {
            for (Object r : risks) analysis.keyRisks.add(String.valueOf(r));
        }

        List<Object> regs = (List<Object>) parsed.get('regulators');
        if (regs != null) {
            for (Object ro : regs) {
                Map<String, Object> rm = (Map<String, Object>) ro;
                RegulatorInsight ri = new RegulatorInsight();
                ri.regulator = (String) rm.get('regulator');
                ri.fullName = (String) rm.get('fullName');
                ri.applicability = (String) rm.get('applicability');
                ri.reasoning = (String) rm.get('reasoning');
                ri.estimatedClauses = rm.get('estimatedClauses') != null ? Integer.valueOf(rm.get('estimatedClauses')) : 0;
                ri.confidence = (String) rm.get('confidence');
                analysis.regulators.add(ri);
            }
        }

        return analysis;
    }

    private static LLMAnalysis buildDeterministicAnalysis(AI_Use_Case__c uc) {
        LLMAnalysis analysis = new LLMAnalysis();
        analysis.regulators = new List<RegulatorInsight>();
        analysis.keyRisks = new List<String>();

        String sub = safe(uc.Sub_Sector__c);
        String audience = safe(uc.Audience__c);
        String autonomy = safe(uc.Autonomy__c);
        String impact = safe(uc.Decision_Impact__c);
        String data = safe(uc.Data_Categories__c);
        String func = safe(uc.Function__c);
        Boolean vulnerable = uc.Vulnerable_Customers__c == true;

        Boolean isBank = sub.contains('SCB') || sub.contains('SFB') || sub.contains('Payments Bank') ||
                          sub.contains('NBFC') || sub.contains('HFC');
        Boolean isCapitalMarket = sub.contains('AMC') || sub.contains('Broker');
        Boolean isInsurer = sub.contains('Insurer');
        Boolean hasPII = data.containsIgnoreCase('Personal') || data.containsIgnoreCase('PII');
        Boolean hasFinancial = data.containsIgnoreCase('Financial');
        Boolean hasAadhaar = data.containsIgnoreCase('Aadhaar');
        Boolean isCustomerFacing = audience == 'Customer';
        Boolean isAutonomous = autonomy == 'Autonomous';
        Boolean isDecisioning = impact == 'Decisioning' || impact == 'Transactional';

        // RBI Analysis
        if (isBank) {
            RegulatorInsight rbi = new RegulatorInsight();
            rbi.regulator = 'RBI';
            rbi.fullName = 'Reserve Bank of India';
            rbi.applicability = 'Applies';
            rbi.confidence = 'High';

            Integer clauses = 20;
            String reason = 'As a ' + sub + ' entity, RBI Master Directions on IT Governance (2023) apply comprehensively. ';
            if (isCustomerFacing) {
                reason += 'Customer-facing deployment triggers Digital Lending Guidelines and Fair Practices Code. ';
                clauses += 10;
            }
            if (isAutonomous) {
                reason += 'Autonomous operation requires explicit compliance with RBI circular on AI/ML in decision-making. ';
                clauses += 5;
            }
            if (hasFinancial) {
                reason += 'Financial data handling triggers RBI data localisation norms under Payment & Settlement Systems Act. ';
                clauses += 8;
            }
            if (func == 'Origination' || func == 'Collections') {
                reason += 'Credit/collections function mandates Fair Practices Code and outsourcing guidelines compliance. ';
                clauses += 5;
            }
            rbi.reasoning = reason.trim();
            rbi.estimatedClauses = Math.min(clauses, 51);
            analysis.regulators.add(rbi);
        } else {
            RegulatorInsight rbi = new RegulatorInsight();
            rbi.regulator = 'RBI';
            rbi.fullName = 'Reserve Bank of India';
            rbi.applicability = 'Does Not Apply';
            rbi.reasoning = sub + ' entity falls outside RBI\'s direct regulatory purview.';
            rbi.estimatedClauses = 0;
            rbi.confidence = 'High';
            analysis.regulators.add(rbi);
        }

        // MeitY Analysis
        RegulatorInsight meity = new RegulatorInsight();
        meity.regulator = 'MeitY';
        meity.fullName = 'Ministry of Electronics & IT';
        meity.applicability = 'Applies';
        meity.confidence = 'High';
        Integer meityCount = 5;
        String meityReason = 'DPDP Act 2023 applies to all entities processing personal data. ';
        if (hasPII || isCustomerFacing) {
            meityReason += 'Customer data processing triggers Data Principal rights, consent management, and Data Fiduciary obligations. ';
            meityCount += 4;
        }
        if (isAutonomous) {
            meityReason += 'Autonomous AI triggers IndiaAI Mission transparency requirements and explainability mandates. ';
            meityCount += 2;
        }
        if (vulnerable) {
            meityReason += 'Processing data of vulnerable persons triggers enhanced protections under DPDP Act Section 9. ';
            meityCount += 1;
        }
        meity.reasoning = meityReason.trim();
        meity.estimatedClauses = Math.min(meityCount, 12);
        analysis.regulators.add(meity);

        // SEBI Analysis
        RegulatorInsight sebi = new RegulatorInsight();
        sebi.regulator = 'SEBI';
        sebi.fullName = 'Securities & Exchange Board of India';
        if (isCapitalMarket) {
            sebi.applicability = 'Applies';
            sebi.reasoning = sub + ' entities must comply with SEBI\'s circular on AI/ML in securities trading and advisory. Algo trading disclosure and model validation requirements apply.';
            sebi.estimatedClauses = 4;
            sebi.confidence = 'High';
        } else if (isBank && (func == 'Wealth' || func == 'Insurance Sales')) {
            sebi.applicability = 'Partial';
            sebi.reasoning = 'While not a direct SEBI-regulated entity, ' + func + ' function may trigger SEBI norms if agent provides investment advisory or distributes securities products.';
            sebi.estimatedClauses = 2;
            sebi.confidence = 'Medium';
        } else {
            sebi.applicability = 'Does Not Apply';
            sebi.reasoning = 'Entity and function do not fall under SEBI\'s regulatory scope for AI governance.';
            sebi.estimatedClauses = 0;
            sebi.confidence = 'High';
        }
        analysis.regulators.add(sebi);

        // IRDAI Analysis
        RegulatorInsight irdai = new RegulatorInsight();
        irdai.regulator = 'IRDAI';
        irdai.fullName = 'Insurance Regulatory & Development Authority';
        if (isInsurer) {
            irdai.applicability = 'Applies';
            irdai.reasoning = 'Insurance entity must comply with IRDAI guidelines on IT governance, digital sales practices, and claim processing AI. Particularly relevant for underwriting and claims automation.';
            irdai.estimatedClauses = 4;
            irdai.confidence = 'High';
        } else if (isBank && func == 'Insurance Sales') {
            irdai.applicability = 'Partial';
            irdai.reasoning = 'Bancassurance distribution channel triggers IRDAI corporate agency guidelines for AI-assisted insurance sales.';
            irdai.estimatedClauses = 2;
            irdai.confidence = 'Medium';
        } else {
            irdai.applicability = 'Does Not Apply';
            irdai.reasoning = 'Entity does not operate in insurance domain.';
            irdai.estimatedClauses = 0;
            irdai.confidence = 'High';
        }
        analysis.regulators.add(irdai);

        // CERT-In Analysis
        RegulatorInsight certIn = new RegulatorInsight();
        certIn.regulator = 'CERT-In';
        certIn.fullName = 'Indian Computer Emergency Response Team';
        certIn.applicability = 'Applies';
        certIn.confidence = 'High';
        certIn.reasoning = 'CERT-In Directions 2022 mandate 6-hour incident reporting, log retention for 180 days, and synchronized system clocks for all entities with IT infrastructure. AI agent deployments must maintain audit trails for cyber incident traceability.';
        certIn.estimatedClauses = 3;
        analysis.regulators.add(certIn);

        // TRAI Analysis
        RegulatorInsight trai = new RegulatorInsight();
        trai.regulator = 'TRAI';
        trai.fullName = 'Telecom Regulatory Authority of India';
        String channels = safe(uc.Channels__c);
        if (channels.containsIgnoreCase('WhatsApp') || channels.containsIgnoreCase('SMS') || channels.containsIgnoreCase('Voice')) {
            trai.applicability = 'Applies';
            trai.reasoning = 'Agent communicates via telecom channels (' + channels + '). TRAI regulations on unsolicited commercial communications, DND registry, and AI-powered call handling apply.';
            trai.estimatedClauses = 1;
            trai.confidence = 'High';
        } else {
            trai.applicability = 'Does Not Apply';
            trai.reasoning = 'Agent does not operate through telecom channels.';
            trai.estimatedClauses = 0;
            trai.confidence = 'High';
        }
        analysis.regulators.add(trai);

        // UIDAI Analysis
        RegulatorInsight uidai = new RegulatorInsight();
        uidai.regulator = 'UIDAI';
        uidai.fullName = 'Unique Identification Authority of India';
        if (hasAadhaar) {
            uidai.applicability = 'Applies';
            uidai.reasoning = 'Agent processes Aadhaar data — UIDAI regulations mandate masking (show only last 4 digits), virtual ID usage, encrypted storage, and audit logging. Violation penalties under Aadhaar Act Section 29.';
            uidai.estimatedClauses = 1;
            uidai.confidence = 'High';
        } else if (func == 'KYC') {
            uidai.applicability = 'Partial';
            uidai.reasoning = 'KYC function likely involves Aadhaar e-KYC or offline verification. Even if Aadhaar is not explicitly listed in data categories, eKYC flows trigger UIDAI compliance.';
            uidai.estimatedClauses = 1;
            uidai.confidence = 'Medium';
        } else {
            uidai.applicability = 'Does Not Apply';
            uidai.reasoning = 'Agent does not process Aadhaar or biometric data.';
            uidai.estimatedClauses = 0;
            uidai.confidence = 'High';
        }
        analysis.regulators.add(uidai);

        // Summary
        Integer totalApplicable = 0;
        Integer totalClauses = 0;
        for (RegulatorInsight ri : analysis.regulators) {
            if (ri.applicability == 'Applies' || ri.applicability == 'Partial') totalApplicable++;
            totalClauses += ri.estimatedClauses;
        }

        analysis.summary = 'This ' + sub + ' AI agent (' + uc.Name + ') serving ' + audience + ' users in ' +
            func + ' function has a regulatory exposure spanning ' + totalApplicable + ' of 7 Indian regulators with an estimated ' +
            totalClauses + ' applicable clauses. ' +
            (isAutonomous ? 'Autonomous operation significantly increases governance requirements. ' : '') +
            (isDecisioning ? 'Decisioning capability requires enhanced explainability and human oversight provisions. ' : '') +
            'A comprehensive compliance mapping is recommended before production deployment.';

        // Key Risks
        if (isCustomerFacing && isAutonomous) {
            analysis.keyRisks.add('Autonomous customer-facing AI requires mandatory human escalation pathways per FREE-AI Rec 14');
        }
        if (hasFinancial && isDecisioning) {
            analysis.keyRisks.add('Financial decisioning AI must maintain full explainability trail per RBI Fair Practices Code');
        }
        if (hasAadhaar) {
            analysis.keyRisks.add('Aadhaar data handling violations carry penalties up to Rs 1 crore per UIDAI Act Section 42');
        }
        if (hasPII) {
            analysis.keyRisks.add('Personal data processing requires explicit consent and purpose limitation under DPDP Act 2023');
        }
        if (vulnerable) {
            analysis.keyRisks.add('Enhanced protections required for vulnerable customer segment — additional review gates recommended');
        }
        if (isBank && isAutonomous && isDecisioning) {
            analysis.keyRisks.add('RBI may require Board-level AI Risk Committee approval for autonomous credit/transaction decisions');
        }

        // Recommendation
        analysis.recommendation = 'Based on the regulatory analysis, this agent requires governance review from ' +
            totalApplicable + ' regulators covering ' + totalClauses + ' clauses. ' +
            'Recommended next steps: (1) Complete Pramaan compliance mapping for all applicable clauses, ' +
            '(2) Route for ' + (totalClauses > 30 ? '5-gate' : totalClauses > 15 ? '4-gate' : '2-gate') + ' review including ' +
            (isBank ? 'AI Risk Committee and RBI Compliance' : 'Legal and Compliance') + ' sign-off, ' +
            '(3) Establish continuous monitoring for regulatory changes.';

        return analysis;
    }

    private static String safe(String s) {
        return s != null ? s : '';
    }
}
