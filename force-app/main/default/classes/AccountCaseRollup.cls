/**
 * Recalculates Account.Open_Case_Count__c with one aggregate query per call.
 * Used synchronously by the Case trigger and in bulk by AccountCaseRollupBatch.
 */
public with sharing class AccountCaseRollup {
    public static void recalculate(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (Id accountId : accountIds) {
            counts.put(accountId, 0);
        }
        for (AggregateResult row : [
            SELECT AccountId accountId, COUNT(Id) openCases
            FROM Case
            WHERE AccountId IN :accountIds AND IsClosed = FALSE
            WITH USER_MODE
            GROUP BY AccountId
        ]) {
            counts.put((Id) row.get('accountId'), (Integer) row.get('openCases'));
        }

        List<Account> updates = new List<Account>();
        for (Id accountId : counts.keySet()) {
            updates.add(new Account(Id = accountId, Open_Case_Count__c = counts.get(accountId)));
        }

        List<Database.SaveResult> results = Database.update(updates, false, AccessLevel.USER_MODE);
        Logger.logSaveErrors('AccountCaseRollup', results);
    }
}
