/**
 * Base class for all trigger handlers.
 *
 * - One trigger per object; the trigger only calls `new XHandler().run()`.
 * - Handlers can be switched off without a deployment through the
 *   Trigger_Setting__mdt custom metadata type.
 * - Handlers can be bypassed programmatically (for data loads or tests).
 * - A per-transaction recursion guard stops a handler re-running for the
 *   same context more than `maxLoops` times.
 */
public virtual inherited sharing class TriggerHandler {
    private static final Set<String> BYPASSED = new Set<String>();
    private static final Map<String, Integer> LOOP_COUNTS = new Map<String, Integer>();

    @TestVisible
    private static Map<String, Trigger_Setting__mdt> settingsOverride;

    @TestVisible
    private System.TriggerOperation context;
    private Integer maxLoops = 3;

    public TriggerHandler() {
        this.context = Trigger.operationType;
    }

    public void run() {
        if (!shouldRun()) {
            return;
        }
        incrementLoopCount();

        switch on context {
            when BEFORE_INSERT {
                beforeInsert(Trigger.new);
            }
            when BEFORE_UPDATE {
                beforeUpdate(Trigger.new, Trigger.oldMap);
            }
            when BEFORE_DELETE {
                beforeDelete(Trigger.oldMap);
            }
            when AFTER_INSERT {
                afterInsert(Trigger.newMap);
            }
            when AFTER_UPDATE {
                afterUpdate(Trigger.newMap, Trigger.oldMap);
            }
            when AFTER_DELETE {
                afterDelete(Trigger.oldMap);
            }
            when AFTER_UNDELETE {
                afterUndelete(Trigger.newMap);
            }
        }
    }

    // ---- Overridable context methods -------------------------------------
    protected virtual void beforeInsert(List<SObject> newRecords) {
    }
    protected virtual void beforeUpdate(List<SObject> newRecords, Map<Id, SObject> oldMap) {
    }
    protected virtual void beforeDelete(Map<Id, SObject> oldMap) {
    }
    protected virtual void afterInsert(Map<Id, SObject> newMap) {
    }
    protected virtual void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
    }
    protected virtual void afterDelete(Map<Id, SObject> oldMap) {
    }
    protected virtual void afterUndelete(Map<Id, SObject> newMap) {
    }

    // ---- Bypass API --------------------------------------------------------
    public static void bypass(String handlerName) {
        BYPASSED.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        BYPASSED.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return BYPASSED.contains(handlerName);
    }

    protected void setMaxLoops(Integer maxLoops) {
        this.maxLoops = maxLoops;
    }

    // ---- Internals ---------------------------------------------------------
    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }

    @TestVisible
    private Boolean shouldRun() {
        if (context == null) {
            // Not executing inside a trigger (for example, called from a test).
            return false;
        }
        String name = getHandlerName();
        if (isBypassed(name) || !isEnabledInMetadata(name)) {
            return false;
        }
        Integer count = LOOP_COUNTS.get(name + context);
        return count == null || count < maxLoops;
    }

    private void incrementLoopCount() {
        String key = getHandlerName() + context;
        Integer count = LOOP_COUNTS.get(key);
        LOOP_COUNTS.put(key, count == null ? 1 : count + 1);
    }

    private static Boolean isEnabledInMetadata(String handlerName) {
        Map<String, Trigger_Setting__mdt> settings = settingsOverride != null
            ? settingsOverride
            : Trigger_Setting__mdt.getAll();
        for (Trigger_Setting__mdt setting : settings.values()) {
            if (setting.Handler_Name__c == handlerName) {
                return setting.Active__c;
            }
        }
        // No record means enabled by default.
        return true;
    }
}
