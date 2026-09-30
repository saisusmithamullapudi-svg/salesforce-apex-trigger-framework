/**
 * Nightly full recalculation of Account.Open_Case_Count__c.
 * Corrects any drift caused by bypassed triggers or bulk data loads.
 *
 * Schedule:  System.schedule('Nightly case rollup', '0 0 2 * * ?', new AccountCaseRollupBatch());
 * Run now:   Database.executeBatch(new AccountCaseRollupBatch(), 200);
 */
public with sharing class AccountCaseRollupBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    @TestVisible
    private Integer accountsProcessed = 0;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM Account WITH USER_MODE]);
    }

    public void execute(Database.BatchableContext context, List<Account> scope) {
        AccountCaseRollup.recalculate(new Map<Id, Account>(scope).keySet());
        accountsProcessed += scope.size();
    }

    public void finish(Database.BatchableContext context) {
        Logger.info('AccountCaseRollupBatch', 'Processed ' + accountsProcessed + ' accounts');
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new AccountCaseRollupBatch(), 200);
    }
}
