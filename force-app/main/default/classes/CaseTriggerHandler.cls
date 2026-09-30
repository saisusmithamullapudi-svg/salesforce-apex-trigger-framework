/**
 * Case trigger logic for a synthetic field-service support desk.
 *
 * before insert : for self-service (Web/Portal) cases, derive Priority from the parent
 *                 Account's Customer_Tier__c; agent-created cases keep the agent's choice
 * after insert  : queue escalation work for High-priority cases
 * after insert/update/delete/undelete : keep Account.Open_Case_Count__c current
 */
public with sharing class CaseTriggerHandler extends TriggerHandler {
    @TestVisible
    private static final Map<String, String> PRIORITY_BY_TIER = new Map<String, String>{
        'Platinum' => 'High',
        'Gold' => 'Medium',
        'Standard' => 'Low'
    };

    @TestVisible
    private static final Set<String> SELF_SERVICE_ORIGINS = new Set<String>{ 'Web', 'Portal' };

    protected override void beforeInsert(List<SObject> newRecords) {
        List<Case> cases = (List<Case>) newRecords;
        Set<Id> accountIds = new Set<Id>();
        for (Case c : cases) {
            if (c.AccountId != null && isSelfService(c)) {
                accountIds.add(c.AccountId);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accounts = new Map<Id, Account>(
            [SELECT Id, Customer_Tier__c FROM Account WHERE Id IN :accountIds WITH USER_MODE]
        );
        for (Case c : cases) {
            Account acct = accounts.get(c.AccountId);
            if (acct != null && isSelfService(c)) {
                c.Priority = PRIORITY_BY_TIER.containsKey(acct.Customer_Tier__c)
                    ? PRIORITY_BY_TIER.get(acct.Customer_Tier__c)
                    : 'Low';
            }
        }
    }

    protected override void afterInsert(Map<Id, SObject> newMap) {
        Set<Id> highPriority = new Set<Id>();
        for (Case c : (List<Case>) newMap.values()) {
            if (c.Priority == 'High') {
                highPriority.add(c.Id);
            }
        }
        if (!highPriority.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new CaseEscalationQueueable(highPriority));
        }
        AccountCaseRollup.recalculate(accountIdsOf(newMap.values()));
    }

    protected override void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        Set<Id> changed = new Set<Id>();
        for (Case c : (List<Case>) newMap.values()) {
            Case old = (Case) oldMap.get(c.Id);
            if (c.IsClosed != old.IsClosed || c.AccountId != old.AccountId) {
                if (c.AccountId != null) {
                    changed.add(c.AccountId);
                }
                if (old.AccountId != null) {
                    changed.add(old.AccountId);
                }
            }
        }
        AccountCaseRollup.recalculate(changed);
    }

    protected override void afterDelete(Map<Id, SObject> oldMap) {
        AccountCaseRollup.recalculate(accountIdsOf(oldMap.values()));
    }

    protected override void afterUndelete(Map<Id, SObject> newMap) {
        AccountCaseRollup.recalculate(accountIdsOf(newMap.values()));
    }

    @TestVisible
    private static Boolean isSelfService(Case c) {
        return SELF_SERVICE_ORIGINS.contains(c.Origin);
    }

    private static Set<Id> accountIdsOf(List<SObject> records) {
        Set<Id> ids = new Set<Id>();
        for (Case c : (List<Case>) records) {
            if (c.AccountId != null) {
                ids.add(c.AccountId);
            }
        }
        return ids;
    }
}
