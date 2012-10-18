// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// Refactored by David Habib & Nicolas Campbell, 2011 Groundwire.
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_ContactTriggerAfter on Contact (after delete, after insert, after update, after undelete) {

    // fixup potential second contact's household
    if (GW_TriggerSettings.ts.Enable_Households__c) {
        GW_Householding.ContactManageHouseholdAfterTrigger();
    }

    // update primary contact for all the accounts that were changed (currently doesn't handle undelete)
    if (GW_TriggerSettings.ts.Enable_Primary_Contact_On_Accounts__c) {
        ONEN_AccountMaintenance am = new ONEN_AccountMaintenance();     
        am.SetPrimaryContacts(trigger.New, trigger.Old, (trigger.isInsert || trigger.isUndelete), trigger.isDelete);
    }

	if (GW_TriggerSettings.ts.Enable_Contact_Add_To_Campaign__c && trigger.isInsert) {
		GW_ContactMaintenance.NewContactAddToCampaign(trigger.new);
	}

    if (trigger.isDelete) {
        // delete appropriate relationships
        if (GW_TriggerSettings.ts.Enable_Contact_Relationships__c) {
            ONEN_ContactRelationships.DeleteOrphanedRelationships(trigger.old);
        }
		
		// if dupeblocker is installed, send deleted contact's recently modified opps to reset membership dates
		/*if (GW_TriggerSettings.ts.Enable_Auto_Membership_Dates__c){// && GW_Utilities.IsDupBlockerInstalled) {
			
			set<id> mergeWinner = new set<id>();
			for (Contact c : trigger.old) if (c.masterRecordId!=null) mergeWinner.add(c.masterRecordId);
			
			if (!mergeWinner.isEmpty()) {
				datetime oneminuteago = datetime.now().addMinutes(-1);
				list<Opportunity> mergeOpps = [ SELECT id, RecordTypeId, ContactId__c, AccountId, CloseDate, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c 
												FROM Opportunity WHERE ContactId__c IN :mergeWinner AND SystemModstamp > :oneminuteago AND CreatedDate > :oneminuteago];
				if (mergeOpps.size() > 0) {
					GW_AutoMemberDates amd = new GW_AutoMemberDates();
					amd.mergeDates(mergeOpps);						
				}

			}

		}*/

    }

}