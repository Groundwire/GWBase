// Written by Matthew Scholtz, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 01/01/2007
* @description ONEN_UnitTestData is a class that handles data for use in unit test code. These methods
* should not be used by production code.
*/
global class ONEN_UnitTestData { 

	/*******************************************************************************************************
	* @description Method that creates a Contact for use in unit test code.
	* @param n Identifies unique set of Contact field values for n values 1, 2 and 3.
	* @return A Contact record.
	*/
	global static contact CreateTestContact (integer n) {
		
		// create one contact
		// integer identifies unique set of field values
		
		Contact newCon = New Contact ();
		
		if ( n == 1 ) {
			newCon.FirstName = 'Stringer';
			newCon.LastName = 'Bell';
			newCon.OtherCity = 'Baltimore';
		} else if (n==2) {
			newCon.FirstName = 'Avon';
			newCon.LastName = 'Barksdale';
			newCon.OtherCity = 'Baltimore';
		} else if (n==3) {
			newCon.FirstName = 'Lester';
			newCon.LastName = 'Freamon';
			newCon.OtherCity = 'Baltimore';
		}
		
//		insert newCon;
		return newCon;
	}
	
	/*******************************************************************************************************
	* @description Method that creates a list of Contacts for use in unit test code.
	* @param n The number of Contacts to be added to the list.
	* @return A list of Contact records of size n.
	*/
	global static list<Contact> CreateMultipleTestContacts (integer n) {
		
		list<contact> ContactsToAdd = New list<contact> ();
		
		for (integer i=0;i<n;i++) {
			Contact newCon = New Contact (
				FirstName = 'Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
			);
			ContactsToAdd.add (newCon);
		}
		
		// testing doing the insert in the calling code - will maybe reinstate this
		//insert ContactsToAdd;
		
		return ContactsToAdd;
	}

	/*******************************************************************************************************
	* @description Method that creates a partner Contact and a Household for each Contact in a list, for use 
	* in unit test code.
	* @param firstContactList A list of contacts.
	* @return A list of contacts, with each contact being in a household with the respective contact from firstContactList.
	*/
	global static list<Contact> CreateMultipleTestContactsInHouseholds (List<Contact> firstContactList) {
		
		list<contact> ContactsToAdd = New list<contact> ();
		list<ONEN_Household__c> householdsToInsert = new list<ONEN_Household__c>();
		
		for (Contact con : firstContactList) {
			ONEN_Household__c hh = new ONEN_Household__c(Name='Foo');
			householdsToInsert.add(hh);
		}
		insert householdsToInsert;
		
		for (integer i=0;i<firstContactList.size();i++) {
			if (firstContactList[i].ONEN_Household__c == null) firstContactList[i].ONEN_Household__c = householdsToInsert[i].id;
			Contact newCon = New Contact (
				FirstName = 'Second Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle',
				ONEN_Household__c = firstContactList[i].ONEN_Household__c == null ? householdsToInsert[i].id : firstContactList[i].ONEN_Household__c
			);
			ContactsToAdd.add (newCon);
		}
		
		update firstContactList;
		
		// testing doing the insert in the calling code - will maybe reinstate this
		//insert ContactsToAdd;
		
		return ContactsToAdd;
	}

	/*******************************************************************************************************
	* @description Method that creates one Opportunity each to a given list of Contacts for use in unit test 
	* code. 
	* @param Cons A list of Contacts to add Opportunities to.
	* @param CampId A Campaign ID to link Opportunities to.
	* @param Stage An Opportunity stage.
	* @param Close An Opportunity closing date.
	* @param Amt An Opportunity amount.
	* @param rectype A record type.
	* @param oppType An Opportunity type.
	* @return A list of Opportunities associated with Cons.
	*/
	global static list<Opportunity> OppsForContactList (list<Contact> Cons, id CampId, string Stage, date Close, double Amt, string rectype, string oppType) {
	 
		// given a list of Contacts,
		// add one Opp per contact w/ the specified data
		// TBD should allow specifying rectype (optional)
	
		list<Opportunity> OppsToAdd = new list<Opportunity> ();
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',rectype);
		
		for ( Contact thisCon : Cons ) {
			Opportunity newOpp = New Opportunity (
				Name = 'Test Opp ' + thisCon.FirstName + thisCon.LastName,
				Amount = Amt,
				CloseDate = Close,
				StageName = Stage,
				CampaignId = CampId,
				CR_Contact_Id__c = thisCon.Id,
				CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',rtid)),
				type = oppType,
				RecordTypeId = rtid
			);	
			OppsToAdd.add (newOpp);
		}
		
		return OppsToAdd;
		
	}
	
	/*******************************************************************************************************
	* @description Method that returns a list of Accounts for use in unit test code.
	* @param n The number of Accounts to be returned.
	* @return A list of Accounts records of size n.
	*/
	global static list<Account> CreateMultipleTestAccounts (integer n) {
		
		list<Account> AcctsToAdd = New list<Account> ();
		
		for (integer i=0;i<n;i++) {
			Account newAcct = New Account (
				Name = 'Yet Another Org ' + i
			);
			AcctsToAdd.add (newAcct);
		}
		
		return AcctsToAdd;
	}
	
	/*******************************************************************************************************
	* @description Method that returns one Opportunity each for a given list of Accounts.
	* @param Accts A list of Accounts to add Opportunities to.
	* @param CampId A Campaign ID to link Opportunities to.
	* @param Stage An Opportunity stage.
	* @param Close An Opportunity closing date.
	* @param Amt An Opportunity amount.
	* @param rectype A record type.
	* @return A list of Opportunities associated with Accts.
	*/
	global static list<Opportunity> OppsForAccountList (list<Account> Accts, id CampId, string Stage, date Close, double Amt, string rectype) {
	
		// given a list of accounts,
		// add one Opp per acct w/ the specified data
	
		list<Opportunity> OppsToAdd = new list<Opportunity> ();
		
		// look up the id for the specified rectype
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',rectype);
		
		for ( Account thisAcct : Accts) {
			Opportunity newOpp = New Opportunity (
				AccountId = thisAcct.id,
				Name = 'Test Opp ' + thisAcct.Name,
				Amount = Amt,
				CloseDate = Close,
				StageName = Stage,
				CampaignId = CampId,
				RecordTypeId = rtid
			);	
			OppsToAdd.add (newOpp);
		}
		
		return OppsToAdd;
		
	}

	/*******************************************************************************************************
	* @description Method that returns a Campaign Member for use in unit test code.
	* @param CampId A Campaign ID.
	* @param ConId A Contact ID.
	* @param CMStatus A Campaign Member Status.
	* @return A list of Accounts records of size n.
	*/
	global static CampaignMember CreateCampaignMember (id CampId, id ConId, string CMStatus) {
	
		CampaignMember newCM = new CampaignMember (
			CampaignId = CampId,
			ContactId = ConId,
			Status = CMStatus
		);
		
		insert newCM;
		return newCm;	
		
	}
	
	/*******************************************************************************************************
	* @description Method that deletes all records in a custom setting table.
	* @param objname A custom setting table.
	*/
	global static void DeleteListCustomSettingRecs (string objname) {
		// given the name of a custom setting table, delete all the records in it
        string qstr = 'SELECT Id,Name FROM ' + objname;
        sObject[] srecs = Database.query(qstr);
        if (srecs.size() > 0) {
        	// first make sure this is really a custom setting obj
        	Schema.Sobjecttype t = srecs[0].getSObjectType();
        	Schema.Describesobjectresult d = t.getDescribe();
        	if ( d.isCustomSetting() ) {
        		// if so, delete all the recs
        		delete srecs;
        	}
        }
	}
	
}