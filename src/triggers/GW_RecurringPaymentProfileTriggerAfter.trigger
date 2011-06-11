// Written by David Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_RecurringPaymentProfileTriggerAfter on Recurring_Payment_Profile__c (after update) {
    
    // if EndDate changes, we may have Opportunities to close.
    if (GW_TriggerSettings.ts.Enable_RPP_Opportunity_Closing__c) {
        GW_RecurringPayments.HandleEndDateChange(trigger.new, trigger.old);
    }
}