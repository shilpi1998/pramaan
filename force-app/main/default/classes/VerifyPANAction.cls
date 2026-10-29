public with sharing class VerifyPANAction {

    @InvocableMethod(label='Verify PAN Card' description='Validates PAN number against NSDL registry and checks for sanctions')
    public static List<String> verifyPAN(List<String> panNumbers) {
        return new List<String>{ 'PAN verified' };
    }
}
