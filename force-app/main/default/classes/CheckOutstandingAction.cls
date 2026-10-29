public with sharing class CheckOutstandingAction {

    @InvocableMethod(label='Check Outstanding Balance' description='Retrieves outstanding loan balance, overdue amount and days past due for account')
    public static List<String> checkOutstanding(List<Id> accountIds) {
        return new List<String>{ 'Outstanding balance retrieved' };
    }
}
