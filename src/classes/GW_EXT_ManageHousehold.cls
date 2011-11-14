// Written by Ryan Foster, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Ryan Foster
* @date 11/10/2011
* @description This class is the VF page extension for the Manage Household interface. This allows users to
* setup their household members, name, and greeting before creating the household. It will also allow the user
* to set the address on the household.
*
*/
public with sharing class GW_EXT_ManageHousehold {

	public ONEN_Household__c hh;
	public List<Contact> hhMembers;
	public Id conId;
	public Contact con;
	public set<Id> activeConIds;
	public map<Id, Contact> activeContacts;
	
	public map<String, Id> viableAddresses;
	public Id activeAddressConId;
	public string activeStreet;
	public string activeCity;
	public string activePostalCode;
	public string activeState;
	public string activeCountry;
	
	private GW_Householding gwhh = new GW_Householding();
	private string conSelect = 'SELECT Id, FirstName, LastName, Salutation, Name, Not_in_HH_Name__c, ONEN_Household__c, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry FROM Contact ';
	
    public GW_EXT_ManageHousehold(ApexPages.StandardController controller) {
    	
    	activeConIds = new set<id>();
    	activeContacts = new map<Id, Contact>();
    	viableAddresses = new map<String, Id>();
    	
        hh = (ONEN_Household__c)controller.getRecord();
        
        //Get the contact id from the query if present
        conId = ApexPages.currentPage().getParameters().get('cid');
        //if we have a contact id, get the contact
        if (conId != null) {
        	con = Database.query(conSelect + 'WHERE Id = \''+conId+'\'');
        	activeConIds.add(conId);
        	activeContacts.put(con.id, con);
        }
        
        //if we are an existing household, get the members
        if (hh.Id != Null) {
        	getHHMembers();
        	if (!hhMembers.isEmpty()) {
        		for (Contact con : hhMembers) {
        			activeConIds.add(con.id);
        		}
        		activeContacts.putAll(hhMembers);
        		for (Id cid : activeContacts.keySet()) {
        			//set the active address fields
        			setActiveAddress(cid);
        		}
        	}
        }
        
        
    }
	
	/*******************************************************************************************************
	* @description Method to return up to 20 contacts with names similar to a passed in string. Filters out
	* contacts that have already been added to the household.
	* @param subString the substring to filter by 
    * @return list<Contact>
    ********************************************************************************************************/
	public list<Contact> findContacts(string subString) {
		String whereClause = 'WHERE Name LIKE \'%'+subString+'%\' AND Id NOT IN :activeConIds LIMIT 20';
		return database.query(conSelect + whereClause);
	}
	
	/*******************************************************************************************************
	* @description add a contact to the household by id.
	* @param Id cid the id to add. 
    * @return Boolean
    ********************************************************************************************************/
	public boolean addContact(Id cid) {
		
		String whereClause = 'WHERE Id = \''+cid+'\'';
		list<Contact> con = Database.query(conSelect + whereClause);
		if (!con.isEmpty()) {
			activeConIds.add(con[0].Id);
        	activeContacts.put(con[0].id, con[0]);
        	
        	return true;
		}
		return false;
		
	}
	
	/*******************************************************************************************************
	* @description add a contact to the household by id along with all of the contacts in the same
	* household.
	* @param Id cid the id to add. 
    * @return Boolean
    ********************************************************************************************************/
	public boolean addContactWithHousehold(Id cid) {
		
		String whereClause = 'WHERE Id = \''+cid+'\'';
		list<Contact> con = Database.query(conSelect + whereClause);
		if (!con.isEmpty()) {
			activeConIds.add(con[0].Id);
        	activeContacts.put(con[0].id, con[0]);
        	
        	// check for household then find and add contacts
        	if (con[0].ONEN_Household__c != null) {
        		whereClause = 'WHERE ONEN_Household__c = \''+con[0].ONEN_Household__c+'\'';
        		list<Contact> hhcons = Database.query(conSelect + whereClause);
        		if (!hhcons.isEmpty()) {
        			for (Contact hhcon : hhcons) {
        				activeConIds.add(hhcon.Id);
        				activeContacts.put(hhcon.id, hhcon);
        			}
        		}
        	}
        	
        	return true;
		}
		return false;
		
	}
	
	/*******************************************************************************************************
	* @description set the active address from the address fields on a contact.
	* @param Id cid the id of the contact to select the address from. 
    * @return Boolean
    ********************************************************************************************************/
	public boolean setActiveAddress(Id cid) {
		Contact con = (activeContacts.containsKey(cid)) ? activeContacts.get(cid) : null;
		if (con == null) return false;
		activeAddressConId = con.id;
		activeStreet = con.OtherStreet;
		activeCity = con.OtherCity;
		activeState = con.OtherState;
		activePostalCode = con.OtherPostalCode;
		activeCountry = con.OtherCountry;
		return true;
	}
	
	/*******************************************************************************************************
	* @description iterate over the active contacts and find all good addresses
	* @return list<Contact> list of contacts with viable addresses
    ********************************************************************************************************/
	public list<Contact> getViableAddresses() {
		list<Contact> retCons = new list<contact>();
		if (activeContacts.isEmpty()) return retCons;
		
		list<Contact> cons = Database.query(conSelect + 'WHERE id IN :activeConIds');
		
		for (Contact con : cons) {
			if (con.OtherStreet != null && con.OtherCity != null && con.OtherState != null) {
				string country = (con.OtherCountry != null) ? con.OtherCountry : '';
				string addressString = con.OtherStreet + con.OtherCity + con.OtherState + string.valueOf(con.OtherPostalCode);
				
				// regex pattern for getting all white space 
				pattern whtspc = pattern.compile('[\\s]');
				
				//find whitespace
				matcher matchWhtSpc = whtspc.matcher(addressString);
				
				//replace whitespace
				addressString = matchWhtSpc.replaceAll('');
				
				if (!viableAddresses.containsKey(addressString)) retCons.add(con);
				viableAddresses.put(addressString, con.id);
				
			}
		}
		return retCons;
	}
	
	/*******************************************************************************************************
	* @description Returns a formulated string based on the contacts in the household
	* @return String The name of the household based on the contacts used.
    ********************************************************************************************************/
    public string getHHName() {
    	String name;
    	if (!activeContacts.isEmpty()) {
    		list<Contact> sorted = sortingList();
    		name = gwhh.getHHName(sorted);
    	}
    	return name;
    }
    
    /*******************************************************************************************************
	* @description Returns a formulated string based on the contacts in the household (there is a method
	* because eventually it will be a javascript remoting method)
	* @return String The name of the household based on the contacts used.
    ********************************************************************************************************/
    public string getHHGreeting() {
    	String name;
    	if (!activeContacts.isEmpty()) {
    		list<Contact> sorted = sortingList();
    		name = gwhh.getHHGreeting(sorted);
    	}
    	return name;
    }
    
    /*******************************************************************************************************
	* @description Simply queries the list of activeContact ids so that the default sorting is used. This 
	* is to make it consistant with the sorting of the names that the trigger uses.
	* @return list<Contact> A sort list of contacts.
    ********************************************************************************************************/
	private list<Contact> sortingList() {
		list<Contact> cons = new list<contact>();
		if (!activeContacts.isEmpty()) {
			cons = Database.query(conSelect + 'WHERE Id IN :activeConIds');
		}
		return cons;
	}
	
	public void getHHMembers() {
		string wc = (conId != Null) ? ' or Id=\''+conId+'\'' : '';
		hhMembers = Database.query(conSelect+'WHERE ONEN_HouseHold__c =\''+hh.id+'\''+wc);
	}
	
	
	public void save() {
		
		// Insert Household
		upsert hh;
		
		if (!activeContacts.isEmpty()) {
			
			// If we haven't yet set the active address attempt to do so now
			if (activeAddressConId == null) {
				list<Contact> conads = getViableAddresses();
				if (!conads.isEmpty()) setActiveAddress(conads[0].id);
			}
			
			for (Contact con : activeContacts.values()) {
				
				// Set Addresses on Contacts
				if (activeAddressConId != null) {
					con.OtherStreet = activeStreet;
					con.OtherCity = activeCity;
					con.OtherState = activeState;
					con.OtherPostalCode = activePostalCode;
					con.OtherCountry = activeCountry;
				}
				
				// Set household on contacts
				con.ONEN_Household__c = hh.id;
				
				update con;
			}
		}
	}
	
	// TEST METHOD
    public static testMethod void testExistingHH() {
    	
    	ONEN_Household__c hh = new ONEN_Household__c(
    		Name = 'test_hh'
    		);
    	insert hh;
    	
    	Contact con = new Contact(
    		FirstName = 'David',
    		LastName = 'TestContactASDF',
    		email = 'testemail@groundwiretest.org',
    		ONEN_Household__c = hh.id,
    		OtherStreet = '1234 Testing Drive Suite 1000',
    		OtherCity = 'Seattle',
    		OtherState = 'WA',
    		OtherPostalCode = '98101',
    		OtherCountry = 'USA'
    		);
    	insert con;
    	
    	Test.startTest();
        ApexPages.StandardController sc = new ApexPages.standardController(hh);
        
        GW_EXT_ManageHousehold ext = new GW_EXT_ManageHousehold(sc);
        
        system.assertEquals(false, ext.hhMembers.isEmpty());
        
        //test active address variables are set
        system.assertEquals(con.OtherStreet, ext.activeStreet);
        system.assertEquals(con.OtherState, ext.activeState);
        system.assertEquals(con.OtherCity, ext.activeCity);
        system.assertEquals(con.OtherPostalCode, ext.activePostalCode);
        system.assertEquals(con.OtherCountry, ext.activeCountry);
        
        //test name
        system.assertEquals('David TestContactASDF', ext.getHHName());
        
        //test greeting
        system.assertEquals('David', ext.getHHGreeting());
        
        Test.stopTest();
    }
    
    public static testMethod void testNewHH() {
    	
    	ONEN_Household__c hh = new ONEN_Household__c(
    		Name = 'test_hh'
    		);
    	
    	
    	Contact con = new Contact(
    		LastName = 'TestContactASDF',
    		email = 'testemail@groundwiretest.org',
    		OtherStreet = '1234 Testing Drive Suite 1000',
    		OtherCity = 'Seattle',
    		OtherState = 'WA',
    		OtherPostalCode = '98101',
    		OtherCountry = 'USA'
    		);
    	insert con;
    	
    	Contact con2 = new Contact(
    		LastName = 'TestContact2 ',
    		email = 'testemail2@groundwiretest.org',
    		OtherStreet = 'Drastically Different',
    		OtherCity = 's',
    		OtherState = 'd',
    		OtherPostalCode = '1',
    		OtherCountry = 'b'
    		);
    	insert con2;
    	
    	Test.startTest();
        ApexPages.StandardController sc = new ApexPages.standardController(hh);
        
        ApexPages.currentPage().getParameters().put('cid', con.id);
        
        GW_EXT_ManageHousehold ext = new GW_EXT_ManageHousehold(sc);
        
        //make sure we got the contact
        system.assertEquals(con.id, ext.conId);
        system.assertNotEquals(null, ext.con);
        
        system.assertEquals(null, ext.hhMembers);
        system.assertEquals(null, ext.hh.id);
        
        //test that active address IS NOT set
        system.assertNotEquals(con.OtherStreet, ext.activeStreet);
        
        // select one and add it
        ext.addContact(con2.id);
        
        // verify that we receive false when we attempt to add a bad contact
        system.assertEquals(false, ext.addContact('01pU0000000h6LK'));
        system.assertEquals(false, ext.addContactWithHousehold('01pU0000000h6LK'));
        
        //save
        ext.save();
        
        // verify that we have a household id
        system.assertNotEquals(null, ext.hh.id);
        
        // Get contacts in household
        list<Contact> householdMembers = [SELECT Id, Name, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry, ONEN_Household__c FROM Contact WHERE ONEN_Household__c = :ext.hh.id];
        
        system.assertEquals(2, householdMembers.size());
        
        // Check that the addresses match
        system.assertEquals(householdMembers[0].OtherStreet, householdMembers[1].OtherStreet);
        system.assertEquals(householdMembers[0].OtherCity, householdMembers[1].OtherCity);
        system.assertEquals(householdMembers[0].OtherState, householdMembers[1].OtherState);
        system.assertEquals(householdMembers[0].OtherPostalCode, householdMembers[1].OtherPostalCode);
        system.assertEquals(householdMembers[0].OtherCountry, householdMembers[1].OtherCountry);
        
        Test.stopTest();
    }
    
    public static testMethod void testFindAndAddContact() {
    	
    	ONEN_Household__c hh = new ONEN_Household__c(
    		Name = 'test_hh'
    		);
    	
    	ONEN_Household__c existingHH = new ONEN_Household__c (
    		Name = 'existing hh'
    		);
    	insert existingHH;
    	
    	Contact con = new Contact(
    		FirstName = 'John',
    		LastName = 'TEST abc Monkey',
    		email = 'testemail@groundwiretest.org',
    		OtherStreet = '1234 Testing Drive Suite 1000',
    		OtherCity = 'Seattle',
    		OtherState = 'WA',
    		OtherPostalCode = '98101',
    		OtherCountry = 'USA'
    		);
    	insert con;
    	
    	Contact con2 = new Contact(
    		FirstName = 'Mike',
    		LastName = 'TEST Monkey abc',
    		email = 'testemail@groundwiretest.org',
    		OtherStreet = '1234 Testing Drive Suite  1000',
    		OtherCity = 'Seattle ',
    		OtherState = ' WA',
    		OtherPostalCode = '98101',
    		OtherCountry = 'USA '
    		);
    	insert con2;
    	
    	Contact con3 = new Contact(
    		FirstName = 'Cheryl',
    		LastName = 'ABC TEST Monkey',
    		email = 'testemail@groundwiretest.org',
    		OtherStreet = '54321 Anderson',
    		OtherCity = 'Kirkland',
    		OtherState = 'WA',
    		OtherPostalCode = '98034'
    		);
    	insert con3;
    	
    	Contact con4 = new Contact(
    		FirstName = 'Toivo',
    		LastName = 'abc TEST Monkey',
    		email = 'testemail@groundwiretest.org'
    		);
    	insert con4;
    	
    	Contact con5 = new Contact(
    		FirstName = 'Kelley',
    		LastName = 'adc TEST Monkey',
    		email = 'testemail@groundwiretest.org'
    		);
    	insert con5;
    	
    	Contact conWithHH = new Contact (
    		FirstName = 'Andy',
    		LastName = 'David WithHousehold',
    		email = 'testEmail@groundwiretest2.org',
    		ONEN_Household__c = existingHH.id
    		);
    	insert conWithHH;
    	
    	Contact conWithHH2 = new Contact (
    		FirstName = 'Cheryl',
    		LastName = 'WithHousehold',
    		email = 'testEmail@groundwiretest3.org',
    		ONEN_Household__c = existingHH.id
    		);
    	insert conWithHH2;
    	
    	Test.startTest();
        ApexPages.StandardController sc = new ApexPages.standardController(hh);
        
        ApexPages.currentPage().getParameters().put('cid', con2.id);
        
        GW_EXT_ManageHousehold ext = new GW_EXT_ManageHousehold(sc);
        
        list<Contact> cQ = ext.findContacts('abc');
        
        Contact ca = [SELECT Id, OtherStreet FROM Contact WHERE id = :con2.id];
        
        // make sure we only got three
        system.assertEquals(3, cQ.size());
        
        // select one and add it
        ext.addContact(cQ[1].Id);
        
        string hhName = ext.getHHName();
        string hhGreeting = ext.getHHGreeting();
        
        //test the name
        system.assertEquals('Mike TEST Monkey abc and Cheryl ABC TEST Monkey', hhName);
        system.assertEquals('Mike and Cheryl', hhGreeting);
        
        // verify that the contact was added
        system.assertEquals(2, ext.activeConIds.size());
        system.assertEquals(true, ext.activeConIds.contains(cQ[1].Id));
        
        cQ = ext.findContacts('zzzzzz');
        
        system.assertEquals(0, cQ.size());
        
        // add more contacts with different addresses
        ext.addContact(con.id);
        ext.addContact(con2.id);
        ext.addContact(con3.id);
        
        system.assertEquals(3, ext.activeConIds.size());
        
        // find viable addresses
        list<Contact> adds = ext.getViableAddresses();
        
        //verify that we found two valid addresses even though the matches aren't exactly the same
        system.AssertEquals(2, ext.viableAddresses.size());
        system.AssertEquals(2, adds.size());
        
        // now test adding a contact with its existing household members
        ext.addContactWithHousehold(conWithHH.id);
        
        // We should now have 5 total hh members displayed
        system.assertEquals(5, ext.activeConIds.size());
        
        // We should also check that the correct contact got added
        system.assertEquals(true, ext.activeContacts.containsKey(conWithHH2.id));
        system.assertEquals(conWithHH2.id, ext.activeContacts.get(conWithHH2.id).id);
        
        Test.stopTest();
    	
    }
    
	
}