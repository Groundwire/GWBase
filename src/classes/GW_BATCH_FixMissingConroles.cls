// Written by Matthew Scholtz, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 04/20/2011
* @description batch utility method for creating missing contact roles not created via trigger upon data import, called from the
* system log. Looks for opps without contact roles who also have a value in CR_Contact_Id__c != null AND AccountId = null
* run this from the system log window by pasting in the following code (example is using a batch size of 100):
*        GW_BATCH_FixMissingConroles batch = new GW_BATCH_FixMissingConroles();
*        id batchinstanceid = database.executeBatch (batch, 100);   
*/
global class GW_BATCH_FixMissingConroles implements Database.Batchable<SObject> {

    //to fix missing contact roles from import
    
    string Query;
    
    // constructors
    /*******************************************************************************************************
	* @description batch class constructor, contains a query for opportunities missing contact roles, which is the batch query
	*/   
    global GW_BATCH_FixMissingConroles () {
        this.Query = 'SELECT id,name,accountid,CR_Contact_Id__c,CR_Contact_Role__c,CR_HHroles__c ' +  
            'FROM Opportunity WHERE id NOT IN (SELECT opportunityid FROM OpportunityContactRole) AND isdeleted = false AND CR_Contact_Id__c != null AND AccountId = null'; 
    }
    
    /*******************************************************************************************************
	* @description standard batch finish method, must be global
	* @param BC Database.BatchableContext BC - standard batch argument
	* @return Query - one chunk of records from the batch query
	*/   
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(Query);
    }

    /*******************************************************************************************************
	* @description standard batch execute method, must be global, see class notes for description of functionality
	* @param Database.BatchableContext BC - standard batch argument
	* @param SBatch - list of sobjects in the batch to process, standard batch argument
	*/       
    global void execute(Database.BatchableContext BC, List<Sobject> SBatch){
        List<Opportunity> opps = (List<Opportunity>) SBatch;
        List<id> conIds = new List<id>();
        for (Opportunity opp:opps) {
            conIds.add(opp.CR_Contact_Id__c);
        } 
        
        ONEN_OpportunityContactRoles.CreateOppConRolesBulk ( opps, conIds);
        
    }
    
    /*******************************************************************************************************
	* @description standard batch finish method, must be global
	* @param Database.BatchableContext BC - standard batch argument
	*/
    global void finish(Database.BatchableContext BC){       
    }
}