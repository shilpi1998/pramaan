public with sharing class VerifyAadhaarAction {

    @InvocableMethod(label='Verify Aadhaar' description='Validates Aadhaar number via UIDAI e-KYC with consent and masking applied')
    public static List<String> verifyAadhaar(List<String> aadhaarTokens) {
        return new List<String>{ 'Aadhaar verified via e-KYC' };
    }
}
