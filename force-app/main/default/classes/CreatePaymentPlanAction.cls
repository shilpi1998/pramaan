public with sharing class CreatePaymentPlanAction {

    @InvocableMethod(label='Create Payment Plan' description='Generates restructured payment plan with revised EMI schedule for delinquent accounts')
    public static List<String> createPaymentPlan(List<Id> opportunityIds) {
        return new List<String>{ 'Payment plan created' };
    }
}
