// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Evan Callahan
* @date 01/01/2010
* @description Batch apex class to rollup opportunities.
*/
global class GW_BATCH_OppRollup implements Database.Batchable<SObject>, Schedulable {

	public String query { get; set; }

	// constructors
	public GW_BATCH_OppRollup() { }		// this constructor needed to allow this class to be schedulable
	public GW_BATCH_OppRollup(string q) { 
		query = q; 
	}

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param SC NULL_PARAMETER
	*/ 	
	global void execute(SchedulableContext SC) { 
		GW_OppRollups rg = new GW_OppRollups();
		rg.rollupAll();    
	}

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param bc NULL_PARAMETER
	* @return NULL_RETURN
	*/ 	
	global database.Querylocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);		 
	}

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param bc NULL_PARAMETER
	* @param result NULL_PARAMETER
	* @return NULL_RETURN
	*/ 
	global public void execute(Database.BatchableContext bc, Sobject[] result) {

		// run rollups for this batch		
		GW_OppRollups rg = new GW_OppRollups();
		
 		if (result[0].getSObjectType() == Account.sObjectType) { 
			rg.RollupAccounts((list<account>)result);
 		} else {
			rg.RollupHouseholds((list<onen_household__c>)result);
			//also reconcile any Opportunity Contact Roles that got out of sync with the Primary Contact on Opp
			ONEN_OpportunityContactRoles ocr = new ONEN_OpportunityContactRoles();
 			ocr.reconcileConRoles((list<ONEN_household__c>)result);
 		}
	}

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param bc NULL_PARAMETER
	* @return NULL_RETURN
	*/
	global void finish(Database.BatchableContext bc) {
	}

	public static testMethod void testBatch() {
		GW_BATCH_OppRollup batch = new GW_BATCH_OppRollup(
			'SELECT id FROM account limit 200'
		);
		id batchProcessId = database.executeBatch(batch);
	}
}