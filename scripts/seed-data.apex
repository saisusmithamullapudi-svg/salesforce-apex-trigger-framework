// Synthetic demo data only. Run with:
//   sf apex run --file scripts/seed-data.apex
List<Account> accounts = new List<Account>();
List<String> tiers = new List<String>{ 'Platinum', 'Gold', 'Standard' };
for (Integer i = 0; i < 30; i++) {
    accounts.add(new Account(Name = 'Demo Homeowner ' + i, Customer_Tier__c = tiers[Math.mod(i, 3)]));
}
insert accounts;

List<Case> cases = new List<Case>();
for (Account acct : accounts) {
    cases.add(new Case(AccountId = acct.Id, Subject = 'Panel output lower than expected', Origin = 'Web', Status = 'New'));
    cases.add(new Case(AccountId = acct.Id, Subject = 'Reschedule inspection', Origin = 'Phone', Status = 'New', Priority = 'Low'));
}
insert cases;
System.debug('Seeded ' + accounts.size() + ' accounts and ' + cases.size() + ' cases');
