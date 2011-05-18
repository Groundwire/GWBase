// Written by Dave Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_LeadTriggerAfter on Lead (after insert) {

	if (GW_TriggerSettings.ts.Enable_Lead_Add_To_Campaign__c) {
		GW_LeadMaintenance.NewLeadAddToCampaign(trigger.New);
	}
	
}