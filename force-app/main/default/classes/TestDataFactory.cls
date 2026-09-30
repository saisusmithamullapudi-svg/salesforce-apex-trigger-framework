/**
 * Synthetic test data. No real customer, client or production data is used.
 */
@IsTest
public class TestDataFactory {
    public static List<Account> createAccounts(Integer count, String tier) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Test Homeowner ' + tier + ' ' + i, Customer_Tier__c = tier));
        }
        insert accounts;
        return accounts;
    }

    public static List<Case> buildCases(List<Account> accounts, Integer perAccount) {
        List<Case> cases = new List<Case>();
        for (Account acct : accounts) {
            for (Integer i = 0; i < perAccount; i++) {
                cases.add(
                    new Case(AccountId = acct.Id, Subject = 'Inverter fault ' + i, Status = 'New', Origin = 'Web')
                );
            }
        }
        return cases;
    }
}
