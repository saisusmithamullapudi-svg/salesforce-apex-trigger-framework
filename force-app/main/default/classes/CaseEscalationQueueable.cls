/**
 * Asynchronous escalation for High-priority cases: routes them to the
 * escalation queue and records a follow-up task for the account owner.
 * Runs as a Queueable so the originating transaction stays fast and
 * the work can be chained or retried independently.
 */
public with sharing class CaseEscalationQueueable implements Queueable {
    @TestVisible
    private static final String ESCALATION_QUEUE = 'Escalations';

    private final Set<Id> caseIds;

    public CaseEscalationQueueable(Set<Id> caseIds) {
        this.caseIds = caseIds;
    }

    public void execute(QueueableContext context) {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName = :ESCALATION_QUEUE
            LIMIT 1
        ];

        List<Case> cases = [
            SELECT Id, CaseNumber, OwnerId, AccountId, Account.OwnerId
            FROM Case
            WHERE Id IN :caseIds AND IsClosed = FALSE
            WITH USER_MODE
        ];

        List<Task> followUps = new List<Task>();
        for (Case c : cases) {
            if (!queues.isEmpty()) {
                c.OwnerId = queues[0].Id;
            }
            if (c.AccountId != null) {
                followUps.add(
                    new Task(
                        WhatId = c.Id,
                        OwnerId = c.Account.OwnerId,
                        Subject = 'High-priority case ' + c.CaseNumber + ' escalated',
                        ActivityDate = Date.today().addDays(1),
                        Priority = 'High'
                    )
                );
            }
        }

        Logger.logSaveErrors('CaseEscalationQueueable.cases', Database.update(cases, false, AccessLevel.USER_MODE));
        Logger.logSaveErrors('CaseEscalationQueueable.tasks', Database.insert(followUps, false, AccessLevel.USER_MODE));
    }
}
