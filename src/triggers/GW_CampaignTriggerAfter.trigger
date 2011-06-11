// Written by Steve Andersen, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
    
trigger GW_CampaignTriggerAfter on Campaign (after insert) {
    
    if (GW_TriggerSettings.ts.Enable_Default_Campaign_Member_Statuses__c) {
        ONEN_CampaignMemberStatus.addDefaultStatuses (trigger.new);
    } 
}