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

	public ONEN_Household__c hh{get; set;}
	public String ctrlName {
		get {
			return GW_Utilities.InManagedPackage == true ? 'GWBase__GW_EXT_ManageHousehold' : 'GW_EXT_ManageHousehold';
		}
	}
	public Boolean autoName {
		get {
			if (hh.Id == null && hh.Name == null) {
				return true;
			}
			return hh.Auto_HHName__c;
		}
	}
	public Boolean autoGreeting {
		get {
			if (hh.Id == null && hh.Greeting__c == null) {
				return true;
			}
			return hh.Auto_HHGreeting__c;
		}
	}
	public String hhName {
		get {
			if (autoName) {
				return getHHName();
			}
			return hh.Name;
		}
		set;
	}
	public String hhGreeting {
		get {
			if (autoGreeting) {
				return getHHGreeting();
			}
			return hh.Greeting__c;
		}
		set;
	}
	
	public Id conId;
	public Contact con;
	public map<Id, Contact> activeContacts;
	public set<Contact> removeContacts;
	public list<Contact> insertContacts;
	
	public String jsonState {get;set;}
	public String originalState {get;set;}
	public String redirectTo {get;set;}
	
	public map<String, Id> viableAddresses;
	public boolean useAddress;
	public Id activeAddressConId;
	public string activeStreet;
	public string activeCity;
	public string activePostalCode;
	public string activeState;
	public string activeCountry;
	 
	public static string conSelect = GW_Utilities.StrAllNSPrefix('SELECT Id, FirstName, LastName, Salutation, Name, Not_in_HH_Name__c, ONEN_Household__c, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry FROM Contact ');
	
	
    public GW_EXT_ManageHousehold(ApexPages.StandardController controller) {
    	
    	activeContacts = new map<Id, Contact>();
    	removeContacts = new set<Contact>();
    	viableAddresses = new map<String, Id>();
    	insertContacts = new list<Contact>();
    	
    	Id tempHHid;
        ONEN_Household__c thh = (ONEN_Household__c)controller.getRecord();
        if (thh.Id == null) {
        	String paramHhId = ApexPages.currentPage().getParameters().get('hhid');
        	try {
        		tempHHid = paramHhId;
        	} catch (Exception e) {
        		tempHHid = null;
        	}
        } else {
        	tempHHid = thh.Id;
        }
        hh = tempHHid != Null ? getHH(tempHHid) : thh;
		
        //Get the contact id from the query if present
        conId = ApexPages.currentPage().getParameters().get('cid');
        
        list<Contact> hhMembers = getHHMembers();
        
        //if we are an existing household, get the members
        if (hh.Id != Null || conId != null) {
        	
        	if (!hhMembers.isEmpty()) {
        		activeContacts.putAll(hhMembers);
        		
        	}
        }
        
        // Set the active address
		if (!activeContacts.isEmpty()) {
			list<Id> aCids = new list<Id>();
			aCids.addAll(activeContacts.keySet());
			if (!aCids.isEmpty()) setActiveAddress(aCids[0]);
		}
        
        getViableAddresses();
        
        if (activeAddressConId == null && !viableAddresses.isEmpty()) {
        	setActiveAddress(viableAddresses.values()[0]);
        }
        
        if (activeAddressConId != null) {
        	useAddress = false;
        }
        
        jsonState = JSON.serialize(this);
        
        // If we are in edit mode, add a copy of the state to compare against
        originalState = (hh.Id == Null) ? jsonState : '';
    }
    
   	
    
	
	/*******************************************************************************************************
	* @description Method to return up to 20 contacts with names similar to a passed in string. Filters out
	* contacts that have already been added to the household.
	* @param subString the substring to filter by 
    * @return list<Contact>
    ********************************************************************************************************/
    @RemoteAction
	public static list<Contact> findContacts(string subString, String state) {
		GW_EXT_ManageHousehold gwMH = unpackState(state);
		
		string excludeIds = '';
		list<Id> activeConIds = new list<Id>();
		activeConIds.addAll(gwMH.activeContacts.keySet());
		if (!activeConIds.isEmpty()) {
			excludeIds =  'AND Id NOT IN (';
			integer i = 1;
			for (Id conId : activeConIds) {
				excludeIds += '\''+conId+'\'';
				if (i != activeConIds.size()) excludeIds += ',';
				i += 1;
			}
			excludeIds += ')';
		}
		
		String whereClause = 'WHERE Name LIKE \'%'+subString+'%\' '+excludeIds+' LIMIT 20';
		String q = GW_Utilities.StrAllNSPrefix(conSelect + whereClause);
		return database.query(q);
	}
	
	/*******************************************************************************************************
	* @description Takes a JSON string and attempts to instantiate GW_EXT_ManageHousehold using the 
	* deserialized object.
	* @param String state - A serialized copy of the page controller state. 
    * @return GW_EXT_ManageHousehold
    ********************************************************************************************************/
	private static GW_EXT_ManageHousehold unpackState(String state) {
		// There is a "bug" where not all of the classes have been loaded by apex when it attempts
		// to JSON.deserialize. The method below makes sure that the type is properly loaded when it attempts to
		// instantiate the object.
		String strState = state;
		JSONParser parser = JSON.createParser(state);
		Type wrapperType = Type.forName('GW_EXT_ManageHousehold'); 
		GW_EXT_ManageHousehold gwMH = (GW_EXT_ManageHousehold) parser.readValueAs(wrapperType);
		
    	return gwMH;
	}
	/*******************************************************************************************************
	* @description Accepcts a GW_EXT_ManageHousehold and serializes it into JSON
	* @param GW_EXT_ManageHousehold state - A copy of the page controller state. 
    * @return String
    ********************************************************************************************************/
	private static string packState(GW_EXT_ManageHousehold state) {
		return JSON.serialize(state);
	}
	
	/*******************************************************************************************************
	* @Remote add a Contact to HH by Id, optionally include Contact's HH.
	* @return JSON State.
    ********************************************************************************************************/
	@RemoteAction
	public static string remoteAddMember(Id cid, Boolean includeHH, String state) {
		GW_EXT_ManageHousehold gwMH = unpackState(state);
		Boolean status = false;
		
		if (!includeHH) {
			// If we should not include household members
			status = gwMH.addContact(cid);
		} else {
			// If we should include household members
			status = gwMH.addContactWithHousehold(cid);
		}
		
		// Update viable addresses
		gwMH.getViableAddresses();
		
		// If we don't have an address attempt to select one
		if (gwMH.useAddress == null && !gwMH.viableAddresses.isEmpty()) {
			gwMH.setActiveAddress(gwMH.viableAddresses.values()[0]);
		}
		
		return packState(gwMH);
	}
	
	/*******************************************************************************************************
	* @Remote method to remove a contact by Id
	* @return JSON state.
    ********************************************************************************************************/
	@RemoteAction
	public static string remoteRemoveMember(Id cid, String state) {
		GW_EXT_ManageHousehold gwMH = unpackState(state);
		
		gwMH.removeContact(cid);
		
		return packState(gwMH);
	}
	
	/*******************************************************************************************************
	* @Sets the naming related fields on the Household and gets the name.
	* @return JSON.
    ********************************************************************************************************/
	@RemoteAction
	public static string remoteSetNaming(Boolean aN, String nN, Boolean aG, String nG, String state) {
		GW_EXT_ManageHousehold gwMH = unpackState(state);
		
		gwMH.hh.Auto_HHName__c = aN;
		if (!aN) gwMH.hh.Name = nN;
		
		gwMH.hh.Auto_HHGreeting__c = aG;
		if (!aG) gwMH.hh.Greeting__c = nG;
		
		gwMH.hhName = gwMH.getHHName();
		
		return packState(gwMH);
	}
	
	/*******************************************************************************************************
	* @Remote method to save HH.
	* @return JSON.
    ********************************************************************************************************/
	@RemoteAction
	public static string remoteSave(String state) {
		GW_EXT_ManageHousehold gwMH = unpackState(state);
		gwMH.saveHH();
		return packState(gwMH);
	}
	
	/*******************************************************************************************************
	* @Describes ONEN_Household__c to get all of the fields, then runs a SOQL to get the household record by
	* Id with all of the fields.
	* @return ONEN_Household__c.
    ********************************************************************************************************/
	public ONEN_Household__c getHH(Id hhId) {
		Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ONEN_Household__c.fields.getMap();
		list<String> fields = new list<String>();
		fields.addAll(fieldMap.keySet());
		String hhq = 'SELECT ';
		Integer i = 1;
		for (String fld : fields) {
			hhq += fld;
			if (i != fields.size()) hhq += ', ';
			i += 1;
		}
		hhq += ' FROM ONEN_Household__c WHERE Id = \''+hhId+'\'';
		String q = GW_Utilities.StrAllNSPrefix(hhq);
		ONEN_Household__c houseHold = database.query(q);
		return houseHold;
	}
	
	/*******************************************************************************************************
	* @description add a contact to the household by id.
	* @param Id cid the id to add. 
    * @return Boolean
    ********************************************************************************************************/
	public boolean addContact(Id cid) {
		
		String whereClause = 'WHERE Id = \''+cid+'\'';
		String q = GW_Utilities.StrAllNSPrefix(conSelect + whereClause);
		list<Contact> con = Database.query(q);
		if (!con.isEmpty()) {
        	activeContacts.put(con[0].id, con[0]);
        	
        	return true;
		}
		return false;
		
	}
	
	/*******************************************************************************************************
	* @Remove a contact by Id from the active set.  Also resets the viableAddresses and activeAddress
	* @return boolean.
    ********************************************************************************************************/
	public boolean removeContact(Id cid) {
		
		Contact con = activeContacts.containsKey(cid) ? activeContacts.get(cid) : null;
		
		if (con == null) return false;
		
		// If this is an existing HH and the contact was a member, add the contact to list of removes
		if (hh.Id != null && con.ONEN_Household__c == hh.Id) {
			con.ONEN_Household__c = null;
			removeContacts.add(con);
		}
		
		// remove the contact from the active set
		activeContacts.remove(cid);
		
		if (cid == conId) conid = null;
		if (cid == activeAddressConId) {
			activeAddressConId = null;
			getViableAddresses();
			if (!viableAddresses.isEmpty()) setActiveAddress(viableAddresses.values()[0]);
		}
		
		return true;
		
	}
	
	/*******************************************************************************************************
	* @description add a contact to the household by id along with all of the contacts in the same
	* household.
	* @param Id cid the id to add. 
    * @return Boolean
    ********************************************************************************************************/
	public boolean addContactWithHousehold(Id cid) {
		
		String whereClause = 'WHERE Id = \''+cid+'\'';
		String q = GW_Utilities.StrAllNSPrefix(conSelect + whereClause);
		list<Contact> con = Database.query(q);
		if (!con.isEmpty()) {
        	activeContacts.put(con[0].id, con[0]);
        	
        	// check for household then find and add contacts
        	if (con[0].ONEN_Household__c != null) {
        		whereClause = 'WHERE ONEN_Household__c = \''+con[0].ONEN_Household__c+'\'';
        		q = GW_Utilities.StrAllNSPrefix(conSelect + whereClause);
        		list<Contact> hhcons = Database.query(q);
        		if (!hhcons.isEmpty()) {
        			for (Contact hhcon : hhcons) {
        				
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
		
		list<Id> activeConIds = new list<Id>();
		activeConIds.addAll(activeContacts.keySet());
		String q = GW_Utilities.StrAllNSPrefix(conSelect + 'WHERE id IN :activeConIds');
		list<Contact> cons = Database.query(q);
		
		for (Contact con : cons) {
			if (con.OtherStreet != null || con.OtherCity != null || con.OtherState != null || con.OtherPostalCode != null || con.OtherCountry != null) {
				
				string addressString = con.OtherStreet + con.OtherCity + con.OtherState + con.OtherPostalCode + con.OtherCountry;
				
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
    	GW_Householding gwhh = new GW_Householding();
    	String name;
    	if (!activeContacts.isEmpty()) {
    		list<Contact> sorted = sortingList();
    		sorted.addAll(insertContacts);
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
    	GW_Householding gwhh = new GW_Householding();
    	String name;
    	if (!activeContacts.isEmpty()) {
    		list<Contact> sorted = sortingList();
    		sorted.addAll(insertContacts);
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
		list<Id> sortOrder = new list<Id>();
		if (!activeContacts.isEmpty()) {
			sortOrder.addAll(activeContacts.keySet());
			sortOrder.sort();
			for (Id cid : sortOrder) {
				cons.add(activeContacts.get(cid));
			}
		}
		return cons;
	}
	
	
	/*******************************************************************************************************
	* @description Retrieves household members. If this is a new hh, retrieves fields for the passed in 
	* contact id.
	* @return list<Contact> A sort list of contacts.
    ********************************************************************************************************/
	public list<Contact> getHHMembers() {
		String q = conSelect;
		
		if (conId != null || hh.id != null) q += ' WHERE';
		if (conId != null) q += ' Id=\''+conId+'\'';
		if (conId != null && hh.id != null) q += ' or';
		if (hh.id != null) q += ' ONEN_HouseHold__c = \''+hh.id+'\'';
		String qry = GW_Utilities.StrAllNSPrefix(q);
		return Database.query(qry);
	}
	
	/*******************************************************************************************************
	* @This method is called by the remoteSave RemoteAction. This most of the work to save the
	* state of the custom interface.
	* @return void.
    ********************************************************************************************************/
	public void saveHH() {
		
		// Insert Household
		upsert hh;
		
		// Update our included contacts
		if (!activeContacts.isEmpty()) {
			
			for (Contact con : activeContacts.values()) {
				
				// Set Addresses on Contacts
				if (useAddress == true || activeAddressConId != null) {
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
		
		// Insert new contacts
		if (!insertContacts.isEmpty()) {
			for (Contact con : insertContacts) {
				con.ONEN_Household__c = hh.id;
			}
			insert insertContacts;
		}
		
		// Remove contacts from household
		if (!removeContacts.isEmpty()) {
			list<Contact> contactsToRemove = new list<Contact>();
			for (Contact con : removeContacts) {
				con.ONEN_Household__c = null;
				contactsToRemove.add(con);
			}
			update contactsToRemove;
		}
		
		
	}
	
	/*******************************************************************************************************
	* @Simply calls delete, on the correct hh, using the standard controller
	* @return PageReference.
    ********************************************************************************************************/
	public PageReference deleteHH() {
		ApexPages.StandardController sc = new ApexPages.standardController(hh);
		return sc.delete();
	}
	
	/*******************************************************************************************************
	* @Simply calls save, on the correct hh, using the standard controller
	* @return PageReference.
    ********************************************************************************************************/
	public PageReference save() {
		
		ONEN_Household__c nHH;
		if (hh.id != null) {
			nHH = getHH(hh.id);
		}
		
		ApexPages.StandardController sc = new ApexPages.standardController(hh);
		PageReference sv = sc.save();
		
		//Rollup household
		GW_OppRollups rg = new GW_OppRollups();
		rg.rollupHousehold(hh.id);
		
		if (nHH != null) {
			hh.Auto_HHGreeting__c = nHH.Auto_HHGreeting__c;
			hh.Auto_HHName__c = nHH.Auto_HHName__c;
			update hh;
		}
		
		return sv;
	}
	
	// TEST METHOD
    public static testMethod void testExistingHH() {
    	
    	ONEN_Household__c hh = new ONEN_Household__c(
    		Name = 'test_hh',
    		Auto_HHName__c = false,
    		Auto_HHGreeting__c = false
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
    	
    	ONEN_Household__c tempHH = new ONEN_Household__c();
        ApexPages.StandardController sc = new ApexPages.standardController(tempHH);
        
        // Test a bogus hhid
        ApexPages.currentPage().getParameters().put('hhid', 'sdf');
        
        GW_EXT_ManageHousehold ext = new GW_EXT_ManageHousehold(sc);
        
        //Make sure we are creating a new HH
        system.assertEquals(null, ext.hh.id);
        
        sc = new ApexPages.standardController(tempHH);
        
        // Test a good hhid
        ApexPages.currentPage().getParameters().put('hhid', hh.Id);
        ext = new GW_EXT_ManageHousehold(sc);
        
        // Make sure we correctly got the right HH
        system.assertEquals(hh.Id, ext.hh.Id);
        
        //system.assertEquals(false, ext.hhMembers.isEmpty());
        
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
        
        system.assertEquals(null, ext.hh.id);
        
        
        
        // verify that we receive false when we attempt to add a bad contact
        system.assertEquals(false, ext.addContact('01pU0000000h6LK'));
        system.assertEquals(false, ext.addContactWithHousehold('01pU0000000h6LK'));
        
        //save
        ext.saveHH();
        
        // verify that we have a household id
        system.assertNotEquals(null, ext.hh.id);
        
        sc = new ApexPages.standardController(hh);
        ApexPages.currentPage().getParameters().put('id', hh.id);
        ext = new GW_EXT_ManageHousehold(sc);
        
        system.assertEquals(1, ext.activeContacts.size());
        
        // Get contacts in household
        list<Contact> householdMembers = [SELECT Id, Name, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry, ONEN_Household__c FROM Contact WHERE ONEN_Household__c = :ext.hh.id];
        
        
        
        
        Test.stopTest();
    }
    
    public static testMethod void testFindAndAdd() {
    	
    	ONEN_Household__c hh = new ONEN_Household__c();
    	
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
        ApexPages.StandardController sc = new ApexPages.standardController(new ONEN_Household__c());
        
        ApexPages.currentPage().getParameters().put('cid', con2.id);
        ApexPages.currentPage().getParameters().put('hhid', hh.id);
        
        GW_EXT_ManageHousehold ext = new GW_EXT_ManageHousehold(sc);
        
        list<Contact> cQ = GW_EXT_ManageHousehold.findContacts('abc', ext.jsonState);
        
        Contact ca = [SELECT Id, OtherStreet FROM Contact WHERE id = :con2.id];
        
        // make sure we only got three
        system.assertEquals(3, cQ.size());
        
        // select one and add it
        ext.addContact(cQ[1].Id);
        
        string hhName = ext.getHHName();
        string hhGreeting = ext.getHHGreeting();
        
        //test the name
        system.assertEquals(true, hhName.contains('Mike'));
        system.assertEquals(true, hhName.contains('Cheryl'));
        system.assertEquals(true, hhGreeting.contains('Mike'));
        system.assertEquals(true, hhGreeting.contains('Cheryl'));
        
        // verify that the contact was added
        system.assertEquals(2, ext.activeContacts.size());
        //system.assertEquals(true, ext.activeConIds.contains(cQ[1].Id));
        
        cQ = GW_EXT_ManageHousehold.findContacts('zzzzzz', ext.jsonState);
        
        system.assertEquals(0, cQ.size());
        
        // add more contacts with different addresses
        ext.addContact(con.id);
        ext.addContact(con2.id);
        ext.addContact(con3.id);
        
        system.assertEquals(3, ext.activeContacts.size());
        
        // find viable addresses
        list<Contact> adds = ext.getViableAddresses();
        
        //verify that we found two valid addresses even though the matches aren't exactly the same
        system.AssertEquals(2, ext.viableAddresses.size());
        
        
        String jsSt = JSON.serialize(ext);
        
        // now test adding a contact with its existing household members
        String nwSt = GW_EXT_ManageHousehold.remoteAddMember(conWithHH.id, true, jsSt);
        
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // We should now have 5 total hh members displayed
        system.assertEquals(5, ext.activeContacts.size());
        
        // We should also check that the correct contact got added
        system.assertEquals(true, ext.activeContacts.containsKey(conWithHH2.id));
        system.assertEquals(conWithHH2.id, ext.activeContacts.get(conWithHH2.id).id);
        
        // now add a contact without a hh
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteAddMember(con5.id, false, jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // Add another for good measure (will use later)
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteAddMember(con4.id, false, jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // Check that the contacts got added
        system.assertEquals(true, ext.activeContacts.containsKey(con5.id));
        system.assertEquals(true, ext.activeContacts.containsKey(con4.id));
        
        // Now let us remove a contact
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteRemoveMember(con5.id, jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // Test that it was removed
        system.assertEquals(false, ext.activeContacts.containsKey(con5.id));
        
        // Test changing name
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteSetNaming(false, 'The Test123Awesomes', false, 'TestZZ1234', jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // Verify that name and greeting were set
        system.assertEquals('The Test123Awesomes', ext.hhName);
        system.assertEquals('TestZZ1234', ext.hhGreeting);
        
        // Save
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteSave(jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // query for a contact and make sure it got the correct fields set
        Contact con4q = [SELECT Id, ONEN_Household__c, OtherStreet FROM Contact WHERE Id = :con4.id];
        
        system.assertEquals(ext.hh.id, con4q.ONEN_Household__c);
        
        // Set the address to the new contact
        ext.setActiveAddress(con4.id);
        
        // Now remove another member, save, and make sure the lookup field is set to null
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteRemoveMember(con4.id, jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        // Save
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteSave(jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        con4q = [SELECT Id, ONEN_Household__c, OtherStreet FROM Contact WHERE Id = :con4.id];
        
        system.assertNotEquals(ext.hh.id, con4q.ONEN_Household__c);
        
        // Now add a completely new contact and save
        ext.insertContacts.add(new Contact(FirstName = 'Lefty', LastName = 'TestFunky123'));
        
        // Save
        jsSt = JSON.serialize(ext);
        nwSt = GW_EXT_ManageHousehold.remoteSave(jsSt);
        ext = GW_EXT_ManageHousehold.unpackState(nwSt);
        
        // Query for our new contact
        Contact newCon = [SELECT Id, ONEN_Household__c, Name FROM Contact WHERE Name = 'Lefty TestFunky123'];
        system.assertEquals(ext.hh.id, newCon.ONEN_Household__c);
        
        Id fHHid = ext.hh.id;
        
        // Cover the "standard" save
        ext.save();
        
        // Now, test delete
        ext.deleteHH();
        
        Test.stopTest();
    	
    }
    
	
}