// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_HouseholdTriggerBefore on ONEN_Household__c (before delete, before update) {
    
    if (!GW_TriggerSettings.ts.Enable_Households__c) {
        return;
    }
    
    if (trigger.isUpdate) {
        // when the household changes, the naming might need to be redone.
        GW_Householding.FixNaming();
    }
    
    /*if (trigger.isDelete) {
        // prevent user from deleting households unless they are already empty
        GW_Householding.PreventDeletion();      
    }*/

}