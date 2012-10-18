public with sharing class GW_CampaignMember {

	public GW_CampaignMember() {}

	public static void upsertCM(CampaignMember cm) {
		if (ONEN_Constants.ENABLE_CAMPAIGNMEMBER_ERROR_TABLE) {
			try {
				upsert cm;
			} catch (System.DmlException e) {
				Campaign_Member_Error__c cmh = convertCM(cm);
				cmh.Exception__c = e.getdmlMessage(0);
				cmh.Exception_Type__c =''+e.getDmlType(0); 
				
				upsert findExistingHolding(cmh);
			}
		} else upsert cm;
	}

	public static void upsertCM(list<CampaignMember> cml) {
		if (ONEN_Constants.ENABLE_CAMPAIGNMEMBER_ERROR_TABLE) {
			list<Campaign_Member_Error__c> failedCM = new list<Campaign_Member_Error__c>();
			list<CampaignMember> existingCM = findExistingCM(cml);
			
			list<Database.UpsertResult> uResults = database.upsert(existingCM, false);
			
			for(integer i=0;i<uResults.size();i++) {
				//if the upsert failed, create holding record
				if (!uResults[i].isSuccess()) {
					Campaign_Member_Error__c cmh = convertCM(cml[i]);
					cmh.Exception__c = uResults[i].getErrors()[0].getMessage();
					cmh.Exception_Type__c = '' + uResults[i].getErrors()[0].getStatusCode();
					failedCM.add(cmh);
				}
			}
			if (!failedCM.isEmpty()) upsert findExistingHolding(failedCM);
		} else upsert cml;		
	}
	
	public static Campaign_Member_Error__c convertCM (CampaignMember cm){
		Campaign_Member_Error__c cmh = new Campaign_Member_Error__c();
		if (cm.LeadId!=null) cmh.Lead__c = cm.LeadId;
		if (cm.ContactId!=null) cmh.Contact__c = cm.ContactId;
		if (cm.CampaignId!=null) cmh.Campaign__c = cm.CampaignId;	
		if (cm.Status!=null) cmh.Status__c = cm.Status;
		cmh.Times_Failed__c = 0;
		return cmh;
	}
	
	public static list<Campaign_Member_Error__c> convertCM (list<CampaignMember> cmList) {
		list<Campaign_Member_Error__c> cmhList = new list<Campaign_Member_Error__c>();
		for (CampaignMember c:cmList) {
			cmhList.add(convertCM(c));
		}
		return cmhList;
	}
	
	public static CampaignMember convertHolding (Campaign_Member_Error__c cmh) {
		CampaignMember cmResult = new CampaignMember();
		if (cmh.Lead__c!=null) cmResult.LeadId = cmh.Lead__c;
		if (cmh.Contact__c!=null) cmResult.ContactId = cmh.Contact__c;
		if (cmh.Status__c!=null) cmResult.Status = cmh.Status__c;
		if (cmh.Campaign__c!=null) cmResult.CampaignId = cmh.Campaign__c;
		return cmResult;
	}
	
	public static list<CampaignMember> convertHolding (list<Campaign_Member_Error__c> cmhList) {
		list<CampaignMember> cmList = new list<CampaignMember>();
		for (Campaign_Member_Error__c cmh:cmhList) {
			cmList.add(convertHolding(cmh));
		}
		return cmList;
	}

    public static CampaignMember findExistingCM (CampaignMember cm) {
    	list<CampaignMember> queryCM = new list<CampaignMember>();
    	id memberid;
		if (cm.ContactId!=null) memberid = cm.ContactId;
		if (cm.LeadId!=null) memberid = cm.LeadId;
		if (memberid!=null && cm.CampaignId!=null) {
			queryCM = [SELECT Id, ContactId, LeadId, CampaignId, LastModifiedDate FROM CampaignMember WHERE (ContactId = :memberid OR LeadId = :memberid) AND CampaignId =:cm.CampaignId];
		} 
		if (!queryCM.isEmpty()) {
			queryCM[0].Status = cm.Status;
			return queryCM[0];
		}
		else return cm;
    }

    //find and update existing CampaignMembers
    public static list<CampaignMember> findExistingCM (list<CampaignMember> cmList) {
		map<id,id> memberIds = new map<id,id>();
		map<string,CampaignMember> concatIds = new map<string,CampaignMember>();
		list<CampaignMember> cmResult = new list<CampaignMember>();
		
		//construct Contact/Lead Id to Campaign Id map for finding existing CampaignMembers
		for (CampaignMember cm : cmList) {
			if (cm.ContactId!=null && cm.CampaignId!=null) 
				memberIds.put(cm.ContactId, cm.CampaignId);
			else if (cm.LeadId!=null && cm.CampaignId!=null) 
				memberIds.put(cm.LeadId, cm.CampaignId);
		}

		//find all existing CampaignMembers		
		for (CampaignMember cm:[SELECT Id, ContactId, LeadId, CampaignId, LastModifiedDate FROM CampaignMember WHERE (ContactId in :memberIds.keySet() OR LeadId in:memberIds.keySet()) AND CampaignId in :memberIds.values()]) {
			if (cm.ContactId!=null) concatIds.put((string)cm.ContactId + ((string)cm.CampaignId), cm);
			else concatIds.put((string)cm.LeadId + ((string)cm.CampaignId), cm);
		}
		
		//loop through CampaignMembers to insert, add Id for upsert if they exist already
		for (CampaignMember cm:cmList) {
			id memberid;
			if (cm.ContactId!=null) memberid = cm.ContactId;
			if (cm.LeadId!=null) memberid = cm.LeadId;
			//if the CampaignMember exists, add the existing CampaignMember to the results, update the status
			if (memberid!=null && cm.CampaignId != NULL && concatIds.keyset().contains((string)memberId + cm.CampaignId)) {
				CampaignMember tempcm = concatIds.get((string)memberId + cm.CampaignId);
				tempcm.Status = cm.Status;
				cmResult.add(tempcm);
			//if the CampaignMember doesn't exist, add the original result
			} else cmResult.add(cm);
		}
		return cmResult;
    }
    
    public static Campaign_Member_Error__c findExistingHolding (Campaign_Member_Error__c cmh) {
    	list<Campaign_Member_Error__c> queryCMH = new list<Campaign_Member_Error__c>();
    	id memberid;
    	
		if (cmh.Contact__c!=null) memberid = cmh.Contact__c;
		if (cmh.Lead__c!=null) memberid = cmh.Lead__c;
		if (memberid!=null && cmh.Campaign__c!=null) {
			queryCMH = [SELECT Id, Contact__c, Lead__c, Campaign__c, CreatedDate FROM Campaign_Member_Error__c WHERE (Contact__c = :memberid OR Lead__c = :memberid) AND Campaign__c =:cmh.Campaign__c];
		} 
		if (!queryCMH.isEmpty()) {
			queryCMH[0].Status__c = cmh.Status__c;
			return queryCMH[0];
		}		
		else return cmh;
    }
    
    public static list<Campaign_Member_Error__c> findExistingHolding (list<Campaign_Member_Error__c> cmhList) {
		map<id,id> memberIds = new map<id,id>();
		map<string,Campaign_Member_Error__c> concatIds = new map<string,Campaign_Member_Error__c>();
    	list<Campaign_Member_Error__c> cmhResult = new list<Campaign_Member_Error__c>();

		//construct Contact/Lead Id to Campaign Id map for finding existing holding records
		for (Campaign_Member_Error__c cmh : cmhList) {
			if (cmh.Contact__c!=null && cmh.Campaign__c!=null) 
				memberIds.put(cmh.Contact__c, cmh.Campaign__c);
			else if (cmh.Lead__c!=null && cmh.Campaign__c!=null) 
				memberIds.put(cmh.Lead__c, cmh.Campaign__c);
		}
		
		//find all existing holding records		
		for (Campaign_Member_Error__c cmh:[SELECT Id, Contact__c, Lead__c, Campaign__c, CreatedDate FROM Campaign_Member_Error__c WHERE (Contact__c in :memberIds.keySet() OR Lead__c in:memberIds.keySet()) AND Campaign__c in :memberIds.values()]) {
			if (cmh.Contact__c!=null) concatIds.put((string)cmh.Contact__c + ((string)cmh.Campaign__c), cmh);
			else concatIds.put((string)cmh.Lead__c + ((string)cmh.Campaign__c), cmh);
		}
		
		//loop through Holding records to insert, add Id for upsert if they exist already
		for (Campaign_Member_Error__c cmh:cmhList) {
			id memberid;
			if (cmh.Contact__c!=null) memberid = cmh.Contact__c;
			if (cmh.Lead__c!=null) memberid = cmh.Lead__c;
			//if the CampaignMember exists, add the existing Holding to the results, update the status
			if (memberid!=null && cmh.Campaign__c != NULL && concatIds.keyset().contains((string)memberId + cmh.Campaign__c)) {
				Campaign_Member_Error__c tempcmh = concatIds.get((string)memberId + cmh.Campaign__c);
				tempcmh.Status__c = cmh.Status__c;
				cmhResult.add(tempcmh);
			//if the CampaignMember doesn't exist, add the original result
			} else cmhResult.add(cmh);
		}
		return cmhResult;
    }

	@istest
	static void rowLockTest() {
	//a required field missing on a CampaignMember puts it into the holding table
		Campaign lockedCampaign = new Campaign (
			Name = 'foo'
		);
		insert lockedCampaign;
		
		Contact testContact = new Contact (
			LastName = 'foo'
		);
		insert testContact;
		
		CampaignMember testMember = new CampaignMember(
			CampaignId = lockedCampaign.id//,
			//ContactId = testContact.id
		);

		list<CampaignMember> testList = new list<CampaignMember>();
		testList.add(testMember);
		
		test.startTest();
		GW_CampaignMember.upsertCM(testList);
		test.stopTest();
		
		list<Campaign_Member_Error__c> queryResults = [SELECT Id, Exception__c FROM Campaign_Member_Error__c WHERE Campaign__c=:lockedCampaign.id];
		system.debug('qresults: '+queryResults);
		system.assertEquals(1,queryResults.size());
	}
	
	@isTest
	static void testUpdateBatch() {
	//updated holding records should updated existing CMs, created new ones	
		Campaign lockedCampaign = new Campaign (
			Name = 'foo'
		);
		insert lockedCampaign;
		
		Contact testContact = new Contact (
			LastName = 'foo'
		);
		insert testContact;
		
		CampaignMember existingMember = new CampaignMember(
			CampaignId = lockedCampaign.id,
			ContactId = testContact.id,
			Status = 'Sent'
		);
		
		Campaign_Member_Error__c updatedHolding = GW_CampaignMember.convertCM(existingMember);
		updatedHolding.Status__c = 'Responded';
		insert updatedHolding;
		insert existingMember;
		
		test.startTest();
        GW_BATCH_CampaignMember batch = new GW_BATCH_CampaignMember('SELECT Id, Contact__c, Lead__c, Campaign__c, Exception_Type__c, Exception__c, Status__c, createddate FROM Campaign_Member_Error__c WHERE Times_Failed__c < 5');
        id batchinstanceid = database.executeBatch (batch, 20);
        test.stopTest();
        
        list<CampaignMember> cmQuery = [SELECT Id, Status FROM CampaignMember WHERE id=:existingMember.id];
        system.assertEquals('Responded',cmQuery[0].Status,'Status should be updated to responded.');
        
        list<Campaign_Member_Error__c> cmhQuery = [SELECT Id FROM Campaign_Member_Error__c];
        system.assertEquals(0,cmhQuery.size(),'Holding record should be deleted: '+ cmhQuery);
	}

	@isTest
	static void testExistingCMH() {
	//failed inserted campaignmembers should update an existing holding record
		Campaign lockedCampaign = new Campaign (
			Name = 'foo'
		);
		insert lockedCampaign;
		
		Contact testContact = new Contact (
			LastName = 'foo'
		);
		insert testContact;
		
		Campaign_Member_Error__c existingHolding = new Campaign_Member_Error__c(
			Campaign__c = lockedCampaign.id,
			Contact__c = testContact.id,
			Status__c = 'Sent'
		);
		insert existingHolding;
		
		Campaign_Member_Error__c updatedHolding = new Campaign_Member_Error__c(
			Campaign__c = lockedCampaign.id,
			Contact__c = testContact.id,
			Status__c = 'Responded'
		);
		
		Campaign_Member_Error__c forUpdate = findExistingHolding(updatedHolding);
		system.assert(forUpdate.Id != null);
		system.assert(forUpdate.Status__c == 'Responded');		
	}
	
/*	@isTest
	static void testExistingHolding() {
	//successfully inserted campaignmembers should delete corresponding holding records	
		Campaign lockedCampaign = new Campaign (
			Name = 'foo'
		);
		insert lockedCampaign;
		
		list<Contact> testcons = new list<Contact>();
		for (integer i=0;i<20;i++){
			Contact c = new Contact(
				lastname='test'+i
			);
			testcons.add(c);
		}
		insert testcons;
		
		list<Campaign_Member_Error__c> existingHolding = new list<Campaign_Member_Error__c>();
		for (integer i=0;i<20;i+=2) {
			Campaign_Member_Error__c temp = new Campaign_Member_Error__c(
				Campaign__c = lockedCampaign.id,
				Contact__c = testCons[i].id,
				Status__c = 'Sent'
			);
			existingHolding.add(temp);
		}
		insert existingHolding;
		
		list<CampaignMember> cml = new list<CampaignMember>();
		for (integer i=0;i<20;i++){
			CampaignMember temp = new CampaignMember(
				ContactId = testcons[i].Id,
				CampaignId = lockedCampaign.id,
				status='Responded'
			);
			cml.add(temp);
		}
		upsertCM(cml);
		
		list<Campaign_Member_Error__c> querycmh = [SELECT id FROM Campaign_Member_Error__c];
		system.assertEquals(0,querycmh.size(),'Holding records should be deleted.');
	}
*/	
	@isTest
	static void testBulk() {
	//successfully inserted campaignmembers should delete corresponding holding records	
		Campaign lockedCampaign = new Campaign (
			Name = 'foo'
		);
		insert lockedCampaign;
		
		list<Contact> testcons = new list<Contact>();
		for (integer i=0;i<20;i++){
			Contact c = new Contact(
				lastname='test'+i
			);
			testcons.add(c);
		}
		insert testcons;
		
		list<CampaignMember> existingcm = new list<CampaignMember>();
		for (integer i=0;i<20;i+=2){
			CampaignMember temp = new CampaignMember(
				ContactId = testcons[i].Id,
				CampaignId = lockedCampaign.id,
				status='Sent'
			);
			existingcm.add(temp);
		}
		insert existingcm;
				
		list<Campaign_Member_Error__c> existingHolding = new list<Campaign_Member_Error__c>();
		for (integer i=0;i<20;i++) {
			Campaign_Member_Error__c temp = new Campaign_Member_Error__c(
				Campaign__c = lockedCampaign.id,
				Contact__c = testCons[i].id,
				Status__c = 'Responded'
			);
			if (i==10) temp.Campaign__c = null;
			existingHolding.add(temp);
		}
		
		test.startTest();
        insert existingHolding;
        
        GW_BATCH_CampaignMember batch = new GW_BATCH_CampaignMember('SELECT Id, Contact__c, Lead__c, Campaign__c, Exception_Type__c, Exception__c, Status__c, CreatedDate FROM Campaign_Member_Error__c WHERE Times_Failed__c < 5');
        id batchinstanceid = database.executeBatch (batch, 20);
        test.stopTest();
        
        list<CampaignMember> cmQuery = [SELECT Id, Status FROM CampaignMember where status='Responded'];
        system.assertEquals(19,cmQuery.size());
        
        list<Campaign_Member_Error__c> cmhQuery = [SELECT Id FROM Campaign_Member_Error__c];
        system.assertEquals(1,cmhQuery.size(),'Holding records should be deleted for successful campaignmembers: '+ cmhQuery);
	}
}