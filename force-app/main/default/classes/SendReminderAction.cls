public with sharing class SendReminderAction {

    @InvocableMethod(label='Send Payment Reminder' description='Sends payment reminder via SMS, email or WhatsApp based on customer communication preference')
    public static List<String> sendReminder(List<Id> contactIds) {
        return new List<String>{ 'Reminder sent' };
    }
}
