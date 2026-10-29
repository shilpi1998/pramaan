public with sharing class PramaanAuditTrail {

    @AuraEnabled
    public static void logEvent(Id governancePackId, String eventType, String payload) {
        Integer nextSeq = 1;
        String prevHash = '0';

        List<Audit_Event__c> lastEvent = [
            SELECT Sequence__c, Event_Hash__c
            FROM Audit_Event__c
            WHERE Governance_Pack__c = :governancePackId
            ORDER BY Sequence__c DESC
            LIMIT 1
        ];
        if (!lastEvent.isEmpty()) {
            nextSeq = (Integer) lastEvent[0].Sequence__c + 1;
            prevHash = lastEvent[0].Event_Hash__c;
        }

        Audit_Event__c evt = new Audit_Event__c();
        evt.Governance_Pack__c = governancePackId;
        evt.Sequence__c = nextSeq;
        evt.Event_Type__c = eventType;
        evt.Actor__c = UserInfo.getName();
        evt.Payload__c = payload;
        evt.Previous_Hash__c = prevHash;
        evt.Event_Timestamp__c = Datetime.now();

        String hashInput = nextSeq + '|' + eventType + '|' + UserInfo.getUserId() + '|' + payload + '|' + prevHash;
        evt.Event_Hash__c = PramaanXRay.generateHash(hashInput);

        insert evt;
    }

    @AuraEnabled(cacheable=true)
    public static List<Audit_Event__c> getAuditTrail(Id governancePackId) {
        return [
            SELECT Name, Sequence__c, Event_Type__c, Actor__c, Payload__c,
                   Previous_Hash__c, Event_Hash__c, Event_Timestamp__c
            FROM Audit_Event__c
            WHERE Governance_Pack__c = :governancePackId
            ORDER BY Sequence__c ASC
        ];
    }

    @AuraEnabled
    public static Map<String, Object> verifyChain(Id governancePackId) {
        List<Audit_Event__c> events = getAuditTrail(governancePackId);
        Map<String, Object> result = new Map<String, Object>();
        result.put('totalEvents', events.size());
        result.put('verified', true);
        result.put('brokenAt', null);

        String expectedPrevHash = '0';
        for (Audit_Event__c evt : events) {
            if (evt.Previous_Hash__c != expectedPrevHash) {
                result.put('verified', false);
                result.put('brokenAt', evt.Sequence__c);
                break;
            }
            String hashInput = (Integer) evt.Sequence__c + '|' + evt.Event_Type__c + '|' +
                              evt.Actor__c + '|' + evt.Payload__c + '|' + evt.Previous_Hash__c;
            expectedPrevHash = evt.Event_Hash__c;
        }

        return result;
    }
}
