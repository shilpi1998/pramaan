public with sharing class PramaanController {

    @AuraEnabled(cacheable=true)
    public static List<AI_Use_Case__c> getUseCases() {
        return [
            SELECT Id, Name, Status__c, Risk_Tier__c, Risk_Score__c,
                   Passport_Number__c, Agent_API_Name__c, Sub_Sector__c,
                   Purpose__c, Audience__c, Decision_Impact__c, Autonomy__c,
                   Function__c, Data_Categories__c, Channels__c,
                   (SELECT Id FROM GovernancePacks__r ORDER BY Version__c DESC LIMIT 1)
            FROM AI_Use_Case__c
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    @AuraEnabled
    public static Id createUseCase(String name, String purpose, String subSector,
                                    String decisionImpact, String autonomy,
                                    String audience, String channels,
                                    String func, String dataCategories) {
        AI_Use_Case__c uc = new AI_Use_Case__c();
        uc.Name = name;
        uc.Purpose__c = purpose;
        uc.Sub_Sector__c = subSector;
        uc.Decision_Impact__c = decisionImpact;
        uc.Autonomy__c = autonomy;
        uc.Audience__c = audience;
        uc.Channels__c = channels;
        uc.Function__c = func;
        uc.Data_Categories__c = dataCategories;
        uc.Status__c = 'New';
        insert uc;
        return uc.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUseCaseDetail(Id useCaseId) {
        AI_Use_Case__c uc = [
            SELECT Id, Name, Status__c, Risk_Tier__c, Risk_Score__c,
                   Passport_Number__c, Agent_API_Name__c, Sub_Sector__c,
                   Purpose__c, Audience__c, Decision_Impact__c, Autonomy__c,
                   Function__c, Data_Categories__c, Channels__c,
                   Passport_Issued__c
            FROM AI_Use_Case__c WHERE Id = :useCaseId
        ];
        Map<String, Object> result = new Map<String, Object>();
        result.put('useCase', uc);
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> runRiskAssessment(Id useCaseId) {
        PramaanRiskEngine.RiskResult risk = PramaanRiskEngine.assessRisk(useCaseId);

        AI_Use_Case__c uc = new AI_Use_Case__c(Id = useCaseId);
        uc.Risk_Score__c = risk.score;
        uc.Risk_Tier__c = risk.tier;
        uc.Status__c = 'Scanned';
        update uc;

        Map<String, Object> result = new Map<String, Object>();
        result.put('score', risk.score);
        result.put('tier', risk.tier);
        result.put('factors', JSON.serialize(risk.factors));
        result.put('floors', risk.floors);
        result.put('hardTriggers', risk.hardTriggers);
        return result;
    }

    @AuraEnabled
    public static void updateUseCase(Id useCaseId, String subSector, String decisionImpact,
                                      String autonomy, String audience, String channels,
                                      String func, String dataCategories, Boolean vulnerable) {
        AI_Use_Case__c uc = new AI_Use_Case__c(Id = useCaseId);
        uc.Sub_Sector__c = subSector;
        uc.Decision_Impact__c = decisionImpact;
        uc.Autonomy__c = autonomy;
        uc.Audience__c = audience;
        uc.Channels__c = channels;
        uc.Function__c = func;
        uc.Data_Categories__c = dataCategories;
        uc.Vulnerable_Customers__c = vulnerable;
        update uc;
    }

    @AuraEnabled(cacheable=true)
    public static List<Governance_Pack__c> getPacksForUseCase(Id useCaseId) {
        return [
            SELECT Id, Name, Version__c, Pack_Status__c, Filed_At__c,
                   Passport_Number__c, Passport_Issued_At__c,
                   Clauses_Total__c, Clauses_Met__c, Clauses_Gap__c, Clauses_NA__c,
                   Gates_Required__c, Gates_Approved__c, Approved_Hash__c,
                   Agent_Snapshot__c
            FROM Governance_Pack__c
            WHERE AI_Use_Case__c = :useCaseId
            ORDER BY Version__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Clause_Mapping__c> getClauseMappings(Id packId) {
        return [
            SELECT Id, Name, Clause_DeveloperName__c, Mapping_Status__c,
                   Why_It_Applies__c, Regulator__c, Clause_Reference__c,
                   Binding_Status__c, Evidence__c, Evidence_Status__c,
                   Obligation__c, Evidence_Hint__c, Lens__c
            FROM Clause_Mapping__c
            WHERE Governance_Pack__c = :packId
            ORDER BY Regulator__c, Name
        ];
    }

    @AuraEnabled
    public static void updateClauseMapping(Id clauseMappingId, String status, String evidence, String evidenceStatus) {
        Clause_Mapping__c cm = new Clause_Mapping__c(Id = clauseMappingId);
        if (String.isNotBlank(status)) {
            cm.Mapping_Status__c = status;
        }
        if (evidence != null) {
            cm.Evidence__c = evidence;
        }
        if (String.isNotBlank(evidenceStatus)) {
            cm.Evidence_Status__c = evidenceStatus;
        }
        update cm;
    }

    @AuraEnabled
    public static List<Reviewer_Brief__c> getReviewerBriefs(Id packId) {
        return [
            SELECT Id, Name, Lens__c, Approval_Status__c,
                   Reviewer__r.Name, Decision_Date__c, Reviewer_Comments__c,
                   Brief_Content__c
            FROM Reviewer_Brief__c
            WHERE Governance_Pack__c = :packId
            ORDER BY Lens__c
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Audit_Event__c> getAuditEvents(Id packId) {
        return [
            SELECT Id, Name, Event_Type__c, Payload__c, Event_Timestamp__c,
                   Event_Hash__c, Previous_Hash__c, Actor__c, Sequence__c
            FROM Audit_Event__c
            WHERE Governance_Pack__c = :packId
            ORDER BY Sequence__c ASC
        ];
    }

    @AuraEnabled
    public static PramaanLLMService.LLMAnalysis getLLMAnalysis(Id useCaseId, String apiKey) {
        return PramaanLLMService.analyzeRegulatory(useCaseId, apiKey);
    }

    @AuraEnabled(cacheable=true)
    public static List<PramaanFilingTemplates.FilingTemplate> getFilingTemplates() {
        return PramaanFilingTemplates.getAvailableTemplates();
    }

    @AuraEnabled
    public static String generateFromTemplate(Id packId, String templateType) {
        return PramaanGovernanceService.generateFilingDocumentFromTemplate(packId, templateType);
    }

    @AuraEnabled
    public static List<Filing_Document__c> getFilingDocuments(Id packId) {
        return PramaanGovernanceService.getFilingDocuments(packId);
    }

    @AuraEnabled
    public static List<PramaanFilingTemplates.TemplateReadiness> getTemplateReadiness(Id packId) {
        Governance_Pack__c pack = [
            SELECT AI_Use_Case__c, AI_Use_Case__r.Name, AI_Use_Case__r.Risk_Tier__c,
                   AI_Use_Case__r.Sub_Sector__c, AI_Use_Case__r.Function__c,
                   AI_Use_Case__r.Audience__c, AI_Use_Case__r.Autonomy__c,
                   AI_Use_Case__r.Decision_Impact__c, AI_Use_Case__r.Data_Categories__c,
                   AI_Use_Case__r.Vulnerable_Customers__c, AI_Use_Case__r.Agent_API_Name__c,
                   AI_Use_Case__r.Channels__c
            FROM Governance_Pack__c WHERE Id = :packId
        ];

        List<Clause_Mapping__c> clauses = [
            SELECT Regulator__c FROM Clause_Mapping__c
            WHERE Governance_Pack__c = :packId AND Mapping_Status__c != 'N/A'
        ];
        Set<String> regulators = new Set<String>();
        for (Clause_Mapping__c cm : clauses) {
            if (cm.Regulator__c != null) regulators.add(cm.Regulator__c);
        }

        List<Filing_Document__c> existingDocs = [
            SELECT Template_Type__c FROM Filing_Document__c
            WHERE Governance_Pack__c = :packId
        ];
        Set<String> generatedTypes = new Set<String>();
        for (Filing_Document__c fd : existingDocs) {
            generatedTypes.add(fd.Template_Type__c);
        }

        return PramaanFilingTemplates.assessReadiness(
            packId, regulators, pack.AI_Use_Case__r.Risk_Tier__c,
            pack.AI_Use_Case__r, generatedTypes
        );
    }

    @AuraEnabled
    public static List<String> generateAllRequiredDocuments(Id packId) {
        Governance_Pack__c pack = [
            SELECT AI_Use_Case__r.Risk_Tier__c
            FROM Governance_Pack__c WHERE Id = :packId
        ];

        List<Clause_Mapping__c> clauses = [
            SELECT Regulator__c FROM Clause_Mapping__c
            WHERE Governance_Pack__c = :packId AND Mapping_Status__c != 'N/A'
        ];
        Set<String> regulators = new Set<String>();
        for (Clause_Mapping__c cm : clauses) {
            if (cm.Regulator__c != null) regulators.add(cm.Regulator__c);
        }

        List<Filing_Document__c> existingDocs = [
            SELECT Template_Type__c FROM Filing_Document__c
            WHERE Governance_Pack__c = :packId
        ];
        Set<String> alreadyGenerated = new Set<String>();
        for (Filing_Document__c fd : existingDocs) {
            alreadyGenerated.add(fd.Template_Type__c);
        }

        List<String> requiredTypes = PramaanFilingTemplates.detectRequiredTemplates(
            regulators, pack.AI_Use_Case__r.Risk_Tier__c
        );

        List<String> generated = new List<String>();
        for (String tmplType : requiredTypes) {
            if (!alreadyGenerated.contains(tmplType)) {
                PramaanGovernanceService.generateFilingDocumentFromTemplate(packId, tmplType);
                generated.add(tmplType);
            }
        }
        return generated;
    }

    @AuraEnabled
    public static String askReviewerQuestion(Id briefId, String question) {
        return PramaanGovernanceService.askReviewerQuestion(briefId, question);
    }

    @AuraEnabled
    public static List<Review_QA__c> getReviewQAs(Id briefId) {
        return PramaanGovernanceService.getReviewQAs(briefId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPassportInfo(Id packId) {
        Governance_Pack__c pack = [
            SELECT Id, Name, Pack_Status__c, Passport_Number__c, Passport_Issued_At__c,
                   Approved_Hash__c, Gates_Required__c, Gates_Approved__c,
                   AI_Use_Case__r.Name, AI_Use_Case__r.Risk_Tier__c,
                   AI_Use_Case__r.Agent_API_Name__c,
                   Agent_Snapshot__r.Snapshot_Hash__c
            FROM Governance_Pack__c WHERE Id = :packId
        ];

        List<Reviewer_Brief__c> briefs = [
            SELECT Lens__c, Approval_Status__c, Decision_Date__c, Reviewer__r.Name
            FROM Reviewer_Brief__c WHERE Governance_Pack__c = :packId
            ORDER BY Lens__c
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('pack', pack);
        result.put('briefs', briefs);

        Map<String, Object> chain = PramaanAuditTrail.verifyChain(packId);
        result.put('chainVerified', chain.get('verified'));
        result.put('totalEvents', chain.get('totalEvents'));
        return result;
    }
}
