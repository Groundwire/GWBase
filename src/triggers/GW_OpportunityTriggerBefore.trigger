// Written by Dave Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

trigger GW_OpportunityTriggerBefore on Opportunity (before insert, before update) {
	
	// create a name for any opps without.
	if (Trigger.IsInsert && GW_TriggerSettings.ts.Enable_Opportunity_AutoName__c) {
		ONEN_OpportunityMaintenance.OpportunityAutoName(trigger.New);
	}
	
}