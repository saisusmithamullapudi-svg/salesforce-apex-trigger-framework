@IsTest
private class CaseTriggerHandlerTest {
    @IsTest
    static void derivesPriorityFromCustomerTier() {
        List<Account> platinum = TestDataFactory.createAccounts(1, 'Platinum');
        List<Account> standard = TestDataFactory.createAccounts(1, 'Standard');

        List<Case> cases = TestDataFactory.buildCases(platinum, 1);
        cases.addAll(TestDataFactory.buildCases(standard, 1));

        Test.startTest();
        insert cases;
        Test.stopTest();

        Map<Id, String> priorityByAccount = new Map<Id, String>();
        for (Case c : [SELECT AccountId, Priority FROM Case]) {
            priorityByAccount.put(c.AccountId, c.Priority);
        }
        Assert.areEqual('High', priorityByAccount.get(platinum[0].Id), 'Platinum accounts should get High priority');
        Assert.areEqual('Low', priorityByAccount.get(standard[0].Id), 'Standard accounts should get Low priority');
    }

    @IsTest
    static void keepsAgentPriorityForPhoneCases() {
        List<Account> platinum = TestDataFactory.createAccounts(1, 'Platinum');
        Case c = TestDataFactory.buildCases(platinum, 1)[0];
        c.Origin = 'Phone';
        c.Priority = 'Low';

        insert c;

        Assert.areEqual(
            'Low',
            [SELECT Priority FROM Case WHERE Id = :c.Id].Priority,
            'Agent-entered priority must not be overwritten'
        );
    }

    @IsTest
    static void escalatesHighPriorityCasesAsynchronously() {
        List<Account> platinum = TestDataFactory.createAccounts(1, 'Platinum');

        Test.startTest();
        insert TestDataFactory.buildCases(platinum, 2);
        Test.stopTest();

        Assert.areEqual(
            2,
            [SELECT COUNT() FROM Task WHERE Priority = 'High'],
            'A follow-up task should be created per escalated case'
        );
    }

    @IsTest
    static void maintainsOpenCaseCountInBulk() {
        List<Account> accounts = TestDataFactory.createAccounts(20, 'Gold');
        List<Case> cases = TestDataFactory.buildCases(accounts, 10); // 200 records, one trigger chunk

        Test.startTest();
        insert cases;
        Test.stopTest();

        for (Account acct : [SELECT Open_Case_Count__c FROM Account WHERE Id IN :accounts]) {
            Assert.areEqual(10, acct.Open_Case_Count__c, 'Each account should show 10 open cases');
        }

        Case first = [SELECT Id, AccountId FROM Case LIMIT 1];
        first.Status = 'Closed';
        update first;
        Assert.areEqual(9, [SELECT Open_Case_Count__c FROM Account WHERE Id = :first.AccountId].Open_Case_Count__c);

        delete [SELECT Id FROM Case WHERE AccountId = :first.AccountId AND IsClosed = FALSE LIMIT 4];
        Assert.areEqual(5, [SELECT Open_Case_Count__c FROM Account WHERE Id = :first.AccountId].Open_Case_Count__c);
    }

    @IsTest
    static void bypassSkipsHandler() {
        List<Account> platinum = TestDataFactory.createAccounts(1, 'Platinum');
        TriggerHandler.bypass('CaseTriggerHandler');

        insert TestDataFactory.buildCases(platinum, 1);

        Case inserted = [SELECT Priority FROM Case LIMIT 1];
        Assert.areNotEqual('High', inserted.Priority, 'Handler logic should not run while bypassed');
        TriggerHandler.clearBypass('CaseTriggerHandler');
        Assert.isFalse(TriggerHandler.isBypassed('CaseTriggerHandler'));
    }

    @IsTest
    static void metadataCanDisableHandler() {
        TriggerHandler.settingsOverride = new Map<String, Trigger_Setting__mdt>{
            'Case' => new Trigger_Setting__mdt(Handler_Name__c = 'CaseTriggerHandler', Active__c = false)
        };
        List<Account> platinum = TestDataFactory.createAccounts(1, 'Platinum');

        insert TestDataFactory.buildCases(platinum, 1);

        Assert.areNotEqual(
            'High',
            [SELECT Priority FROM Case LIMIT 1].Priority,
            'Disabled handler should not set priority'
        );
    }
}
