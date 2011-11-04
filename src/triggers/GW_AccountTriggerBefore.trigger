// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_AccountTriggerBefore on Account (before delete, before insert, before update) {

    // prevent deletions, renames, or duplicates for the Individual Account
    if (GW_TriggerSettings.ts.Enable_Individual_Account__c) {
    	ONEN_DefaultAccount defAcct = new ONEN_DefaultAccount();
        defAcct.ProtectIndividualAccount();
    }
    
    /* deprecated
    if (trigger.isInsert || trigger.isUpdate) {
        
        // set all fields on the account we can derive from zip.
        if (GW_TriggerSettings.ts.Enable_Zip_Lookup__c) {
            ONEN_ZipLookup.AccountZipLookup(trigger.new);
        }
    }
    */
}