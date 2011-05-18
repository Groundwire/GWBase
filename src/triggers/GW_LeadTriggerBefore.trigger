// Written by Dave Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_LeadTriggerBefore on Lead (before insert, before update) {
	
	if (GW_TriggerSettings.ts.Enable_Lead_Smart_Fields__c) {
		GW_LeadMaintenance.LeadFieldFixups(trigger.New, trigger.isInsert);
	}
	
}