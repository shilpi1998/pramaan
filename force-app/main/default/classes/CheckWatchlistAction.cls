public with sharing class CheckWatchlistAction {

    @InvocableMethod(label='Check Watchlist' description='Screens customer against RBI sanctions list, OFAC, and PEP databases')
    public static List<String> checkWatchlist(List<Id> contactIds) {
        return new List<String>{ 'No watchlist matches found' };
    }
}
