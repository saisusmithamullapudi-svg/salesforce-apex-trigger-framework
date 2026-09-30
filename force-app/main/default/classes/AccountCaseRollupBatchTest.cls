@IsTest
private class AccountCaseRollupBatchTest {
    @IsTest
    static void correctsDriftForAllAccounts() {
        List<Account> accounts = TestDataFactory.createAccounts(5, 'Standard');
        TriggerHandler.bypass('CaseTriggerHandler'); // simulate a bulk load with triggers off
        insert TestDataFactory.buildCases(accounts, 3);
        TriggerHandler.clearBypass('CaseTriggerHandler');

        AccountCaseRollupBatch job = new AccountCaseRollupBatch();
        Test.startTest();
        Database.executeBatch(job, 200);
        Test.stopTest();

        for (Account acct : [SELECT Open_Case_Count__c FROM Account]) {
            Assert.areEqual(3, acct.Open_Case_Count__c, 'Batch should restore the correct count');
        }
    }

    @IsTest
    static void schedulesTheBatch() {
        Test.startTest();
        String jobId = System.schedule('Case rollup test', '0 0 2 * * ?', new AccountCaseRollupBatch());
        Test.stopTest();

        Assert.isNotNull(jobId);
    }

    @IsTest
    static void loggerRecordsSaveErrors() {
        // Blanking a required field fails the row without throwing (allOrNone = false).
        Account acct = TestDataFactory.createAccounts(1, 'Standard')[0];
        acct.Name = null;
        List<Database.SaveResult> results = Database.update(new List<Account>{ acct }, false);
        Integer failures = Logger.logSaveErrors('test', results);

        Assert.areEqual(1, failures);
        Assert.isFalse(Logger.BUFFER.isEmpty());
    }
}
