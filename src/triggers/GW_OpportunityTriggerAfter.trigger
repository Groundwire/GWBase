// Written by employees of Groundwire, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_OpportunityTriggerAfter on Opportunity (after delete, after insert, after undelete, after update) {

	// check for the contact roles
	if (Trigger.isInsert && GW_TriggerSettings.ts.Enable_Opportunity_Contact_Roles__c) {
		ONEN_OpportunityContactRoles.CheckContactRoles(trigger.new);
	} 
		
	// add primary contact on an opp to its campaign
	if ((Trigger.IsInsert || Trigger.IsUpdate) && GW_TriggerSettings.ts.Enable_Opportunity_Add_To_Campaign__c) {
		GW_OpportunityAddToCampaign.AddToCampaign(trigger.new, trigger.oldMap);
	}

	// create the opps' mirror payments
	if (Trigger.IsInsert && GW_TriggerSettings.ts.Enable_Opportunity_Mirror_Payments__c) {
		ONEN_OpportunityInstallments.CreateMirrorPayments(trigger.new);
	}
		
	if (Trigger.IsUpdate) {
		// update mirror payments 
		if (GW_TriggerSettings.ts.Enable_Opportunity_Mirror_Payments__c) {
			ONEN_OpportunityInstallments.CheckMirrorPayments(trigger.new, trigger.oldMap);
		}
		
		// handle the primary contact being changed for the opp.
    	if (ONEN_OpportunityContactRoles.runPrimaryContactRoleSync) {
	    	ONEN_OpportunityContactRoles.updatePrimaryOppContactRole(Trigger.oldMap, Trigger.newMap);
    	}	
	} 
		
	// if the last Recurring opportunity is completed, create more if the RecurringPaymentProfile is still active.
	if ((Trigger.IsUpdate || Trigger.IsInsert) && GW_TriggerSettings.ts.Enable_Opportunity_Recurring_Creation__c) {
		GW_RecurringPayments.CreateRecurringOppsIfNeeded(trigger.new, trigger.old);		
	}	

	// handle opportunity rollups in all scenarios
	if (GW_TriggerSettings.ts.Enable_Opportunity_Rollups__c) {
		GW_OppRollups rg = new GW_OppRollups();
		rg.rollupForOppTrigger(trigger.newMap, trigger.oldMap);
	}  
				
}