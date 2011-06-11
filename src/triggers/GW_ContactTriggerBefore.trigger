// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// Refactored by David Habib, 2011 Groundwire.
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_ContactTriggerBefore on Contact (before insert, before update) {
         
    // assign them to the bucket account if they don't have one specified.
    if (GW_TriggerSettings.ts.Enable_Individual_Account__c) {
        ONEN_DefaultAccount.SetIndividualAccount();
    }
    
    // set empty fields we can derive from zip.
    if (GW_TriggerSettings.ts.Enable_Zip_Lookup__c) {
        ONEN_ZipLookup.ContactZipLookup();
    }
    
    // set various field values (that used to be handled by workflow rules)
    if (GW_TriggerSettings.ts.Enable_Contact_Smart_Fields__c) {
        GW_ContactMaintenance.UpdateContactFieldsBeforeTrigger();
    }

    // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
    if (GW_TriggerSettings.ts.Enable_Engagement_Tracker__c) {
        GW_BATCH_EngagementRollup.ContactEngagementLvlOverride();
    }
    
    // fixup the contact's household due to name changes, etc.
    if (GW_TriggerSettings.ts.Enable_Households__c) {
        GW_Householding.ContactManageHouseholdBeforeTrigger();
    }
}