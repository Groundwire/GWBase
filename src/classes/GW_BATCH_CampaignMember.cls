global without sharing class GW_BATCH_CampaignMember implements Database.Batchable<SObject>, Schedulable {

	//parameters
	public string query {get;set;}
	public id cronTriggerId {get;set;}

	//constructors
	global GW_BATCH_CampaignMember () {
		query = 'SELECT Id, Contact__c, Lead__c, Campaign__c, Exception_Type__c, Exception__c, Status__c, CreatedDate FROM Campaign_Member_Error__c WHERE Times_Failed__c < 5 AND Exception_Type__c!=\'REQUIRED_FIELD_MISSING\' AND Exception_Type__c!=\'CAMPAIGNMEMBER_NEWER_THAN_ERROR\'';
	}
	global GW_BATCH_CampaignMember (string q) {
		query = q;
	}
	global GW_BATCH_CampaignMember (id i){
		cronTriggerId = i;
		query = 'SELECT Id, Contact__c, Lead__c, Campaign__c, Exception_Type__c, Exception__c, Status__c, CreatedDate FROM Campaign_Member_Error__c WHERE Times_Failed__c < 5 AND Exception_Type__c!=\'REQUIRED_FIELD_MISSING\' AND Exception_Type__c!=\'CAMPAIGNMEMBER_NEWER_THAN_ERROR\'';
	}
	
	//batch methods
	global database.Querylocator start(Database.BatchableContext bc) { 
		return Database.getQueryLocator(query);
	}

    global void execute(SchedulableContext SC) {
        // check running batches in case there are already 5 running
        AsyncApexJob[] batchInProgress = [select id from AsyncApexJob where (status = 'Queued' or status = 'Processing') and 
            ApexClass.Name like '%GW_BATCH_CampaignMemberHolding'];
            
        if (batchInProgress.size() < 3) {
            GW_BATCH_CampaignMember batch = new GW_BATCH_CampaignMember('SELECT Id, Contact__c, Lead__c, Campaign__c, Exception_Type__c, Exception__c, Status__c, CreatedDate FROM Campaign_Member_Error__c WHERE Times_Failed__c < 5 AND Exception_Type__c!=\'REQUIRED_FIELD_MISSING\' AND Exception_Type__c!=\'CAMPAIGNMEMBER_NEWER_THAN_ERROR\'');
            id batchinstanceid = database.executeBatch (batch, 200);
        }  
    }
    
    global void execute(Database.BatchableContext bc, Sobject[] result) {
		list<Campaign_Member_Error__c> cmhToDelete = new list<Campaign_Member_Error__c>();
		list<Campaign_Member_Error__c> cmhToUpdate = new list<Campaign_Member_Error__c>();
		
		//convert holding objects to campaignmembers
		list<Campaign_Member_Error__c> cmhList = (list<Campaign_Member_Error__c>)result;
		list<Campaign_Member_Error__c> cmhForUpsert = new list<Campaign_Member_Error__c>();
		
		//find existing campaignmembers for update
		list<CampaignMember> cmResult = GW_CampaignMember.findExistingCM(GW_CampaignMember.convertHolding(cmhList)); 
		list<CampaignMember> cmForUpsert = new list<CampaignMember>();
		
		//separate out Campaign Members that were modified since the holding was created
		for (integer i=0;i<cmhList.size();i++) {
			//only update the holding record if the existing campaignmember wasn't modified since the holding was created
			if (cmResult[i].id==null || (cmResult[i].LastModifiedDate >= cmhList[i].CreatedDate)) {
				//campaignmember is new, or hasn't been updated since the holding record was created.
				system.debug('CM Modified: ' + cmResult[i].LastModifiedDate +' Holding Created: '+ cmhList[i].CreatedDate);
				cmForUpsert.add(cmResult[i]);
				cmhForUpsert.add(cmhList[i]);
			} else {
				//campaignmember was updated since the holding record was created. Update error message.
				cmhList[i].Exception__c = 'Campaign Member was updated since this record was created, there will be no further attempts to update this record.';
				cmhList[i].Exception_Type__c = 'CAMPAIGNMEMBER_NEWER_THAN_ERROR';
				cmhToUpdate.add(cmhList[i]);
			}
		}
		
		//upsert as many rows as possible		
		list<Database.UpsertResult> uResults = database.upsert(cmForUpsert, false);
		//process results
		for(integer i=0;i<uResults.size();i++) {
			//if the upsert succeeded, delete the holding record
			if (uResults[i].isSuccess()) cmhToDelete.add(cmhForUpsert[i]);
			//else update errors and fail count
			else {
				cmhForUpsert[i].Exception__c = uResults[i].getErrors()[0].getMessage();
				cmhForUpsert[i].Exception_Type__c = '' + uResults[i].getErrors()[0].getStatusCode();
				if(cmhForUpsert[i].Times_Failed__c != null) cmhForUpsert[i].Times_Failed__c += 1;
				else cmhForUpsert[i].Times_Failed__c = 1; 
				cmhToUpdate.add(cmhForUpsert[i]);
			}
		}
		
		//update/delete holding objects
		if (!cmhToUpdate.isEmpty()) update cmhToUpdate;
		if (!cmhToDelete.isEmpty()) delete cmhToDelete;
    }

    global void finish(Database.BatchableContext bc) {
    	if (cronTriggerId != null) {
			try {
				system.abortJob(cronTriggerId);
			} catch (exception e) {
				system.debug ('Failed to abort crontrigger job for GW_BATCH_CampaignMemberHolding after batch completed: '+e);
			}
    	}
    }
}