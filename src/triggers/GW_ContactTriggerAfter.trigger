// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// Refactored by David Habib, 2011 Groundwire.
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_ContactTriggerAfter on Contact (after delete, after insert, after update, after undelete) {

    // fixup potential second contact's household
    if (GW_TriggerSettings.ts.Enable_Households__c) {
        GW_Householding.ContactManageHouseholdAfterTrigger();
    }

    // update primary contact for all the accounts that were changed (currently doesn't handle undelete)
    if (GW_TriggerSettings.ts.Enable_Primary_Contact_On_Accounts__c && !trigger.isUnDelete) {
        ONEN_AccountMaintenance am = new ONEN_AccountMaintenance();     
        am.SetPrimaryContacts(trigger.New, trigger.Old, trigger.isInsert, trigger.isDelete);
    }

    if (trigger.isDelete) {
        // delete appropriate relationships
        if (GW_TriggerSettings.ts.Enable_Contact_Relationships__c) {
            ONEN_ContactRelationships.DeleteOrphanedRelationships(trigger.old);
        }
    }
}