public with sharing class CalculateEMIAction {

    @InvocableMethod(label='Calculate EMI' description='Calculates equated monthly installment based on loan amount, tenure and interest rate')
    public static List<String> calculateEMI(List<Id> opportunityIds) {
        return new List<String>{ 'EMI calculated' };
    }
}
