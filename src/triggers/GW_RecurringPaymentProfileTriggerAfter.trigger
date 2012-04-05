// Written by David Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_RecurringPaymentProfileTriggerAfter on Recurring_Payment_Profile__c (after update,after insert,after delete) {
    
    // if EndDate changes, we may have Opportunities to close.
    if (trigger.isUpdate && GW_TriggerSettings.ts.Enable_RPP_Opportunity_Closing__c) {
        GW_RecurringPayments.HandleEndDateChange(trigger.new, trigger.old);
    }
    
    // on any update or insert, rollup recurring totals to contact
    if (GW_TriggerSettings.ts.Enable_Recurring_Rollup_Triggers__c) {
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupForRecurringTrigger(trigger.newMap, trigger.oldMap);
    }
}