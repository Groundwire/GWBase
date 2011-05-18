// Written by Matthew Scholtz, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

public with sharing class GW_OpportunityAddToCampaign {

	public static void AddToCampaign(list<Opportunity> listOppsNew, map<id, Opportunity> mapOppsOld) {
		// Written by Matthew Scholtz, copyright (c) 2007 Groundwire
		// when we first end up w/ a closedwon Opp that has a campaign source, 
		// ensure that the primary contact has a campaign mbrship for that campaign set to Responded
		// don't worry about opp deletions - don't ever remove camp mbrship once created
		// note: this doesn't prevent user from later removing camp mbr or changing it to not responded - that's OK I think
		// also note: won't trigger if user later changes primary contact on opp - that's probably OK too
	
		string DefaultDonatedStatus = ONEN_Constants.CAMPAIGN_DEFAULT_DONATED_STATUS;
		Set<id> allOppIds = new Set<id> ();
		Map<id,id> OppToContactIds = new Map<id,id> (); 
		// Map<id,Map<id,CampaignMember>> ContactToCMs = new Map<id,Map<id,CampaignMember>> ();
		Map<id,Opportunity> oppsToProcess = new Map<id,Opportunity> ();
		List<CampaignMember> CMsToInsert = new List<CampaignMember> ();
		List<CampaignMember> CMsToUpdate = new List<CampaignMember> ();
		
		// this map's keys will be a concatenation of contactID & campaignID 
		Map<string,CampaignMember> comboIDMap = new Map<string,CampaignMember> ();
		
		// use a set for this because it will automatically dedup
		Set<id> CampaignsToCheckCMS = new Set<id> ();
		Set<id> CampToCheckResponded = new Set<id> ();
		Set<id> CMIDsToUpdateSet = new set<id> ();
		Set<id> CampaignIds = new set<id> ();
		
		// load settings for opp types
		set<id> recordTypesToExcludeAccts = new set<id>();
		set<id> recordTypesToExcludeCons = new set<id>();
		set<string> oppTypesToExcludeAccts = new set<string>();
		set<string> oppTypesToExcludeCons = new set<string>();	
	    OppRollupSettings__c rollupSettings = OppRollupSettings__c.getInstance();
		if (rollupSettings != null) {
			if (rollupSettings.Excluded_Contact_Opp_Rectypes__c != null) {
				set<string> rtNamesToExclude = new set<string>(rollupSettings.Excluded_Contact_Opp_Rectypes__c.split(';'));
				recordTypesToExcludeCons = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);
			}
			if (rollupSettings.Excluded_Account_Opp_Rectypes__c != null) {
				set<string> rtNamesToExclude = new set<string>(rollupSettings.Excluded_Account_Opp_Rectypes__c.split(';'));
				recordTypesToExcludeAccts = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);
			}
			if (rollupSettings.Excluded_Contact_Opp_Types__c != null) {
				oppTypesToExcludeCons = new set<string>(rollupSettings.Excluded_Contact_Opp_Types__c.split(';'));
			}
			if (rollupSettings.Excluded_Account_Opp_Types__c != null) {
				oppTypesToExcludeAccts = new set<string>(rollupSettings.Excluded_Contact_Opp_Types__c.split(';'));
			}
		}
		
		// first, make sure we have checked for contact role creation if necessary
		// (have to do this here to insure triggers happen in the right order)
		// no longer necessary, since we control the ordering in GW_OpportunityTriggers.
		//if ( Trigger.isInsert && ONEN_OpportunityContactRoles.haveCheckedContactRoles == false ) {
		//	ONEN_OpportunityContactRoles.CheckContactRoles ( trigger.newmap );	
		//}
		
		// first figure out which opps need processing - only want contact opps whose
		for (Opportunity opp : listOppsNew) {
			boolean isChgd = false;
			if (mapOppsOld != null) {
				Opportunity oldOpp = mapOppsOld.get(opp.Id);
				if (oldOpp.CampaignID != opp.CampaignID || oldOpp.StageName != opp.StageName) isChgd = true;
			}
			if ( opp.CampaignID != Null && opp.AccountID==null && (Trigger.IsInsert || isChgd )) {	
				oppsToProcess.put (opp.id, opp);
				CampaignIds.add(opp.CampaignId);	
			}
		}
		
		If ( oppsToProcess.size() > 0 ) {
		
			// * get set of oppID's in trigger.new
			// and pass set to OppContactRoles.getPrimaryContactID, returns map PrimaryContacts (OppID -> ContactID)
			allOppIds = oppsToProcess.keySet();
			OppToContactIds = ONEN_OpportunityContactRoles.GetPrimaryContactIdsBulk (allOppIds);
		
			//system.debug ('oppToContactIds map: ' + OppToContactIds);
			
			// map combos of contact & camp ID's to the CM's
			for (CampaignMember thisCM : [Select Id, ContactId, CampaignId, Status, HasResponded From CampaignMember WHERE ContactId IN :OppToContactIds.values() AND CampaignId IN :CampaignIds]) {
				string comboID = thisCM.ContactID + '|' + thisCM.CampaignID;
				comboIDMap.put (comboID,thisCM);
			}
			//system.debug('This CampaignMember: ' + comboIDMap);
			
			// now loop through all of our opps
			for (Opportunity thisOpp : oppsToProcess.values() ) {
				
				id ConId = OppToContactIds.get(thisOpp.Id);
				id CampId = thisOpp.CampaignId;
	
				// but only process those that actually have a primary contact			
				if ( ConId != null) {
					CampaignMember thisCM;
					string comboID = ConId + '|' + CampId;
					thisCM = comboIDMap.get(comboID);
	
					boolean isNotGift = (thisOpp.accountId == null && 
						(recordTypesToExcludeCons.contains(thisOpp.RecordTypeId) ||
						oppTypesToExcludeCons.contains(thisOpp.Type))) ||
						(thisOpp.accountId != null && 
						(recordTypesToExcludeAccts.contains(thisOpp.RecordTypeId) ||
						oppTypesToExcludeAccts.contains(thisOpp.Type)));
	
					// if this contact doesn't already have a CM for this campaign, create one				
					if ( thisCM == null ) {
						CampaignMember newCM = new CampaignMember(
							ContactId = ConId ,
							CampaignId = CampId						
						);
						//use the default status unless the opp is won, then use the default donated status if it's a gift
						if (thisOpp.IsWon == True) {						
							If ( isNotGift ) {
								newCM.Status = 'Responded';
								CampToCheckResponded.add (CampId);
							} else {
								newCM.Status = DefaultDonatedStatus;
								CampaignsToCheckCMS.add (CampId);
							}
						}
						CMsToInsert.add (newCM);
						comboIDMap.put (comboID,newCM);
	
						
					} else {
						// if they do already have a CM, chg the status where appropriate
						if ( thisCM.HasResponded == true || thisOpp.IsWon == false) {
							// if already responded, or not won, do nothing
						} else {
							If ( isNotGift ) {
								thisCM.Status = 'Responded';
								CampToCheckResponded.add (CampId);
							} else {
								thisCM.Status = DefaultDonatedStatus;
								CampaignsToCheckCMS.add (CampId);
							}
							if (CMIDsToUpdateSet.add(thisCM.Id)) {
								CMsToUpdate.add(thisCM);
							}
						}
					}
				}
			}
			
			// check list of Campaigns that they have the Donated status, add if not
			// last param means we require that the status be HasResponded, and change it to that if it's not 
			// already
			boolean statusOK = ONEN_CampaignMemberStatus.CheckCMStatusExistsBulk (CampaignsToCheckCMS,DefaultDonatedStatus,true);
			boolean statusOK2 = ONEN_CampaignMemberStatus.CheckCMStatusExistsBulk (CampToCheckResponded,'Responded',true);
			
			//system.debug ('to update: ' + CMsToUpdate);
			//system.debug ('to insert: ' + CMsToInsert);
	
			// need to insert the new ones first, in case any will be subsequent dups that need updating.
			if ( CMsToInsert.size() > 0 ) {
				insert CMsToInsert;
			}	
			//system.debug('CMDebug: ' + CMsToUpdate);	
			if ( CMsToUpdate.size() > 0 ) {
				update CMsToUpdate;		
			}
			
		}
	}	

	/////////////////////////////////////////////////////////////////////////////////////////////
	// TEST CODE
	/////////////////////////////////////////////////////////////////////////////////////////////
	
	private static string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
	private static string WithOppStatus = ONEN_Constants.CAMPAIGN_DEFAULT_DONATED_STATUS;

	static testMethod void OppToCampaign_OnUpdateChgToResponded () {
		
		// tests trigger OppToCampaignMbr
		// starting w/ a contact who's a mbr of a campaign, but not showing Responded
		// test that adding an Opp sourced to that campaign will chg status to responded
		// first add a couple of contacts

		system.debug ('TEST>>>> adding contact #1');

		Contact testCon1 = ONEN_UnitTestData.CreateTestContact(1);
		insert testCon1;

		system.debug ('TEST>>>> adding campaign');
		
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp1 = new Campaign (
			Name = 'Test Campaign 1',
			IsActive = True
		);
		insert testCamp1;
		
		system.debug ('TEST>>>> adding CampMbr for Contact #1 & camp #1, as Sent...');
	
		// not sure it's worth it to factor this out, but it does make it a little simpler
		//CampaignMember testCMbr1 = ONEN_UnitTestData.CreateCampaignMember (testCamp1.Id, testCon1.Id, 'Sent');
		
		system.debug ('TEST>>>> adding Opp #1 for Con #1, prospecting/camp #1...');

		// insert an Opp for Con1 that meets criteria but not Won
		// uses trigger to create con role
		Opportunity testOpp1 = New Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name = 'Test Opp 1',
			Amount = 50,
			CloseDate = system.Today(),
			StageName = 'Prospecting',
			CampaignId = testCamp1.Id,
			CR_Contact_Id__c = testCon1.Id,
			CR_Contact_Role__c = 'Individual Donor'
		);
		insert testOpp1;
		
		// assert Con1 not yet Responded mbr of camp
		CampaignMember[] testCmbr1Chg = [Select Id, Status,HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon1.Id];
		system.assertEquals (1 , testCmbr1Chg.size());
		system.assertEquals ('Sent' , testCmbr1Chg[0].Status );
		system.assertEquals (False , testCmbr1Chg[0].HasResponded );
		
		system.debug ('TEST>>>> chging Opp #1 to closed won');

		// now chg opp to closed won, should trigger here
		testOpp1.StageName = 'Closed Won';
		update testOpp1;
		
		// assert Con1 mbr of camp w/ 'Responded'
		testCmbr1Chg = [Select Id, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon1.Id];
		system.assertEquals (WithOppStatus , testCmbr1Chg[0].Status );
		system.assertEquals (True , testCmbr1Chg[0].HasResponded );
		
	}

	static testMethod void OppToCampaign_AlreadyCampaignMbr () {

		// given a contact who's already mbr of a campaign w/ status responded
		// check that creating and then deleting an opp sourced to that campaign
		// does not chg campaign status at all
		
		// note: each test method can do one DML insert of Opps
		// if it expects con roles to be created via trigger
		// (because of static var controlling whether con roles have been checked)
		// (see class OppContactRoles)

		system.debug ('TEST>>>> adding contact #2');
		
		Contact testCon2 = ONEN_UnitTestData.CreateTestContact(2);
		insert testCon2;

		system.debug ('TEST>>>> adding campaign');
		
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp1 = new Campaign (
			Name = 'Test Campaign 1',
			IsActive = True
		);
		insert testCamp1;
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp2 = new Campaign (
			Name = 'Test Campaign 2',
			IsActive = True
		);
		insert testCamp2;
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp3 = new Campaign (
			Name = 'Test Campaign 3',
			IsActive = True
		);
		insert testCamp3;
				
		system.debug ('TEST>>>> adding CampMbr for Con #2 & camp #1, as Responded...');
		
		// add Contact 2 to the campaign as responded
		CampaignMember testCMbr1 = ONEN_UnitTestData.CreateCampaignMember (testCamp1.Id, testCon2.Id, 'Responded');	
		CampaignMember testCMbr2 = ONEN_UnitTestData.CreateCampaignMember (testCamp2.Id, testCon2.Id, 'Responded');	
		CampaignMember testCMbr3 = ONEN_UnitTestData.CreateCampaignMember (testCamp3.Id, testCon2.Id, 'Responded');	
		
		system.debug ('TEST>>>> adding Opp #2 for Con #2, closed won & camp #1...');

		// insert an Opp for con2 that meets criteria
		Opportunity testOpp2 = New Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name = 'Test Opp 2',
			Amount = 1000,
			CloseDate = system.Today(),
			StageName = 'Closed Won',
			CampaignId = testCamp1.Id,
			CR_Contact_Id__c = testCon2.Id,
			CR_Contact_Role__c = 'Individual Donor'
		);
		insert testOpp2;
		
		
		// assert COn2 still mbr of camp w/ responded - shouldn't chg to donated in this case
		CampaignMember[] testCmbr1Chg = [Select Id, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon2.Id];
		system.assertEquals ('Responded' , testCmbr1Chg[0].Status );
		system.assertEquals (True , testCmbr1Chg[0].HasResponded );

		system.debug ('TEST>>>> deleting Opp #2...');

		// delete opp for con2
		delete testOpp2;
		
		// assert con2 still mbr of camp. w/ responded
		testCmbr1Chg = [Select Id, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon2.Id];
		system.assertEquals ('Responded' , testCmbr1Chg[0].Status );
		system.assertEquals (True , testCmbr1Chg[0].HasResponded );
		
	}

	
	static testMethod void OppToCampaign_NotCampMbr () {	

		// given a contact who's not a member of a campaign at all
		// check that adding an Opp sourced to that campaign
		// will add contact to campaign as responded

		system.debug ('TEST>>>> adding contact #3');

		Contact testCon3 = ONEN_UnitTestData.CreateTestContact(3);
		insert testCon3;		

		system.debug ('TEST>>>> adding campaign');
		
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp1 = new Campaign (
			Name = 'Test Campaign 1',
			IsActive = True
		);
		insert testCamp1;

		system.debug ('TEST>>>> adding Opp #3 for Con #3 as closedWon, no Camp');
		
		// insert an Opp for con3 closed won but no campaign
		Opportunity testOpp3 = New Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name = 'Test Opp 3',
			Amount = 25,
			CloseDate = system.Today(),
			StageName = 'Prospecting',
			CR_Contact_Id__c = testCon3.Id,
			CR_Contact_Role__c = 'Individual Donor'
		);
		insert testOpp3;
		
		// assert con3 not yet mbr of camp. 
		CampaignMember[] testCmbr1Chg = [Select Id, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon3.Id];
		system.assertEquals ( 0 , testCmbr1Chg.Size() );		

		system.debug ('TEST>>>> updating Opp #3 w/ Camp #1...');

		// update opp w/ campaign
		testOpp3.CampaignId = testCamp1.Id;
		update testOpp3;
		
		// assert con3 mbr of camp w/ 'Responded' 
		testCmbr1Chg = [Select Id, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon3.Id];
		system.assertEquals ( 'Sent' , testCmbr1Chg[0].Status );
		system.assertEquals (False , testCmbr1Chg[0].HasResponded );
		
		testOpp3.StageName = 'Closed Won';
		update testOpp3;
		
		CampaignMember[] testCmbr2Chg = [Select Id, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id AND ContactId = :testCon3.Id];
		system.assertEquals (WithOppStatus , testCmbr2Chg[0].Status );
		system.assertEquals (True , testCmbr2Chg[0].HasResponded );
		
	}
	
	static TestMethod void testOppToCampaignLargeSet () {

		set<id> ConIds = new set<id> ();
		set<id> ConIDsInCM = new set<id> ();

		integer howMany = 50; 

		list<Contact> TestContacts = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany );
		
		system.debug ('returned contacts, inserting..');
		
		insert TestContacts;
		
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp1 = new Campaign (
			Name = 'Test Campaign 1',
			IsActive = True
		);

		system.debug ('adding 1 test campaign...');
		insert testCamp1;
		
		// now add an opp for each contact, closedwon, for the campaign
		list<Opportunity> OppsToAdd = ONEN_UnitTestData.OppsForContactList (TestContacts,testCamp1.id,'Closed Won',system.Today(),50,GiftRectype,null);
		list<Opportunity> MoreOppsToAdd = ONEN_UnitTestData.OppsForContactList (TestContacts,testCamp1.id,'Closed Won',system.Today(),50,GiftRectype,null);
		
		// let's add an additional opportunity on an existing contact, to make sure we don't fail with dup CampaignMembers
		OppsToAdd.addAll(MoreOppsToAdd);

		system.debug ('got list of Opps, inserting...' );

		test.StartTest();
		insert OppsToAdd;
		test.StopTest();
				
		// test we have the right number of opps
		system.assertEquals ( howMany*2 , OppsToAdd.size() );

		// now query for what should be a list of 1 campaign mbr per opp
		CampaignMember[] CMsCreated = [Select Id, ContactId, Status, HasResponded FROM CampaignMember WHERE CampaignId = :testCamp1.Id];
		
		// test we have the right number of CM's
		system.assertEquals (howMany, CMsCreated.size() );

		// now get a list of all the con ids created
		for ( Contact thisCon : TestContacts ) {
			ConIds.add (thisCon.id);	
		}
		
		// and test that the CMs are for the right contacts!
		for ( CampaignMember thisCM : CMsCreated ) {
			ConIDsInCM.add (thisCM.ContactId);
		}		
		
		// the two Sets should be identical, since they're unordered lists that should contain the same id's
		system.assertEquals (ConIds,ConIDsInCM);
		
	}

}