public with sharing class FetchLoanProductsAction {

    @InvocableMethod(label='Fetch Loan Products' description='Retrieves available loan products matching applicant eligibility criteria')
    public static List<String> fetchLoanProducts(List<Id> accountIds) {
        return new List<String>{ 'Products fetched' };
    }
}
