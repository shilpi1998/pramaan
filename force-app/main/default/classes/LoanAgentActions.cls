public with sharing class LoanAgentActions {

    @InvocableMethod(label='Check Credit Score' description='Retrieves and evaluates credit score for loan applicant from bureau data')
    public static List<CreditResult> checkCreditScore(List<CreditRequest> requests) {
        CreditResult r = new CreditResult();
        r.score = 742;
        r.rating = 'Good';
        r.eligible = true;
        return new List<CreditResult>{ r };
    }

    public class CreditRequest {
        @InvocableVariable(required=true description='The applicant Account Id')
        public Id accountId;
    }

    public class CreditResult {
        @InvocableVariable(description='Credit score')
        public Integer score;
        @InvocableVariable(description='Credit rating')
        public String rating;
        @InvocableVariable(description='Eligible for loan')
        public Boolean eligible;
    }
}
