// Written by Michael Paulsmeyer, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_CampaignTriggerBefore on Campaign (before insert) {

    for (Campaign c : Trigger.new) {
        
        //Set Campaign active checkbox to true
        if (GW_TriggerSettings.ts.Enable_Active_Campaign__c) {
            c.IsActive = true; 
        }
    }
}