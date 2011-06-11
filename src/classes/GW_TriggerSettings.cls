// Written by David Habib, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author David Habib
* @date 01/01/2011
* @description Class which sets default trigger settings. Avoids conflicts with DupBlocker and test 
* classes.
*/

global class GW_TriggerSettings {
	
	private static void SetTriggerSettingDefaults(TriggerSettings__c ts) {
		// must explicitly set the default values.  (doing new Obj doesn't use defaults!)
		ts.Enable_Active_Campaign__c = true;
		ts.Enable_Contact_Relationships__c = true;
		ts.Enable_Contact_Smart_Fields__c = true;
		ts.Enable_Default_Campaign_Member_Statuses__c = true;
		ts.Enable_Engagement_Tracker__c = true;
		ts.Enable_Households__c = true;
		ts.Enable_Individual_Account__c = true;
		ts.Enable_InterAccount_Relationships__c = true;
		ts.Enable_Lead_Add_To_Campaign__c = true;
		ts.Enable_Lead_Smart_Fields__c = true;
		ts.Enable_Opportunity_Add_To_Campaign__c = true;
		ts.Enable_Opportunity_AutoName__c = true;
		ts.Enable_Opportunity_Contact_Roles__c = true;
		ts.Enable_Opportunity_Mirror_Payments__c = true;
		ts.Enable_Opportunity_Rollups__c = true;
		ts.Enable_Zip_Lookup__c = true;		
		ts.Enable_Opportunity_Recurring_Creation__c = true;
		ts.Enable_RPP_Opportunity_Closing__c = true;
		
		// if DupBlocker is in this instance, we can't allow our code to do this.
		// the client code must handle this to avoid DupBlocker issues.
		ts.Enable_Primary_Contact_On_Accounts__c = !GW_Utilities.IsDupBlockerInstalled;
	}

	/*******************************************************************************************************
	* @description Sets trigger settings.
	*/	
	global static TriggerSettings__c ts {
		get {			
			if (ts == null) {
				// special case only loading the real settings if we aren't testing!
				// our test code assumes our triggers are always on.
				if (!System.Test.isRunningTest()) {
					ts = TriggerSettings__c.getInstance();
				}
				if (ts == null) {
					ts = new TriggerSettings__c();
					SetTriggerSettingDefaults(ts);	
					if (!System.Test.isRunningTest()) {
						// during tests, settings are already set and we can't insert them again.
						insert ts; 
					}					
				}
			}
			return ts;				
		}
		
		set;
	}
	
}