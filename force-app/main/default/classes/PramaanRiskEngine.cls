public with sharing class PramaanRiskEngine {

    public class RiskResult {
        @AuraEnabled public Integer score;
        @AuraEnabled public String tier;
        @AuraEnabled public List<ScoreFactor> factors;
        @AuraEnabled public List<String> floors;
        @AuraEnabled public List<String> hardTriggers;
    }

    public class ScoreFactor {
        @AuraEnabled public String factor;
        @AuraEnabled public String value;
        @AuraEnabled public Integer points;
    }

    public class ApplicabilityResult {
        @AuraEnabled public Integer totalClauses;
        @AuraEnabled public Integer applicableClauses;
        @AuraEnabled public Integer naClauses;
        @AuraEnabled public Integer inForceClauses;
        @AuraEnabled public Integer futureClauses;
        @AuraEnabled public Integer guidanceClauses;
        @AuraEnabled public List<ClauseMatch> matches;
    }

    public class ClauseMatch {
        @AuraEnabled public String clauseName;
        @AuraEnabled public String regulator;
        @AuraEnabled public String reference;
        @AuraEnabled public String obligation;
        @AuraEnabled public String bindingStatus;
        @AuraEnabled public String lens;
        @AuraEnabled public String whyApplies;
        @AuraEnabled public Boolean applies;
        @AuraEnabled public String evidenceHint;
        @AuraEnabled public String sourceUrl;
        @AuraEnabled public Boolean mentionsAI;
        @AuraEnabled public Date effectiveFrom;
        @AuraEnabled public Date effectiveTo;
    }

    @AuraEnabled
    public static RiskResult assessRisk(Id useCaseId) {
        AI_Use_Case__c uc = [
            SELECT Audience__c, Decision_Impact__c, Autonomy__c,
                   Data_Categories__c, Channels__c, Function__c,
                   Vulnerable_Customers__c, Sub_Sector__c
            FROM AI_Use_Case__c
            WHERE Id = :useCaseId
        ];

        RiskResult r = new RiskResult();
        r.factors = new List<ScoreFactor>();
        r.floors = new List<String>();
        r.hardTriggers = new List<String>();
        r.score = 0;

        r.score += scoreFactor(r.factors, 'Audience', uc.Audience__c,
            new Map<String, Integer>{'Employee' => 0, 'Partner' => 1, 'Customer' => 3});
        r.score += scoreFactor(r.factors, 'Decision Impact', uc.Decision_Impact__c,
            new Map<String, Integer>{'Informational' => 0, 'Advisory' => 1, 'Decisioning' => 3, 'Transactional' => 3});
        r.score += scoreFactor(r.factors, 'Human Oversight Level', uc.Autonomy__c,
            new Map<String, Integer>{'Human-in-loop' => 0, 'Human-on-loop' => 1, 'Autonomous' => 3});

        Integer dataSens = 0;
        String cats = uc.Data_Categories__c != null ? uc.Data_Categories__c : '';
        if (cats.contains('Financial') || cats.contains('Aadhaar') || cats.contains('Health') || cats.contains('Children')) {
            dataSens = 3;
        } else if (cats.contains('Personal')) {
            dataSens = 2;
        } else if (cats.contains('Employee')) {
            dataSens = 1;
        }
        addFactor(r.factors, 'Data Sensitivity', cats, dataSens);
        r.score += dataSens;

        r.score += scoreFactor(r.factors, 'Vulnerable Customers',
            uc.Vulnerable_Customers__c ? 'Yes' : 'No',
            new Map<String, Integer>{'Yes' => 2, 'No' => 0});

        r.tier = tierFromScore(r.score);

        if (uc.Audience__c == 'Customer' && r.score < 6) {
            r.tier = 'Medium';
            r.floors.add('FREE-AI Rec 14: customer-facing agent is at least Medium');
        }
        if (uc.Audience__c == 'Customer' && uc.Autonomy__c == 'Autonomous') {
            r.tier = 'High';
            r.floors.add('FREE-AI Rec 14: autonomous + customer-facing is at least High');
        }
        if (uc.Decision_Impact__c == 'Decisioning' || uc.Decision_Impact__c == 'Transactional') {
            if (uc.Function__c == 'Origination' || uc.Function__c == 'Collections') {
                r.tier = 'High';
                r.floors.add('FREE-AI Rec 14: moves money or underwrites credit is at least High');
            }
        }

        if (cats.contains('Aadhaar') || cats.contains('Health')) {
            if (uc.Autonomy__c == 'Autonomous' &&
                (uc.Decision_Impact__c == 'Decisioning' || uc.Decision_Impact__c == 'Transactional')) {
                r.tier = 'Critical';
                r.hardTriggers.add('Autonomous credit/KYC decision with sensitive data');
            }
        }

        return r;
    }

    @AuraEnabled
    public static ApplicabilityResult mapClauses(Id useCaseId) {
        AI_Use_Case__c uc = [
            SELECT Sub_Sector__c, Audience__c, Decision_Impact__c, Autonomy__c,
                   Data_Categories__c, Channels__c, Function__c, Vulnerable_Customers__c
            FROM AI_Use_Case__c
            WHERE Id = :useCaseId
        ];

        Map<String, String> dna = buildDNA(uc);
        List<Reg_Clause__mdt> allClauses = Reg_Clause__mdt.getAll().values();

        ApplicabilityResult ar = new ApplicabilityResult();
        ar.matches = new List<ClauseMatch>();
        ar.totalClauses = allClauses.size();
        ar.applicableClauses = 0;
        ar.naClauses = 0;
        ar.inForceClauses = 0;
        ar.futureClauses = 0;
        ar.guidanceClauses = 0;

        Date today = Date.today();

        for (Reg_Clause__mdt clause : allClauses) {
            if (clause.Effective_To__c != null && clause.Effective_To__c < today) {
                continue;
            }

            ClauseMatch m = new ClauseMatch();
            m.clauseName = clause.DeveloperName;
            m.regulator = clause.Regulator__c;
            m.reference = clause.Reference__c;
            m.obligation = clause.Obligation__c;
            m.bindingStatus = clause.Binding_Status__c;
            m.lens = clause.Lens__c;
            m.evidenceHint = clause.Evidence_Hint__c;
            m.sourceUrl = clause.Source_URL__c;
            m.mentionsAI = clause.Mentions_AI__c;
            m.effectiveFrom = clause.Effective_From__c;
            m.effectiveTo = clause.Effective_To__c;

            String rule = clause.Applies_When__c;
            m.applies = evaluateRule(rule, dna);
            m.whyApplies = m.applies ? buildWhyText(rule, dna) : buildWhyNotText(rule, dna);

            ar.matches.add(m);
            if (m.applies) {
                ar.applicableClauses++;
                if (clause.Binding_Status__c == 'In force') ar.inForceClauses++;
                else if (clause.Binding_Status__c == 'From future date') ar.futureClauses++;
                else ar.guidanceClauses++;
            } else {
                ar.naClauses++;
            }
        }

        return ar;
    }

    private static Map<String, String> buildDNA(AI_Use_Case__c uc) {
        Map<String, String> dna = new Map<String, String>();
        dna.put('sub_sector', safe(uc.Sub_Sector__c));
        dna.put('audience', safe(uc.Audience__c));
        dna.put('decision_impact', safe(uc.Decision_Impact__c));
        dna.put('autonomy', safe(uc.Autonomy__c));
        dna.put('data', safe(uc.Data_Categories__c));
        dna.put('channel', safe(uc.Channels__c));
        dna.put('function', safe(uc.Function__c));
        dna.put('vulnerable', uc.Vulnerable_Customers__c ? 'Yes' : 'No');

        String subSec = safe(uc.Sub_Sector__c);
        Set<String> regs = new Set<String>();
        if (subSec.contains('SCB') || subSec.contains('SFB') || subSec.contains('Payments Bank') ||
            subSec.contains('NBFC') || subSec.contains('HFC')) {
            regs.add('RBI');
        }
        if (subSec.contains('AMC') || subSec.contains('Broker')) {
            regs.add('SEBI');
        }
        if (subSec.contains('Insurer')) {
            regs.add('IRDAI');
        }
        regs.add('CERT-In');
        regs.add('MeitY');
        dna.put('regulators', String.join(new List<String>(regs), ','));

        return dna;
    }

    public static Boolean evaluateRule(String rule, Map<String, String> dna) {
        if (String.isBlank(rule) || rule.trim().equalsIgnoreCase('always')) return true;

        rule = rule.trim();
        if (rule.contains(' AND ')) {
            List<String> parts = rule.split(' AND ');
            for (String part : parts) {
                if (!evaluateRule(part.trim(), dna)) return false;
            }
            return true;
        }
        if (rule.contains(' OR ')) {
            List<String> parts = rule.split(' OR ');
            for (String part : parts) {
                if (evaluateRule(part.trim(), dna)) return true;
            }
            return false;
        }

        if (rule.contains(' CONTAINS_ANY ')) {
            List<String> sides = rule.split(' CONTAINS_ANY ');
            String attr = dna.get(sides[0].trim().toLowerCase());
            if (attr == null) return false;
            String valList = sides[1].trim().replaceAll('[\\(\\)]', '');
            for (String v : valList.split(',')) {
                if (attr.containsIgnoreCase(v.trim())) return true;
            }
            return false;
        }
        if (rule.contains(' CONTAINS ')) {
            List<String> sides = rule.split(' CONTAINS ');
            String attr = dna.get(sides[0].trim().toLowerCase());
            return attr != null && attr.containsIgnoreCase(sides[1].trim());
        }
        if (rule.contains(' IN ')) {
            List<String> sides = rule.split(' IN ');
            String attr = dna.get(sides[0].trim().toLowerCase());
            if (attr == null) return false;
            String valList = sides[1].trim().replaceAll('[\\(\\)]', '');
            for (String v : valList.split(',')) {
                if (attr.equalsIgnoreCase(v.trim())) return true;
            }
            return false;
        }
        if (rule.contains(' != ')) {
            List<String> sides = rule.split(' != ');
            String attr = dna.get(sides[0].trim().toLowerCase());
            return attr != null && !attr.equalsIgnoreCase(sides[1].trim());
        }
        if (rule.contains(' = ')) {
            List<String> sides = rule.split(' = ');
            String attr = dna.get(sides[0].trim().toLowerCase());
            return attr != null && attr.equalsIgnoreCase(sides[1].trim());
        }

        return false;
    }

    private static String buildWhyText(String rule, Map<String, String> dna) {
        if (String.isBlank(rule) || rule.trim().equalsIgnoreCase('always')) {
            return 'Applies to all AI agents';
        }
        return 'Matched: ' + rule;
    }

    private static String buildWhyNotText(String rule, Map<String, String> dna) {
        return 'Does not apply: ' + rule;
    }

    private static Integer scoreFactor(List<ScoreFactor> factors, String name, String value, Map<String, Integer> scores) {
        Integer pts = scores.containsKey(value) ? scores.get(value) : 0;
        addFactor(factors, name, value, pts);
        return pts;
    }

    private static void addFactor(List<ScoreFactor> factors, String name, String value, Integer pts) {
        ScoreFactor sf = new ScoreFactor();
        sf.factor = name;
        sf.value = value != null ? value : '(not set)';
        sf.points = pts;
        factors.add(sf);
    }

    private static String tierFromScore(Integer score) {
        if (score >= 16) return 'Critical';
        if (score >= 11) return 'High';
        if (score >= 6) return 'Medium';
        return 'Low';
    }

    private static String safe(String s) {
        return s != null ? s : '';
    }
}
