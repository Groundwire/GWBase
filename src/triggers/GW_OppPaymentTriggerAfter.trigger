// Written by Dave Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_OppPaymentTriggerAfter on OppPayment__c (after delete, after undelete, after update, after insert) {

    // when deleting payments, see if they are all deleted and a mirror needs to be created.
    if (trigger.isDelete && GW_TriggerSettings.ts.Enable_Opportunity_Mirror_Payments__c) {
        ONEN_OpportunityInstallments.ConvertDeletedInstallmentsToMirror(trigger.old);
    }

	// when changing payments in any way, recalculate amount on opp 
	// also set the opp stage to closed if full amount is paid
    if (GW_TriggerSettings.ts.Enable_Payment_Amount_Sync__c) {
        ONEN_OpportunityInstallments.SyncTotalPaymentAmount(trigger.new, trigger.oldmap, (trigger.IsInsert || trigger.isUnDelete), trigger.isUpdate);
    }

    // when inserting installments, delete any remaining mirror payment
    if (trigger.isInsert && GW_TriggerSettings.ts.Enable_Opportunity_Mirror_Payments__c) {
        ONEN_OpportunityInstallments.DeleteMirrors(trigger.new);
    }

}