// Written by Dave Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_OppPaymentTriggerAfter on OppPayment__c (after delete) {

	// when deleting payments, see if they are all deleted and a mirror needs to be created.
	if (GW_TriggerSettings.ts.Enable_Opportunity_Mirror_Payments__c) {
		ONEN_OpportunityInstallments.ConvertDeletedInstallmentsToMirror(trigger.old);
	}
}