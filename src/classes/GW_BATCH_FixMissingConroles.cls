global class GW_BATCH_FixMissingConroles implements Database.Batchable<SObject> {

	/* run this from the system log window by pasting in the following code (example is using a batch size of 100):
		
		GW_BATCH_FixMissingConroles batch = new GW_BATCH_FixMissingConroles();
		id batchinstanceid = database.executeBatch (batch, 100);   
		
	*/
	//to fix missing contact roles from import
	
	string Query;

	
	// constructors
    global GW_BATCH_FixMissingConroles () {
    	this.Query = 'SELECT id,name,accountid,CR_Contact_Id__c,CR_Contact_Role__c,CR_HHroles__c ' +  
    		'FROM Opportunity WHERE id NOT IN (SELECT opportunityid FROM OpportunityContactRole) AND isdeleted = false AND CR_Contact_Id__c != null AND AccountId = null'; 
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(Query);
    }
	
	global void execute(Database.BatchableContext BC, List<Sobject> SBatch){
		List<Opportunity> opps = (List<Opportunity>) SBatch;
		List<id> conIds = new List<id>();
		for (Opportunity opp:opps) {
			conIds.add(opp.CR_Contact_Id__c);
		} 
		
		ONEN_OpportunityContactRoles.CreateOppConRolesBulk ( opps, conIds);
		
	}
	
	
    global void finish(Database.BatchableContext BC){       
    }
}