// Written by Evan Callahan, copyright (c) 2008 NPower Seattle
// refactored by Steve Andersen, 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_InterAccountRelationshipTriggerAfter on Interaccount_Relationship__c (after delete, after insert, after undelete, after update) {
	
	if (!GW_TriggerSettings.ts.Enable_InterAccount_Relationships__c) {
		return;
	}
	
	//intantiate our relationships class
	GW_InterAccountRelationships relationships = new GW_InterAccountRelationships();

	for (Interaccount_Relationship__c accountRelationship : Trigger.isInsert ? Trigger.new : Trigger.old) {
		if (Trigger.isInsert) {
			//collect these in a list
			if(accountRelationship.Mirror_Relationship__c==null) {
				relationships.accountRelsInsertedToMirror.put(accountRelationship.Id,accountRelationship);
			}
		} else if (trigger.isUpdate){
			Interaccount_Relationship__c newaccountRelationship = trigger.newmap.get (accountRelationship.id);
			//collect in a list
			//if there are substantive changes. We can get in a loop because the insert trigger will cause an update
			//if the records aren't changing at all, we don't update
			if((accountRelationship.Mirror_Relationship__c!=newaccountRelationship.Mirror_Relationship__c)||
				(accountRelationship.relationship__c!=newaccountRelationship.relationship__c)||
				(accountRelationship.Reciprocal_Relationship__c!=newaccountRelationship.Reciprocal_Relationship__c)||
				(accountRelationship.To_Date__c!=newaccountRelationship.To_Date__c)||
				(accountRelationship.From_Date__c!=newaccountRelationship.From_Date__c)||
				(accountRelationship.Notes__c!=newaccountRelationship.Notes__c)
				) {
				relationships.accountRelUpdateMap.put(newaccountRelationship.Mirror_Relationship__c,newaccountRelationship);
			}
		} else if (Trigger.isDelete){
			//collect related id in a list for deleting
			relationships.accountRelIdsToDelete.add(accountRelationship.Mirror_Relationship__c);
		} else if (Trigger.isUndelete) {
			//what to do with undeletes?			
		}
	}

	if (relationships.accountRelIdsToDelete.size()>0) {
		relationships.deleteAccountRelationships();
	}
	
	if (relationships.accountRelUpdateMap.size()>0) {
		relationships.updateChangingAccountRelationships();
	}

	if (relationships.accountRelsInsertedToMirror.size()>0) {
		relationships.processNewAccountRelationships();		
	}
}