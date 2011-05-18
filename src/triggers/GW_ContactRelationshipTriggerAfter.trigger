// Written by Evan Callahan, copyright (c) 2008 NPower Seattle
// refactored by Steve Andersen, 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
trigger GW_ContactRelationshipTriggerAfter on Contact_Relationship__c (after delete, after insert, after undelete, after update) {

	if (!GW_TriggerSettings.ts.Enable_Contact_Relationships__c) {
		return;
	}
	
	//intantiate our relationships class
	ONEN_ContactRelationships relationships = new ONEN_ContactRelationships();

	for (Contact_Relationship__c crel : Trigger.isInsert ? Trigger.new : Trigger.old) {
		if (Trigger.isInsert) {
			//collect these in a list
			if(crel.Mirror_Relationship__c==null) {
				relationships.contactRelsInsertedToMirror.put(crel.Id,crel);
			}
		} else if (trigger.isUpdate){
			Contact_Relationship__c newcrel = trigger.newmap.get (crel.id);
			//collect in a list
			//if there are substantive changes. We can get in a loop because the insert trigger will cause an update
			//if the records aren't changing at all, we don't update
			if((crel.Mirror_Relationship__c!=newcrel.Mirror_Relationship__c)||
				(crel.relationship__c!=newcrel.relationship__c)||
				(crel.Reciprocal_Relationship__c!=newcrel.Reciprocal_Relationship__c)||
				(crel.To_Date__c!=newcrel.To_Date__c)||
				(crel.From_Date__c!=newcrel.From_Date__c)||
				(crel.Notes__c!=newcrel.Notes__c)
				) {
				relationships.contactRelUpdateMap.put(newcrel.Mirror_Relationship__c,newcrel);
			}
		} else if (Trigger.isDelete){
			//collect related id in a list for deleting
			relationships.contactRelIdsToDelete.add(crel.Mirror_Relationship__c);
		} else if (Trigger.isUndelete) {
			//what to do with undeletes?
		}
	}

	if (relationships.contactRelIdsToDelete.size()>0) {
		relationships.deleteContactRelationships();
	}
	
	if (relationships.contactRelUpdateMap.size()>0) {
		relationships.updateChangingContactRelationships();
	}

	if (relationships.contactRelsInsertedToMirror.size()>0) {
		relationships.processNewContactRelationships();		
	}
}