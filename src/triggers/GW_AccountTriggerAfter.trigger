// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_AccountTriggerAfter on Account (after delete, after update) {

	if (trigger.isDelete) {
		// delete any interaccount relationships
		if (GW_TriggerSettings.ts.Enable_InterAccount_Relationships__c) {
			GW_InterAccountRelationships.DeleteInterAccountRelationships(trigger.old);
		}
	}
	
	if (trigger.isUpdate) {
		// update the primary contact for the account
		if (GW_TriggerSettings.ts.Enable_Primary_Contact_On_Accounts__c) {
			ONEN_AccountMaintenance am = new ONEN_AccountMaintenance();
			am.SetPrimaryContactForAccounts(trigger.New, trigger.Old);
		}		
	}
	
	
}