// Written by Dave Habib, copyright (c) 2011 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
public with sharing class GW_LeadMaintenance {

	// when inserting/updating a lead, we do some minor field fixups:
	// - company name, if not provided.
	// - copying address fields to home address fields, if flag set to home.
	public static void LeadFieldFixups(list<Lead> listLead, boolean isInsert) {		
		for (Lead l : listLead) {
			// add company name if not provided
			if (l.Company == NULL || l.Company == '') {			
				l.Company = ONEN_Constants.NOT_PROVIDED_LABEL;
			}
	
			// if Address flag is set, and Home address isn't filled out, put the main address in home fields
			if (isInsert && l.Address_Flag__c == 'Home' && l.Home_Street__c == null) {
				//swap addresses
				l.Home_Street__c = l.Street;
				l.Home_City__c = l.City;
				l.Home_State__c = l.State;
				l.Home_PostalCode__c = l.PostalCode;
				l.Home_Country__c = l.Country;
				l.Home_Phone__c = l.Phone;
				//set main address to null
				l.Street = null;
				l.City = null;
				l.State = null;
				l.PostalCode = null;
				l.Country = null;
				l.Phone = null;
			}
		}
	}	


	// after a lead is inserted, add them to a Campaign if one was specified.
	public static void NewLeadAddToCampaign(list<Lead> listLead) {
		
		Map<Id,Lead> leadsToProcess = new Map<Id, Lead>();
		for (Lead l : listLead) {
			if (l.Campaign_Id__c != NULL || l.Contact_Id__c != NULL) {
				leadsToProcess.put(l.id, l);
			}
		}

		if (leadsToProcess.size() > 0) { 			
			List<CampaignMember> membershipRecords = new list<CampaignMember>();
			for(Lead thisLead : leadsToProcess.values()) {
				if (thisLead.Campaign_Id__c != NULL) {	
					if (thisLead.Contact_Id__c != NULL) {
						CampaignMember cmContact = new CampaignMember (				
							CampaignId=thisLead.Campaign_Id__c,
							ContactId=thisLead.Contact_Id__c			
						);
						if (thisLead.Campaign_Member_Status__c!=null) {
							cmContact.Status=thisLead.Campaign_Member_Status__c;
						}
						membershipRecords.add(cmContact);
					} else {
						CampaignMember cmLead = new CampaignMember (				
							CampaignId=thisLead.Campaign_Id__c,
							LeadId=thisLead.Id			
						);
						if (thisLead.Campaign_Member_Status__c!=null) {
							cmLead.Status=thisLead.Campaign_Member_Status__c;
						}
						membershipRecords.add(cmLead);
					}	
				}	
			}
			
			if (membershipRecords.size()>0) {			
				GW_CampaignMember.UpsertCM(membershipRecords);
			}
		}
	}
	
	
////////////////////////////////////////////////////////////////////////////
// TEST CODE
////////////////////////////////////////////////////////////////////////////

	static testMethod void TestLeadAdd() {	 

		//create first contact
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen'		
		);
		insert firstLead;
		
		Lead thisLead = [select Company from Lead where Id =:firstLead.id];

		//the Company should be not provided
		System.assertEquals(ONEN_Constants.NOT_PROVIDED_LABEL,thisLead.Company);
		
		//create second contact
		Lead secondLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company = 'Test Company'		
		);
		insert secondLead;
		
		Lead thisSecondLead = [select Company from Lead where Id =:secondLead.id];

		//the company should be what we set
		System.assertEquals('Test Company',thisSecondLead.Company);
		
		//blank out company
		thisSecondLead.Company = '';
		
		update thisSecondLead;
		
		Lead thisSecondLeadAfterUpdate = [select Company from Lead where Id =:secondLead.id];

		//the company should be not provided
		System.assertEquals(ONEN_Constants.NOT_PROVIDED_LABEL,thisSecondLeadAfterUpdate.Company);
	}
	
	
	//test to see that nothing happens if the address flag isn't set
	public static testMethod void testLeadNullAddressFlag() {
		
		String leadStreet = '123 Elm St.';
		String leadCity = 'Seattle';
		String leadState = 'WA';
		String leadPostalCode = '98107';
		String leadCountry = 'USA';
		String leadPhone = '206-888-9999';
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Street=leadStreet,
			City=leadCity,
			State=leadState,
			PostalCode=leadPostalCode,
			Country=leadCountry,
			Phone=leadPhone,
			Address_Flag__c=null
		);

		insert firstLead;
		
		Lead firstLeadAfterUpdate = [select id,Street,City,State,PostalCode,Country,Phone,Home_Street__c,Home_City__c,Home_State__c,Home_PostalCode__c,Home_Country__c,Home_Phone__c from Lead where Id=:firstLead.Id];
		//check main address fields
		system.assertEquals(leadStreet,firstLead.Street);
		system.assertEquals(leadCity,firstLead.City);
		system.assertEquals(leadState,firstLead.State);
		system.assertEquals(leadPostalCode,firstLead.PostalCode);
		system.assertEquals(leadCountry,firstLead.Country);
		system.assertEquals(leadPhone,firstLead.Phone);
		//check home address fields
		system.assertEquals(null,firstLead.Home_Street__c);
		system.assertEquals(null,firstLead.Home_City__c);
		system.assertEquals(null,firstLead.Home_State__c);
		system.assertEquals(null,firstLead.Home_PostalCode__c);
		system.assertEquals(null,firstLead.Home_Country__c);
		system.assertEquals(null,firstLead.Home_Phone__c);
		
	}
	
	
	//test to see that a home address will get moved from main to home fields
	public static testMethod void testLeadHomeAddressFlag() {
		
		String leadStreet = '123 Elm St.';
		String leadCity = 'Seattle';
		String leadState = 'WA';
		String leadPostalCode = '98107';
		String leadCountry = 'USA';
		String leadPhone = '206-888-9999';
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Street=leadStreet,
			City=leadCity,
			State=leadState,
			PostalCode=leadPostalCode,
			Country=leadCountry,
			Phone=leadPhone,
			Address_Flag__c='Home'
		);

		insert firstLead;
		
		Lead firstLeadAfterUpdate = [select id,Street,City,State,PostalCode,Country,Phone,Home_Street__c,Home_City__c,Home_State__c,Home_PostalCode__c,Home_Country__c,Home_Phone__c from Lead where Id=:firstLead.Id];
		//check main address
		system.assertEquals(null,firstLeadAfterUpdate.Street);
		system.assertEquals(null,firstLeadAfterUpdate.City);
		system.assertEquals(null,firstLeadAfterUpdate.State);
		system.assertEquals(null,firstLeadAfterUpdate.PostalCode);
		system.assertEquals(null,firstLeadAfterUpdate.Country);
		system.assertEquals(null,firstLeadAfterUpdate.Phone);
		//check home address
		system.assertEquals(leadStreet,firstLeadAfterUpdate.Home_Street__c);
		system.assertEquals(leadCity,firstLeadAfterUpdate.Home_City__c);
		system.assertEquals(leadState,firstLeadAfterUpdate.Home_State__c);
		system.assertEquals(leadPostalCode,firstLeadAfterUpdate.Home_PostalCode__c);
		system.assertEquals(leadCountry,firstLeadAfterUpdate.Home_Country__c);
		system.assertEquals(leadPhone,firstLeadAfterUpdate.Home_Phone__c);
		
	}


	//test to see that home address won't move if home is selected and Home address
	//isn't null--meaning someone entered that data
	public static testMethod void testLeadHomeAddressFlagWithHomeAddress() {
		
		String leadStreet = '123 Elm St.';
		String leadCity = 'Seattle';
		String leadState = 'WA';
		String leadPostalCode = '98107';
		String leadCountry = 'USA';
		String leadPhone = '206-888-9999';
		
		String leadHomeStreet = '123 Oak St.';
		String leadHomeCity = 'Portland';
		String leadHomeState = 'OR';
		String leadHomePostalCode = '97443';
		String leadHomeCountry = 'USA';
		String leadHomePhone = '206-777-0000';
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Street=leadStreet,
			City=leadCity,
			State=leadState,
			PostalCode=leadPostalCode,
			Country=leadCountry,
			Phone=leadPhone,
			Address_Flag__c='Home',
			Home_Street__c=leadHomeStreet,
			Home_City__c=leadHomeCity,
			Home_State__c=leadHomeState,
			Home_PostalCode__c=leadHomePostalCode,
			Home_Country__c=leadHomeCountry,
			Home_Phone__c=leadHomePhone
		);

		insert firstLead;
		
		Lead firstLeadAfterUpdate = [select id,Street,City,State,PostalCode,Country,Phone,Home_Street__c,Home_City__c,Home_State__c,Home_PostalCode__c,Home_Country__c,Home_Phone__c from Lead where Id=:firstLead.Id];
		//check main address
		system.assertEquals(leadStreet,firstLeadAfterUpdate.Street);
		system.assertEquals(leadCity,firstLeadAfterUpdate.City);
		system.assertEquals(leadState,firstLeadAfterUpdate.State);
		system.assertEquals(leadPostalCode,firstLeadAfterUpdate.PostalCode);
		system.assertEquals(leadCountry,firstLeadAfterUpdate.Country);
		system.assertEquals(leadPhone,firstLeadAfterUpdate.Phone);
		//check home address
		system.assertEquals(leadHomeStreet,firstLeadAfterUpdate.Home_Street__c);
		system.assertEquals(leadHomeCity,firstLeadAfterUpdate.Home_City__c);
		system.assertEquals(leadHomeState,firstLeadAfterUpdate.Home_State__c);
		system.assertEquals(leadHomePostalCode,firstLeadAfterUpdate.Home_PostalCode__c);
		system.assertEquals(leadHomeCountry,firstLeadAfterUpdate.Home_Country__c);
		system.assertEquals(leadHomePhone,firstLeadAfterUpdate.Home_Phone__c);		
	}


	/*********************************************************************************
	* Test creation of a lead and connection to a campaign
	*********************************************************************************/
	public static testMethod void testLeadOnCampaignNoStatus() {
		
		Campaign firstCampaign = new Campaign (
			Name='testcampaign'			
		);

		insert firstCampaign;
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Campaign_Id__c=firstCampaign.id	
		);

		insert firstLead;
		system.debug('firstLead.Id: ' + firstLead.Id);
		CampaignMember[] firstCampaginMember = [select id,leadid,status from CampaignMember where CampaignId =:firstCampaign.id and LeadId=:firstLead.Id];
		system.debug('firstcampaignmember: ' + firstCampaginMember);
		system.assertequals(1,firstCampaginMember.size());
	}
	
	public static testMethod void testLeadOnCampaignValidStatus() {
		
		Campaign firstCampaign = new Campaign (
			Name='testcampaign'			
		);

		insert firstCampaign;
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Campaign_Id__c=firstCampaign.id,
			Campaign_Member_Status__c='Responded'	
		);

		insert firstLead;
		//system.debug('firstLead.Id: ' + firstLead.Id);
		CampaignMember[] firstCampaginMember = [select id,leadid,status from CampaignMember where CampaignId =:firstCampaign.id and LeadId=:firstLead.Id];
		//system.debug('firstcampaignmember: ' + firstCampaginMember);
		system.assertequals(1,firstCampaginMember.size());
	}
	
	public static testMethod void testLeadOnCampaignInValidStatus() {
		
		Campaign firstCampaign = new Campaign (
			Name='testcampaign'			
		);

		insert firstCampaign;
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Campaign_Id__c=firstCampaign.id,
			Campaign_Member_Status__c='NeverHeardOfHim'	
		);

		insert firstLead;
		//system.debug('firstLead.Id: ' + firstLead.Id);
		CampaignMember[] firstCampaginMember = [select id,leadid,status from CampaignMember where CampaignId =:firstCampaign.id and LeadId=:firstLead.Id];
		//system.debug('firstcampaignmember: ' + firstCampaginMember);
		system.assertequals(1,firstCampaginMember.size());
	} 

}