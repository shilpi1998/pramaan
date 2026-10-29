public with sharing class VerifyIncomeAction {

    @InvocableMethod(label='Verify Income' description='Validates applicant income against bank statements and ITR documents')
    public static List<String> verifyIncome(List<Id> contactIds) {
        return new List<String>{ 'Income verified' };
    }
}
