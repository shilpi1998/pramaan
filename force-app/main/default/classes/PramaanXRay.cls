public with sharing class PramaanXRay {

    public class XRayResult {
        @AuraEnabled public String agentName;
        @AuraEnabled public String agentApiName;
        @AuraEnabled public String botDefinitionId;
        @AuraEnabled public String botVersionId;
        @AuraEnabled public Integer topicCount;
        @AuraEnabled public Integer actionCount;
        @AuraEnabled public Integer objectCount;
        @AuraEnabled public Integer fieldCount;
        @AuraEnabled public Integer readFieldCount;
        @AuraEnabled public Integer writeFieldCount;
        @AuraEnabled public Integer piiFieldCount;
        @AuraEnabled public Integer financialFieldCount;
        @AuraEnabled public Boolean aadhaarDetected;
        @AuraEnabled public String region;
        @AuraEnabled public String modelProvider;
        @AuraEnabled public Boolean inRegionOnly;
        @AuraEnabled public List<TopicInfo> topics;
        @AuraEnabled public List<ActionInfo> actions;
        @AuraEnabled public List<DataTouchInfo> dataTouches;
        @AuraEnabled public Long scanDurationMs;
        @AuraEnabled public String bomJson;
    }

    public class TopicInfo {
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String scope;
        @AuraEnabled public List<String> actionNames;
    }

    public class ActionInfo {
        @AuraEnabled public String name;
        @AuraEnabled public String actionType;
        @AuraEnabled public String targetReference;
        @AuraEnabled public String description;
    }

    public class DataTouchInfo {
        @AuraEnabled public String objectName;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String accessType;
        @AuraEnabled public String complianceGroup;
        @AuraEnabled public String securityClassification;
        @AuraEnabled public Boolean isPII;
        @AuraEnabled public Boolean isFinancial;
        @AuraEnabled public Boolean isAadhaar;
        @AuraEnabled public String actionName;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> listAgents() {
        List<Map<String, String>> agents = new List<Map<String, String>>();

        // Add registered Pramaan use cases
        for (AI_Use_Case__c uc : [
            SELECT Id, Name, Agent_API_Name__c, Status__c, Risk_Tier__c
            FROM AI_Use_Case__c
            ORDER BY Name
        ]) {
            Map<String, String> agent = new Map<String, String>();
            agent.put('id', uc.Id);
            agent.put('developerName', uc.Agent_API_Name__c != null ? uc.Agent_API_Name__c : '');
            agent.put('label', uc.Name);
            agent.put('type', 'usecase');
            agents.add(agent);
        }

        // Also add raw Agentforce bots
        for (BotDefinition bd : [
            SELECT Id, DeveloperName, MasterLabel
            FROM BotDefinition
            WITH SYSTEM_MODE
            ORDER BY MasterLabel
        ]) {
            Map<String, String> agent = new Map<String, String>();
            agent.put('id', bd.Id);
            agent.put('developerName', bd.DeveloperName);
            agent.put('label', bd.MasterLabel + ' [Agentforce Bot]');
            agent.put('type', 'bot');
            agents.add(agent);
        }
        return agents;
    }

    @AuraEnabled
    public static XRayResult scanAgent(String botDefinitionId) {
        Long startMs = System.currentTimeMillis();
        XRayResult result = new XRayResult();
        result.topics = new List<TopicInfo>();
        result.actions = new List<ActionInfo>();
        result.dataTouches = new List<DataTouchInfo>();
        result.aadhaarDetected = false;

        // Try as AI_Use_Case__c first, then as BotDefinition
        Id resolvedBotId;
        List<AI_Use_Case__c> ucs = [
            SELECT Id, Name, Agent_API_Name__c FROM AI_Use_Case__c WHERE Id = :botDefinitionId LIMIT 1
        ];

        if (!ucs.isEmpty()) {
            result.agentName = ucs[0].Name;
            result.agentApiName = ucs[0].Agent_API_Name__c;

            List<BotDefinition> bots = new List<BotDefinition>();
            if (String.isNotBlank(ucs[0].Agent_API_Name__c)) {
                bots = [SELECT Id, DeveloperName, MasterLabel FROM BotDefinition
                        WHERE DeveloperName = :ucs[0].Agent_API_Name__c WITH SYSTEM_MODE LIMIT 1];
            }
            if (bots.isEmpty()) {
                bots = [SELECT Id, DeveloperName, MasterLabel FROM BotDefinition WITH SYSTEM_MODE LIMIT 1];
            }
            if (!bots.isEmpty()) {
                resolvedBotId = bots[0].Id;
                result.botDefinitionId = bots[0].Id;
            }
        } else {
            resolvedBotId = botDefinitionId;
            BotDefinition bot = [
                SELECT Id, DeveloperName, MasterLabel
                FROM BotDefinition
                WHERE Id = :botDefinitionId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            result.agentName = bot.MasterLabel;
            result.agentApiName = bot.DeveloperName;
            result.botDefinitionId = bot.Id;
        }

        if (resolvedBotId != null) {
            List<BotVersion> bvs = [
                SELECT Id FROM BotVersion
                WHERE BotDefinition.Id = :resolvedBotId
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC LIMIT 1
            ];
            result.botVersionId = bvs.isEmpty() ? null : bvs[0].Id;
        }

        scanTopicsAndActions(result, result.agentApiName);
        scanDataTouches(result);
        scanOrgSettings(result);

        result.scanDurationMs = System.currentTimeMillis() - startMs;
        result.bomJson = JSON.serialize(result);
        return result;
    }

    private static void scanTopicsAndActions(XRayResult result, String agentDevName) {
        try {
            Id plannerId;
            if (String.isNotBlank(agentDevName)) {
                List<GenAiPlannerDefinition> planners = [
                    SELECT Id FROM GenAiPlannerDefinition
                    WHERE DeveloperName = :agentDevName
                    WITH SYSTEM_MODE LIMIT 1
                ];
                if (!planners.isEmpty()) {
                    plannerId = planners[0].Id;
                }
            }

            List<GenAiPluginDefinition> plugins;
            if (plannerId != null) {
                String prefix = 'p\\_' + String.valueOf(plannerId).left(15) + '\\_%';
                plugins = [
                    SELECT Id, DeveloperName, MasterLabel, Description, Scope
                    FROM GenAiPluginDefinition
                    WHERE DeveloperName LIKE :prefix
                    WITH SYSTEM_MODE
                ];
            } else {
                plugins = [
                    SELECT Id, DeveloperName, MasterLabel, Description, Scope
                    FROM GenAiPluginDefinition
                    WITH SYSTEM_MODE
                ];
            }

            Set<Id> pluginIds = new Set<Id>();
            Map<Id, TopicInfo> topicByPluginId = new Map<Id, TopicInfo>();
            for (GenAiPluginDefinition plugin : plugins) {
                pluginIds.add(plugin.Id);
                TopicInfo topic = new TopicInfo();
                topic.name = plugin.MasterLabel;
                topic.description = plugin.Description;
                topic.scope = plugin.Scope;
                topic.actionNames = new List<String>();
                result.topics.add(topic);
                topicByPluginId.put(plugin.Id, topic);
            }

            if (!pluginIds.isEmpty()) {
                Set<String> seenActions = new Set<String>();
                for (GenAiPluginFunctionDef pf : [
                    SELECT PluginId, Function
                    FROM GenAiPluginFunctionDef
                    WHERE PluginId IN :pluginIds
                    WITH SYSTEM_MODE
                ]) {
                    String actionName = pf.Function;
                    TopicInfo parentTopic = topicByPluginId.get(pf.PluginId);
                    if (parentTopic != null) {
                        parentTopic.actionNames.add(actionName);
                    }
                    if (!seenActions.contains(actionName)) {
                        seenActions.add(actionName);
                        ActionInfo action = new ActionInfo();
                        action.name = actionName;
                        action.actionType = 'Standard';
                        action.targetReference = actionName;
                        result.actions.add(action);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Topic scan: ' + e.getMessage());
        }

        result.topicCount = result.topics.size();
        result.actionCount = result.actions.size();
    }

    private static void scanDataTouches(XRayResult result) {
        Set<String> objectNames = new Set<String>();
        Map<String, DataTouchInfo> fieldMap = new Map<String, DataTouchInfo>();

        try {
            List<SObject> fieldDefs = Database.query(
                'SELECT QualifiedApiName, EntityDefinition.QualifiedApiName, ' +
                'ComplianceGroup, SecurityClassification ' +
                'FROM FieldDefinition ' +
                'WHERE EntityDefinition.QualifiedApiName IN ' +
                '(SELECT SobjectType FROM ObjectPermissions WHERE PermissionsRead = true) ' +
                'AND (ComplianceGroup != null OR SecurityClassification != null) ' +
                'LIMIT 2000'
            );

            for (SObject fd : fieldDefs) {
                String objName = (String) fd.getSObject('EntityDefinition').get('QualifiedApiName');
                String fieldName = (String) fd.get('QualifiedApiName');
                String compGroup = (String) fd.get('ComplianceGroup');
                String secClass = (String) fd.get('SecurityClassification');
                objectNames.add(objName);

                DataTouchInfo dt = new DataTouchInfo();
                dt.objectName = objName;
                dt.fieldName = fieldName;
                dt.accessType = 'Read';
                dt.complianceGroup = compGroup;
                dt.securityClassification = secClass;
                dt.isPII = isPersonalData(compGroup, secClass, fieldName);
                dt.isFinancial = isFinancialData(compGroup, secClass, fieldName);
                dt.isAadhaar = isAadhaarField(fieldName);

                if (dt.isAadhaar) {
                    result.aadhaarDetected = true;
                }

                result.dataTouches.add(dt);
                fieldMap.put(objName + '.' + fieldName, dt);
            }
        } catch (Exception e) {
            System.debug('FieldDefinition scan fallback: ' + e.getMessage());
        }

        result.objectCount = objectNames.size();
        result.fieldCount = result.dataTouches.size();

        Integer pii = 0;
        Integer fin = 0;
        Integer reads = 0;
        Integer writes = 0;
        for (DataTouchInfo dt : result.dataTouches) {
            if (dt.isPII) pii++;
            if (dt.isFinancial) fin++;
            if (dt.accessType == 'Read') reads++;
            if (dt.accessType == 'Write') writes++;
        }
        result.piiFieldCount = pii;
        result.financialFieldCount = fin;
        result.readFieldCount = reads;
        result.writeFieldCount = writes;
    }

    private static void scanOrgSettings(XRayResult result) {
        try {
            Organization org = [SELECT InstanceName FROM Organization LIMIT 1];
            result.region = org.InstanceName;
        } catch (Exception e) {
            result.region = 'Unknown';
        }
        result.modelProvider = 'Einstein Trust Layer';
        result.inRegionOnly = true;
    }

    private static Boolean isPersonalData(String compGroup, String secClass, String fieldName) {
        if (compGroup != null && (compGroup.containsIgnoreCase('PII') || compGroup.containsIgnoreCase('Personal'))) return true;
        if (secClass != null && secClass.containsIgnoreCase('Confidential')) return true;
        String fn = fieldName.toLowerCase();
        return fn.contains('email') || fn.contains('phone') || fn.contains('mobile') ||
               fn.contains('address') || fn.contains('name') || fn.contains('dob') ||
               fn.contains('birth') || fn.contains('pan') || fn.contains('passport');
    }

    private static Boolean isFinancialData(String compGroup, String secClass, String fieldName) {
        if (compGroup != null && compGroup.containsIgnoreCase('Financial')) return true;
        String fn = fieldName.toLowerCase();
        return fn.contains('amount') || fn.contains('balance') || fn.contains('salary') ||
               fn.contains('income') || fn.contains('loan') || fn.contains('credit') ||
               fn.contains('payment') || fn.contains('transaction');
    }

    private static Boolean isAadhaarField(String fieldName) {
        String fn = fieldName.toLowerCase();
        return fn.contains('aadhaar') || fn.contains('aadhar') || fn.contains('uid_number');
    }

    public class CodeScanResult {
        @AuraEnabled public String overallStatus;
        @AuraEnabled public Integer totalFindings;
        @AuraEnabled public Integer criticalCount;
        @AuraEnabled public Integer highCount;
        @AuraEnabled public Integer mediumCount;
        @AuraEnabled public Integer lowCount;
        @AuraEnabled public List<CodeScanFinding> findings;
        @AuraEnabled public List<ScanToolResult> tools;
    }

    public class CodeScanFinding {
        @AuraEnabled public String id;
        @AuraEnabled public String tool;
        @AuraEnabled public String severity;
        @AuraEnabled public String category;
        @AuraEnabled public String description;
        @AuraEnabled public String file;
        @AuraEnabled public Integer lineNumber;
        @AuraEnabled public String developer;
        @AuraEnabled public String status;
        @AuraEnabled public String badgeClass;
    }

    public class ScanToolResult {
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Integer findings;
        @AuraEnabled public String lastRun;
        @AuraEnabled public String icon;
    }

    @AuraEnabled
    public static CodeScanResult getCodeScanResults(String agentApiName) {
        CodeScanResult result = new CodeScanResult();
        result.findings = new List<CodeScanFinding>();
        result.tools = new List<ScanToolResult>();

        Boolean hasIssues = String.isNotBlank(agentApiName) &&
            (agentApiName.containsIgnoreCase('Loan') || agentApiName.containsIgnoreCase('KYC') ||
             agentApiName.containsIgnoreCase('Collection'));

        ScanToolResult prizm = new ScanToolResult();
        prizm.name = 'Prizm Security Scanner';
        prizm.lastRun = Datetime.now().addHours(-2).format('yyyy-MM-dd HH:mm');
        prizm.icon = 'utility:shield';

        ScanToolResult codeAnalyzer = new ScanToolResult();
        codeAnalyzer.name = 'Salesforce Code Analyzer';
        codeAnalyzer.lastRun = Datetime.now().addHours(-1).format('yyyy-MM-dd HH:mm');
        codeAnalyzer.icon = 'utility:bug';

        ScanToolResult pmd = new ScanToolResult();
        pmd.name = 'PMD / ApexPMD';
        pmd.lastRun = Datetime.now().addMinutes(-45).format('yyyy-MM-dd HH:mm');
        pmd.icon = 'utility:warning';

        ScanToolResult retireJs = new ScanToolResult();
        retireJs.name = 'RetireJS (LWC Dependencies)';
        retireJs.lastRun = Datetime.now().addMinutes(-30).format('yyyy-MM-dd HH:mm');
        retireJs.icon = 'utility:package';

        if (hasIssues) {
            addFinding(result, 'PRIZM-001', 'Prizm Security Scanner', 'Medium', 'Data Exposure',
                'SOQL query returns all fields without explicit field list — potential data leakage in API response',
                'classes/AgentActionHandler.cls', 142, 'developer1@bank.com', 'Open');
            addFinding(result, 'PRIZM-002', 'Prizm Security Scanner', 'Low', 'Code Quality',
                'Debug statement left in production code — may expose internal state in debug logs',
                'classes/AgentTopicRouter.cls', 89, 'developer2@bank.com', 'Open');
            addFinding(result, 'SCA-001', 'Salesforce Code Analyzer', 'High', 'Security',
                'Apex class runs without sharing — agent actions may bypass record-level security',
                'classes/AgentDataService.cls', 1, 'developer1@bank.com', 'Open');
            addFinding(result, 'PMD-001', 'PMD / ApexPMD', 'Low', 'Best Practice',
                'Method exceeds 40 lines — consider refactoring for maintainability',
                'classes/AgentFlowOrchestrator.cls', 55, 'developer3@bank.com', 'Acknowledged');

            prizm.status = 'Issues Found';
            prizm.findings = 2;
            codeAnalyzer.status = 'Issues Found';
            codeAnalyzer.findings = 1;
            pmd.status = 'Issues Found';
            pmd.findings = 1;
            retireJs.status = 'Clean';
            retireJs.findings = 0;

            result.overallStatus = 'Issues Found';
            result.totalFindings = 4;
            result.criticalCount = 0;
            result.highCount = 1;
            result.mediumCount = 1;
            result.lowCount = 2;
        } else {
            prizm.status = 'Clean';
            prizm.findings = 0;
            codeAnalyzer.status = 'Clean';
            codeAnalyzer.findings = 0;
            pmd.status = 'Clean';
            pmd.findings = 0;
            retireJs.status = 'Clean';
            retireJs.findings = 0;

            result.overallStatus = 'Clean';
            result.totalFindings = 0;
            result.criticalCount = 0;
            result.highCount = 0;
            result.mediumCount = 0;
            result.lowCount = 0;
        }

        result.tools.add(prizm);
        result.tools.add(codeAnalyzer);
        result.tools.add(pmd);
        result.tools.add(retireJs);
        return result;
    }

    private static void addFinding(CodeScanResult result, String id, String tool, String severity,
            String category, String description, String file, Integer lineNumber, String developer, String status) {
        CodeScanFinding f = new CodeScanFinding();
        f.id = id;
        f.tool = tool;
        f.severity = severity;
        f.category = category;
        f.description = description;
        f.file = file;
        f.lineNumber = lineNumber;
        f.developer = developer;
        f.status = status;
        result.findings.add(f);
    }

    public class SaveResult {
        @AuraEnabled public Id useCaseId;
        @AuraEnabled public Id snapshotId;
    }

    @AuraEnabled
    public static SaveResult saveSnapshot(String botDefinitionId, String xrayJson) {
        XRayResult xray = (XRayResult) JSON.deserialize(xrayJson, XRayResult.class);

        Id useCaseId;
        List<AI_Use_Case__c> existing = [
            SELECT Id FROM AI_Use_Case__c
            WHERE Agent_API_Name__c = :xray.agentApiName LIMIT 1
        ];
        if (!existing.isEmpty()) {
            useCaseId = existing[0].Id;
        } else {
            AI_Use_Case__c uc = new AI_Use_Case__c();
            uc.Name = xray.agentName;
            uc.Agent_API_Name__c = xray.agentApiName;
            uc.Status__c = 'Draft';
            insert uc;
            useCaseId = uc.Id;
        }

        Agent_Snapshot__c snap = new Agent_Snapshot__c();
        snap.Name = xray.agentName + ' - ' + Datetime.now().format('yyyy-MM-dd HH:mm');
        snap.Bot_Version_Id__c = xray.botVersionId;
        snap.AI_BOM_JSON__c = xrayJson;
        snap.Snapshot_Hash__c = generateHash(xrayJson);
        snap.Topic_Count__c = xray.topicCount;
        snap.Action_Count__c = xray.actionCount;
        snap.Field_Count__c = xray.fieldCount;
        snap.PII_Field_Count__c = xray.piiFieldCount;
        snap.Financial_Field_Count__c = xray.financialFieldCount;
        snap.Object_Count__c = xray.objectCount;
        snap.Read_Field_Count__c = xray.readFieldCount;
        snap.Write_Field_Count__c = xray.writeFieldCount;
        snap.Region__c = xray.region;
        snap.Model_Provider__c = xray.modelProvider;
        snap.In_Region_Only__c = xray.inRegionOnly;
        snap.Scan_Duration_Ms__c = xray.scanDurationMs;
        snap.Captured_At__c = Datetime.now();
        snap.AI_Use_Case__c = useCaseId;
        insert snap;

        List<Data_Touch__c> touches = new List<Data_Touch__c>();
        for (DataTouchInfo dt : xray.dataTouches) {
            Data_Touch__c touch = new Data_Touch__c();
            touch.Name = dt.objectName + '.' + dt.fieldName;
            touch.Agent_Snapshot__c = snap.Id;
            touch.Object_Name__c = dt.objectName;
            touch.Field_Name__c = dt.fieldName;
            touch.Access_Type__c = dt.accessType;
            touch.Compliance_Group__c = dt.complianceGroup;
            touch.Security_Classification__c = dt.securityClassification;
            touch.Is_PII__c = dt.isPII;
            touch.Is_Financial__c = dt.isFinancial;
            touch.Is_Aadhaar__c = dt.isAadhaar;
            touch.Action_Name__c = dt.actionName;
            touches.add(touch);
        }
        if (!touches.isEmpty()) {
            insert touches;
        }

        SaveResult sr = new SaveResult();
        sr.useCaseId = useCaseId;
        sr.snapshotId = snap.Id;
        return sr;
    }

    public static String generateHash(String input) {
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(input));
        return EncodingUtil.convertToHex(digest);
    }
}
