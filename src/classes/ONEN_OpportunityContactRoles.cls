public class ONEN_OpportunityContactRoles {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    public static Id GetPrimaryContactId (Id oppID){

        Id primaryId;       

        // get the primary contract role record (if any) for this opp
        OpportunityContactRole[] conRoles = [select ContactId From OpportunityContactRole WHERE Opportunity.Id = :oppID AND IsPrimary = true];
        if (conRoles.size()>0) {
            //get the primary Contact's Id
            primaryID = conRoles[0].ContactId;
        }
        
        return primaryId;
    }
  
    public static map<Id,Id> GetPrimaryContactIdsBulk (set<id> oppIds) {
        
        // given a list of OppID's (in a set)
        // look up the primary contacts from ConRole (if any)
        // and return a map of OppID->PrimaryConID
        // looks like we can return maps from methods, although the lang reference doesn't specify you can
        
        map <Id,Id> ContactIdMap = new Map <Id,Id> ();
        
        // query for OppConRoles where primary=true and OppID in arg set
        OpportunityContactRole[] conRoles = [select OpportunityId, ContactId From OpportunityContactRole WHERE IsPrimary = true AND Opportunity.Id IN :oppIds ];
        
        // now loop through the results and build the map
        for (OpportunityContactRole thisCR : conRoles) {
            ContactIdMap.put( thisCR.OpportunityId, thisCR.ContactId );
        }
        
        return ContactIdMap;
        
    }
    
    
    public static void CreateOppConRolesBulk ( list<Opportunity> opps , list<id> ConIds ) {
    
    // new bulk-safe version of this by MS
    // given a list of opps with 'dummy' ConId and Role fields populated,
    // create ConRole records
    
    // args now expect both a map from OppId to ConId,
    // and then also a list of those same Opps as objects
    
    // moved from original spot in class GivingHistory
        
        
    //  system.debug ('class method called for ' + opps.size() + ' Opps');
        
        list<OpportunityContactRole> OCRtoCreate = new list<OpportunityContactRole> ();
        
        // first ensure that the ID stored in the opp is in fact a valid con id
            // if any of them aren't, we'll just skip 'em
        map<id, Contact> validCons = new Map<id, Contact> ([SELECT id, FirstName,ONEN_Household__c FROM Contact WHERE id IN :ConIds ]);
        //get a set of all the households for primary contact roles in this batch of opps
        set<id> allHouseholds = new set<id>();
        //loop through the primary contacts, adding the households to the set
        for (Contact primaryContact : validCons.values()) {
            if (primaryContact.ONEN_Household__c != null) {
                allHouseholds.add(primaryContact.ONEN_Household__c);
            }
        }
        //get full Contacts for the households
        map<id, Contact> validHouseholdCons = new Map<id, Contact> ([SELECT id, ONEN_Household__c FROM Contact WHERE ONEN_Household__c in :allHouseholds ]);
        //a new map to hold all the Contacts for each Households
        map<id,List<Contact>> contactsInHousehold = new Map<id,List<Contact>> ();   
        //looping through the contacts, creating/adding the hh to contact map records as necessary  
        for (Contact possibleHouseholdMember : validHouseholdCons.values()) {
            List<Contact> contactsForHousehold = new List<Contact>();
            //if the household is already represented, pull the existing list
            if (contactsInHousehold.get(possibleHouseholdMember.ONEN_Household__c)!=null) {
                contactsForHousehold = contactsInHousehold.get(possibleHouseholdMember.ONEN_Household__c);
            }
            //add this contact to the list
            contactsForHousehold.add(possibleHouseholdMember);
            //put the list in the map
            contactsInHousehold.put(possibleHouseholdMember.ONEN_Household__c,contactsForHousehold);
                            
        }
        
        // if so, create ConRoles
        // (by looping through original opps and seeing if we have a matching valid contact)
        
        // TBD we may eventually want to double check that none of these already have contact roles
        //      because users may import or enter a conid for an opp that duplicates an existing role
        //      (this would only be for a trigger other than CreateContactRoles, which only fires after insert, not after update

        for ( Opportunity thisOpp : opps ) {
            //get the primary contact
            Contact primaryContact = validCons.get(thisOpp.CR_Contact_Id__c);
            //if we have a primary contact
            if (primaryContact != null ) {
                
                //create a role for the primary contact
                OpportunityContactRole newOCR = new OpportunityContactRole (
                    OpportunityId = thisOpp.id,
                    ContactId = primaryContact.Id,
                    Role = thisOpp.CR_Contact_Role__c,
                    IsPrimary = true
                );
                
                OCRtoCreate.add (newOCR);
                //get the primary contact's household
                Id thisPrimaryContactHouseholdId = primaryContact.ONEN_Household__c;
                if(primaryContact.ONEN_Household__c!=null&&thisOpp.CR_HHroles__c){
                    List<Contact> contactsForThisOpp = new List<Contact>();
                    contactsForThisOpp = contactsInHousehold.get(thisPrimaryContactHouseholdId);
                    //if there is more than just the primary contact in the list
                    if (contactsForThisOpp.size()>1) {
                        //create a role for each contact that isn't the primary                     
                        for (Contact c : contactsForThisOpp) {
                            if (c.Id!=thisOpp.CR_Contact_Id__c) {
                                OpportunityContactRole HHSoftCreditRole = new OpportunityContactRole(
                                    OpportunityId=thisOpp.id,
                                    ContactId=c.id,
                                    Role=ONEN_Constants.OPP_GIFT_HH_DONOR_ROLE
                                );
                                OCRtoCreate.add (HHSoftCreditRole);
                            }
                        }
                    }
                    //system.debug ('ConRoles to create: ' + OCRtoCreate.size() );
                    
                }               
            }
        }
    //  system.debug ('ConRoles to create: ' + OCRtoCreate);
        insert OCRtoCreate;
        
        
        // for now we're just adding the primary role, might want to later insert roles
        // for the other HH members as well (or at least give an option via the args
        
    }
    

    public static void CheckContactRoles (list<Opportunity> listOpps) {

        // this is the logic that usually goes in the trigger
        // factored out to here so that this can be called by any of the other
        // Opp AfterInsert triggers
        // to ensure that opp creation happens first (see trigger CreateContactRoles)

        // pass in the trigger.newmap from the calling trigger
        
        //system.debug ('CheckContactRoles: CALLED');
        
        list<Opportunity> OppsToProcess = new list<Opportunity> ();
        list<id> ConIds = new list<id> ();
        
        // collect those Opps with the CR Contact ID dummy field set
        for ( Opportunity thisOpp : listOpps ) {
            if ( thisOpp.CR_Contact_Id__c != null ) {
                ConIds.add (thisOpp.CR_Contact_Id__c );
                OppsToProcess.add (thisOpp);
            }
        }
        
        //system.debug ('CheckContactRoles opps to process: ' + OppsToProcess.size() );
        
        // update those Opps
        if ( OppsToProcess.size() > 0 ) {
            CreateOppConRolesBulk ( OppsToProcess , ConIds);
        }
        
        // and record the fact that we've done this (so it won't be done again)
        //haveCheckedContactRoles = true;
        
    }
    
    
    //static variable to prevent trigger firing (from other opp updates) to update contact roles
    public static boolean runPrimaryContactRoleSync = true;

    // copy primary contact lookup to opportunity contact role
    public static void updatePrimaryOppContactRole(Map<id, Opportunity> oldMap, Map<id, Opportunity> newMap) {
      
		Map<id, list<OpportunityContactRole>> oppsAndOCRList = new Map<id, list<OpportunityContactRole>>();
		Map<id, id> oppsWithPrimaryContacts = new Map<id, id>();
		Map<id,id> rtMap = new Map<id,id>();
      
	    map<string,ConRole_Settings__c> allSettings = ConRole_Settings__c.getAll();
		
		// if contact is not in existing contact roles, add it
		for (Opportunity opp : newMap.values()) {
			if (opp.ContactId__c != oldMap.get(opp.id).ContactId__c && opp.ContactId__c != null) {
				oppsAndOCRList.put(opp.id, new list<OpportunityContactRole>());
				oppsWithPrimaryContacts.put(opp.id, opp.ContactId__c);
				rtMap.put(opp.id,opp.RecordTypeId);
			}
		}
      	
      	if (!oppsAndOCRList.isEmpty()) {
	      	//query for all of the Opportunity Contact Roles from opps with a change to Primary Contact
			List<OpportunityContactRole> existingRoles = [select id, ContactId, OpportunityId, Opportunity.RecordType.Name, isPrimary, Contact.ONEN_Household__c from OpportunityContactRole where OpportunityId in :oppsAndOCRList.keySet()];
			for (OpportunityContactRole ocr : existingRoles) {
				if (oppsAndOCRList.containsKey(ocr.OpportunityId)) {
					oppsAndOCRList.get(ocr.OpportunityId).add(ocr);
				} else {
					oppsAndOCRList.put(ocr.OpportunityId,new List<OpportunityContactRole>{ocr});
				}
			}
			
			List<OpportunityContactRole> ocrsToUpdate = new List<OpportunityContactRole>();
	      	
			// loop through all opps where primary contact has changed
			for (id oppToProcess : oppsAndOCRList.keyset()) {
				boolean primaryAlreadyExists = false;
				
				// loop through existing contact roles for this opp
				for (OpportunityContactRole ocr : oppsAndOCRList.get(oppToProcess)) {
	        		// if the primary contact for this opp matches the conrole contact, set it to primary
	        		if (ocr.ContactId == oppsWithPrimaryContacts.get(ocr.OpportunityId)) {
	        			ocr.IsPrimary = true;
	        			ocr.Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ocr.Opportunity.RecordType.Name);
	        			ocrsToUpdate.add(ocr);
	        			primaryAlreadyExists = true;
	        			//once we find the ConRole for this Primary Contact, stop looping through the OCRs
	        			break;
	        		}
		        }
		        if (!primaryAlreadyExists) {
		        	ocrsToUpdate.add(new OpportunityContactRole(opportunityId = oppToProcess, contactId = oppsWithPrimaryContacts.get(oppToProcess), isPrimary = true, role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',rtMap.get(oppToProcess)))));
		        }
	        
			}
	 		if (!ocrsToUpdate.isEmpty()) {
		 		upsert ocrsToUpdate;           
	 		}
      	}    
	}
	
	public void reconcileConRoles(List<ONEN_Household__c> hhs) {
    	
    	//turn off the trigger that fires on opp update to set con roles
    	runPrimaryContactRoleSync = false;
    	
    	List<Opportunity> oppsToUpdate = new List<Opportunity>();
    	Set<id> oppIds = new Set<id>();
    	
    	//grab the set of households for the query of ConRoles
    	set<id> hhIds = new set<id>();	
    	for (ONEN_Household__c hh : hhs) {
    		hhIds.add(hh.id);
    	}
    	
    	//find all of the opp conroles associated with the HHs from the batch query
    	//and find differences between primary OppConRole and Primary Contact on Opp and update as needed
    	for (OpportunityContactRole ocr :
    		[SELECT ContactId, OpportunityId, Opportunity.ContactId__c 
    			FROM OpportunityContactRole
    			WHERE IsPrimary = true
    			AND contact.ONEN_Household__c IN : hhIds 
    			ORDER BY LastModifiedDate ] ) {
    		
    		if (ocr.ContactId != ocr.Opportunity.ContactId__c && !oppIds.contains(ocr.OpportunityId)) {
    			Opportunity o = new Opportunity(
    				id = ocr.OpportunityId,
    				ContactId__c = ocr.ContactId
    				);
    			oppsToUpdate.add(o);
    			oppIds.add(o.id);
    		}
    		
    	}
    	
    	//process the updates
    	if (!oppsToUpdate.isEmpty()) {
    		try {
    			update oppsToUpdate;
    		} catch (exception e) {}
    	}
    }

//////////////////////////
// TEST CODE
/////////////////////////
	private static transient string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
	
	static testmethod void testNewOppCRSingle () {
		
		Contact TestCon1 = ONEN_UnitTestData.CreateTestContact (1) ;
		insert TestCon1;
		Contact[] cons = new Contact[] {TestCon1};
		
		// insert an opp for this contact
		// this method puts the ConID into the proper field in Opp
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( cons, null, 'Closed Won', System.Today(), 100 , GiftRectype,null);
		insert newOpps;
		
		// test we got one opp back:
		System.assertEquals ( 1 , newOpps.size() );
		
		// test the opp has ConRole for our contact, and that they're the Primary
		Opportunity thisOpp = newOpps[0];
		OpportunityContactRole[] thisCR = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE ContactId = :thisOpp.CR_Contact_Id__c AND OpportunityId = :thisOpp.id ];
		
		System.assertEquals ( 1 , thisCR.size() );
		System.assertEquals ( true , thisCR[0].IsPrimary ) ;		
		System.AssertEquals(TestCon1.Id, GetPrimaryContactId(thisOpp.Id));  
		
	}
	
	static testmethod void testNewOppCRHouseholds () {

		Integer sizeOfTest = 10;
		Contact[] TestCon1 = ONEN_UnitTestData.CreateMultipleTestContacts (sizeOfTest) ;
		Test.StartTest();
		insert TestCon1;
		Test.StopTest();
		List<Id> createContactIds = new List<Id>();
		for (Contact firstContact : TestCon1) {
			createContactIds.add(firstContact.Id);
		}
		Contact[] TestCon1WithHoueshold = [Select Id, ONEN_Household__c from Contact where id in :createContactIds];
		//system.debug('first contacts with hh: ' + TestCon1WithHoueshold);
		Contact[] secondContacts = ONEN_UnitTestData.CreateMultipleTestContactsInHouseholds (TestCon1WithHoueshold);
		
		insert secondContacts;
		//system.debug('second contacts: ' + secondContacts);
		
		List<Id> secondContactIds = new List<Id>();
		for (Contact secondContact : secondContacts) {
			secondContactIds.add(secondContact.Id);
		}
		//system.debug (secondContactIds);
				
		// insert an opp for this contact
		// this method puts the ConID into the proper field in Opp
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCon1, null, 'Closed Won', System.Today(), 100 , GiftRectype,null);
		insert newOpps;
		
		// test we got one opp back:
		System.assertEquals ( sizeOfTest , newOpps.size() );
		List<Id> createdOppIds = new List<Id>();
		for (Opportunity thisOpp : newOpps) {
			createdOppIds.add(thisOpp.Id);
		}
//		system.debug (newOpps[0]);
		
		// test the opp has ConRole for our contact, and that they're the Primary
		Opportunity thisOpp = newOpps[0];
		OpportunityContactRole[] theseCR = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE ContactId in :createContactIds AND OpportunityId in :createdOppIds ];
		
//		system.debug (thisCR[0]);
		
		System.assertEquals ( sizeOfTest , theseCR.size() );
		for(OpportunityContactRole thisCR : theseCR) {
			System.assertEquals ( true , thisCR.IsPrimary ) ;
			System.assertEquals ( ONEN_Constants.OPP_GIFT_DONOR_ROLE(GiftRectype) , thisCR.Role ) ;
		}
		
		
		OpportunityContactRole[] theseHouseholdCR = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE ContactId in :secondContactIds AND OpportunityId in :createdOppIds ];
		
		System.assertEquals ( sizeOfTest , theseHouseholdCR.size() );
		for(OpportunityContactRole thisHHCR : theseHouseholdCR) {
			System.assertEquals ( false , thisHHCR.IsPrimary ) ;
			System.assertEquals (ONEN_Constants.OPP_GIFT_HH_DONOR_ROLE , thisHHCR.Role ) ;
		}
		
		// test code to exercise GetPrimaryContactIdsBulk()
		map<Id,Id> mapOppIdCRId;
		set<Id> setOppId = new set<Id>(createdOppIds);
		mapOppIdCRId = GetPrimaryContactIdsBulk(setOppId);
		System.AssertEquals(mapOppIdCRId.size(), setOppId.size());		
	}

	static testmethod void testNewOppCRMany () {
		
		List<id> OppIds = new List<id> ();
		integer howMany = 50;
	
		Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
		insert TestCons;
		
		// this method puts the ConID into the proper field in Opp
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Closed Won', System.Today(), 100 , GiftRectype,null);
		Test.StartTest();
		insert newOpps;
		Test.StopTest();
		
		// test we got opps back:
		System.assertEquals ( howMany , newOpps.size() );
		
		// get a list of the opp id's created
		for ( Opportunity thisOpp : newOpps ) {
			OppIds.add (thisOpp.id);	
		}
		
		// find all corresponding opp CR's
		OpportunityContactRole[] newCRs = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId IN :OppIds ];
		
		// check we got the right number and that all of them are Primary
		System.assertEquals ( howMany , newCRs.size() );
		
		OpportunityContactRole[] newCRsPrimary = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId IN :OppIds and IsPrimary = true];
		System.assertEquals ( howMany , newCRsPrimary.size () );
		
	}
	
	static testmethod void changeContactRoleFromStdRelatedList() {
 		//tests the nightly batch update to reconcile any accidental changes to OCRs using standard list, that did not update Primary Contact on opp
 		List<ONEN_Household__c> hhs = new List<ONEN_Household__c>();
 		
 		ONEN_Household__c hh = new ONEN_Household__c(Name='The_Bromer_Residence');
 		insert hh;
 		hhs.add(hh);
 		
 		ONEN_Household__c hh2 = new ONEN_Household__c(Name='The_Andersen_Residence');
 		insert hh2;
 		hhs.add(hh2);
 		
 		Contact con = new Contact (LastName = 'Halladay_Sucks',ONEN_Household__c=hh.id);
 		insert con;
 		
 		Contact con2 = new Contact (LastName = 'Halladay_Sucks',ONEN_Household__c=hh2.id);
 		insert con2;
 		
 		Opportunity opp = new Opportunity(
 			Name='Test_Opportunity',
 			CloseDate = system.today(),
 			StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
 			Amount = 100
 			);
 		insert opp;
 		
 		OpportunityContactRole ocr = new OpportunityContactRole(
 			OpportunityId = opp.id, 
 			ContactId = con.id, 
 			Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
 			IsPrimary = true); 
 		insert ocr;
 		
 		OpportunityContactRole ocr2 = new OpportunityContactRole(
 			OpportunityId = opp.id, 
 			ContactId = con2.id, 
 			Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
 			IsPrimary = false); 
 		insert ocr2;
 		
 		ONEN_OpportunityContactRoles OCRClass = new ONEN_OpportunityContactRoles();
 		OCRClass.reconcileConRoles(hhs);
 		
 		List<Opportunity> updatedOpps = [SELECT ContactId__c FROM Opportunity WHERE id = :opp.id];
 		system.assertEquals(con.id,updatedOpps[0].ContactId__c);
 		
 		//now update to the second contact as primary and see if Primary Contact changes correctly
 		ocr.IsPrimary = false;
 		update ocr;
 		ocr2.isPrimary = true;
 		update ocr2;
 		
 		OCRClass = new ONEN_OpportunityContactRoles();
 		OCRClass.reconcileConRoles(hhs);
 		
 		List<Opportunity> updatedOpps2 = [SELECT ContactId__c FROM Opportunity WHERE id = :opp.id];
 		system.assertEquals(con2.id,updatedOpps2[0].ContactId__c);
 		
    }
}