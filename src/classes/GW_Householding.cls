/**
* @author Evan Callahan
* @date 1/1/2010
* @description Class to manage household names and addresses syncing
*/
public class GW_Householding {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// Portions written by Steve Andersen, (c) 2008 Groundwire
// Modifications by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

// Class to manage household names and addresses syncing

    // set to true if you want Mr. and Mrs. in the household name
    static final boolean includeSalutation = true;  
        
    // flags that indicate we are updating (so we can short-circuit the triggers)
    public static boolean nowUpdating = false;
    public static boolean nowCopyingAddresses = false;
    
    // lists of contacts and opps to create, passed from before trigger to after trigger
    //public static set<id> secondContactIds;
    public static contact[] secondContacts = new contact[]{};
    
    
    // fix the specified household records -- gets called when contact names or households are changed
/**
* @description fix the specified household records -- gets called when contact names or households are changed
* @param Set<Id> a set of Household object Id's 
* @return void
*/
    public void UpdateNames(Set<Id> households) {
        onen_household__c[] hhs = [select id, name, greeting__c, auto_hhName__c, auto_hhGreeting__c, 
        	(SELECT Id, Salutation, FirstName, LastName, not_in_hh_name__c 
        	from Contacts__r order by createddate limit 8)  // eight is enough? 
        	from onen_household__c where id in :households];
        onen_household__c[] emptyHH = new onen_household__c[]{};
                
        for (onen_household__c h : hhs) {
            if (h.contacts__r.size() > 0) {
	        	// set the number of members
	        	h.Member_Count__c = h.contacts__r.size();
	        	
                // update household names
                if (h.auto_hhName__c) {
                    h.name = getHHName(h.contacts__r);
                }
                if (h.auto_hhGreeting__c) {
                    h.greeting__c = getHHGreeting(h.contacts__r);
                }
            } else {
            	if (! h.name.contains('DupeBlocker Unit Test') ) {
	                emptyHH.add(h);
            	}
            }
        }   
        // update households -- the flag tells the trigger this is an apex modification
        nowUpdating = true;
        if (hhs.size() > 0) {
            update hhs;
        } 
        
        // delete empty households
        if (emptyHH.size() > 0) {
            delete emptyHH;
        } 
        nowUpdating = false;
    }

/**
* @description propogate addresses -- gets called when contact other address is changed
* @param Map<Id, contact> a map of Hosehold Id's to Contact objects 
* @return void
*/    // propogate addresses -- gets called when contact other address is changed
    public void UpdateAddresses(Map<Id, contact> households) {

        // query for all contacts in the household map
        Contact[] cons = [select id, onen_household__c, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry, primary_address__c from Contact 
        					where onen_household__c in :households.keyset() ORDER BY OtherStreet desc, OtherCity desc, OtherState desc, OtherPostalCode desc];

        Contact[] consToUpdate = new Contact[]{};
        //need a map to keep track of valid addresses so we don't overwrite null address with valid addresses already on household contacts
		map<id,contact> validAddressMap = new map<id,contact>();
		
        for (contact c : cons) {
            // grab the changed contact record for this household
            contact master = households.get(c.onen_household__c);
            
            if (validAddressMap.get(c.ONEN_Household__c) == null && (master.otherStreet != null || master.otherCity != null || master.otherState != null || master.otherPostalCode != null)) {
 	           validAddressMap.put(c.ONEN_Household__c,c);
            }
            // update the address if this is another contact
            if (c.id != master.id && (master.otherStreet != null || master.otherCity != null || master.otherState != null || master.otherPostalCode != null)) {
                c.otherStreet = master.otherStreet;
                c.otherCity = master.otherCity;
                c.otherState = master.otherState;
                c.otherPostalCode = master.otherPostalCode;
                c.otherCountry = master.otherCountry;
                if (c.primary_address__c == null) c.primary_address__c = 'Home'; 
	            consToUpdate.add(c);
            } else if (c.id == master.id && (master.otherStreet == null && master.otherCity == null && master.otherState == null && master.otherPostalCode == null)){
            	Contact conWithAddy = validAddressMap.get(c.ONEN_Household__c);
            	if (conWithAddy != null) {
	                c.otherStreet = conWithAddy.otherStreet;
	                c.otherCity = conWithAddy.otherCity;
	                c.otherState = conWithAddy.otherState;
	                c.otherPostalCode = conWithAddy.otherPostalCode;
	                c.otherCountry = conWithAddy.otherCountry;
	                if (c.primary_address__c == null) c.primary_address__c = 'Home'; 
		            consToUpdate.add(c);
            	}
            	
            }
        }   
        if (consToUpdate.size() > 0) {
            nowCopyingAddresses = true;
            update consToUpdate;
            nowCopyingAddresses = false;
        }
    }
    
    public string getHHName(Contact[] allMembers) {
        final string sAnd = ' and ';
        string hhname = '';

        // get the adult members list
        Contact[] members = new Contact[0];
        for (contact c : allMembers) {
            if (c.not_in_hh_name__c != true) members.add(c);
        } 
        
        // build the household name from the member names
        if (members.size() > 0 && members.size() < 3) {
            if (members[0].FirstName!=null) {
                hhName += members[0].FirstName;
            }
            if (members.size()==1 || members[1].FirstName==null) {
                hhName += ' ' + members[0].LastName;
                if (includeSalutation && members[0].Salutation != null) {
                    hhName = members[0].Salutation + ' ' + hhName;
                }
            } else {
                boolean haveSalutations = (includeSalutation && members[0].Salutation != null && members[1].Salutation != null);    
                
                if (members[0].LastName == members[1].LastName) {
                    // same last name
                    hhName += sAnd + members[1].FirstName;

                    if (haveSalutations) {
                        
                        // don't want Mrs & Mr, just too strange
                        if (members[0].Salutation == members[1].Salutation || members[0].Salutation == 'Mrs.' || members[0].Salutation == 'Ms.') {
                            hhName = members[0].Salutation + ' ' + members[0].FirstName + ' ' + members[0].LastName + sAnd + members[1].Salutation + ' ' + members[1].FirstName;
                        } else {
                            // Mr. & Mrs.
                            hhName = members[0].Salutation + ' & ' + members[1].Salutation + ' ' + hhName;
                        }
                    }
                } else {
                    // different last name
                    if (haveSalutations) {
                        hhName = members[0].Salutation + ' ' + hhName + ' ' + members[0].LastName + sAnd + members[1].Salutation + ' ' + members[1].FirstName;
                    } else {
                        hhName += ' ' + members[0].LastName + sAnd + members[1].FirstName;
                    }
                }
                hhName += ' ' + members[1].LastName;
            }           
        } else if (members.size() == 0) {
        	hhName = '[Unknown]';
        } else {
            // combine last names, only one copy of each name
            Set<String> lnames = new Set<String>{};
            for (contact c : members) {
                if (!lnames.contains(c.LastName)) {
                    hhName += '/' + c.LastName;
                }
                lnames.add(c.LastName);
                if (lnames.size() > 3) break;
            }
            hhName = 'The ' + hhName.substring(1) + ' Family';
        }
        return hhName;
    }
    
    public string getHHGreeting(Contact[] allMembers) {
        final string sAnd = ' and ';
        final string sComma = ', ';

        // get the adult members list
        Contact[] members = new Contact[0];
        for (contact c : allMembers) {
            if (c.not_in_hh_name__c != true) members.add(c);
        } 

        // append each first name to the greeting
        string greeting = (members.isEmpty() || members[0].FirstName == null) ? '' : members[0].FirstName;
        if (members.size() > 1) {
	        for (integer i=1 ; i<members.size() ; i++) {
	            if (members[i].FirstName!=null) {
	            	boolean moreRoom = greeting.length() < 30;
	                greeting += (( i < members.size() - 1 && moreRoom )  ? sComma : sAnd) + members[i].FirstName;
	                if (!moreRoom) break;
	            }
	        }
        }
        return (greeting == '' ? 'Friend' : greeting);
        
     }


	public static void FixNaming() {
	
		// if this update is from apex, don't perform the trigger
		if (!GW_Householding.nowUpdating) {
			
			// get all the contacts for these households
			contact[] allhc = [select id, onen_household__c, salutation, firstname, lastname, not_in_hh_name__c 
				from contact where onen_household__c in :trigger.newmap.keyset() limit 800];			
			for (SObject obj : trigger.new) {
				onen_household__c hh = (ONEN_Household__c)obj;
				onen_household__c oldHH = (ONEN_Household__c)trigger.oldmap.get(hh.id);
				
				// set the manual update fields
				if (hh.name != oldHH.name) {
					hh.auto_hhName__c = false;
				}
				if (hh.greeting__c != oldHH.greeting__c) {
					hh.auto_hhGreeting__c = false;
				}
	
				// get the contact list for this one household 
				contact[] hc = new contact[0];
				for (contact c : allhc) {
					if (c.onen_household__c == hh.id) hc.add(c);
				}
						
				// update names as needed
				GW_Householding gwhh = new GW_Householding();
				if (hh.auto_hhName__c) {
					hh.name = gwhh.getHHName(hc);
				}
				if (hh.auto_hhGreeting__c) {
					hh.greeting__c = gwhh.getHHGreeting(hc); 
				}
			}
		}
	}
	
	
	public static void PreventDeletion() {
		// if this update is from apex, don't perform the trigger
		if (!GW_Householding.nowUpdating) {
			
			// prevent user from deleting households unless they are already empty
				
			// first get the set of non-empty households
			set<id> hhids = new set<id>{};
			for (contact c : [select onen_household__c from contact 
									where onen_household__c in :trigger.oldmap.keyset() 
									limit 1000]) {
				hhids.add(c.onen_household__c);
			}
				
			// now add an error for each one that's in the non-empty list
			for (SObject obj : trigger.old) { 
				onen_household__c h = (ONEN_Household__c)obj;
				if (hhids.contains(h.id)) 
					h.addError('You cannot delete households that contain existing contacts. Instead, delete the contacts or clear their household field.');
			}
		}
	}

	// called from the Contact before trigger
	public static void ContactManageHouseholdBeforeTrigger() {
	
	    // don't run this recursively when fixing addresses 
	    if (!GW_Householding.nowCopyingAddresses) {
	    
	        // don't run this recursively when creating 'second' contacts 
		    if (!trigger.isInsert || ((Contact)Trigger.new[0]).SecondContactLastName__c != 'Second Contact') { 
		
		        // compile a list of households that need updating
		        onen_household__c[] newHouseholds = new onen_household__c[]{};
		
		        // also save contacts that have no address
		        id[] needAddress = new id[]{};
		
		        // loop through the records
		        for (SObject obj : Trigger.New) {
			        	Contact c = (Contact)obj;
			        
			        if (c.SecondContactLastName__c != null) {
			            // add this contact to the update list if no home address
			            if (c.otherstreet == null && c.onen_household__c != null) {
			                needAddress.add(c.onen_household__c);
			            }
	
						// check if this contact is newly deceased
						if ( c.Deceased__c == true && trigger.oldmap != null && 
							trigger.oldmap.containsKey(c.id) && !(((Contact)(trigger.oldmap.get(c.id))).deceased__c ))
								c.ONEN_Household__c = null;
			
			            // create a blank household for each contact that doesn't have one
			            if (c.onen_household__c==null) {
			                newHouseholds.add(new onen_household__c(Name='New Household'));
			                // NOTE: household names get corrected in the "after" trigger
			            }
		        	}
		        }
		        if (newHouseholds.size() > 0) insert newHouseholds;
		        
		        // get missing addresses
		        Map<id, contact> addresses = new Map<id, contact>{};
		        if (needAddress.size() > 0) {
		            for (contact c : [select id, onen_household__c, otherStreet, otherCity, otherState, otherPostalCode, otherCountry from contact where onen_household__c in :needAddress and otherStreet!=null]) {
		                addresses.put(c.onen_household__c, c);
		            }
		        }
		
		        // loop through the new records again
		        integer i = 0;
		        for (SObject obj: Trigger.new) {
		        	Contact c = (Contact)obj;
		            
		            if (c.SecondContactLastName__c != null) {
			            // set the household to one of the 'New' ones
			            if (c.onen_household__c==null) {
			                c.onen_household__c = newHouseholds[i].id;
			                i++;
			            }
			            // fill in preferred address, if blank
			            if (c.primary_address__c == null) 
			                c.primary_address__c = (c.mailingStreet != null) ? 'Work' : (c.OtherStreet != null) ? 'Home' : null;        
			            // set the address from other household member, if this is a new person without one
			            if (c.otherStreet == null && trigger.isInsert) {
			                if (addresses.containsKey(c.onen_household__c)) {
			                    contact addr = addresses.get(c.onen_household__c);
			                    c.otherStreet = addr.otherStreet;
			                    c.otherCity = addr.otherCity;
			                    c.otherState = addr.otherState;
			                    c.otherPostalCode = addr.otherPostalCode;
			                    c.otherCountry = addr.otherCountry;
			                }
			            }
			
			            // create a 'second' contact in the same household
			            if (c.SecondContactFirstName__c != null) {
			                
			                GW_Householding.secondContacts.add(new Contact(
			                    Salutation = c.SecondContactSalutation__c,
			                    FirstName = c.SecondContactFirstName__c,
			                    LastName = c.SecondContactLastName__c,
			                    Email = c.SecondContactEmail__c,
			                    onen_household__c = c.onen_household__c,
			                    AccountId = ONEN_DefaultAccount.GetIndividualAccountId(),
			                    SecondContactLastName__c='Second Contact')
			                );
			                c.SecondContactFirstName__c = null;
			            }
			            c.SecondContactLastName__c = null;
			            c.SecondContactEmail__c = null;
			        }
		        }
		    }
	    }
	}

	// called from the Contact after trigger.
	public static void ContactManageHouseholdAfterTrigger() {
		
		// AFTER TRIGGER
	    /* need to special case if this is a second contact created by apex after saving a regular 
	       contact record. it is a tricky event path -- we come to this trigger after saving a 
	       primary contact, and again recursively when doing the second insert here
	       I did all this just so that I could add the second contact *after* the first */
	    if (!trigger.isInsert || ((Contact)trigger.new[0]).SecondContactLastName__c!='Second Contact') {
	           
	        if (!GW_Householding.secondContacts.isEmpty()) {
	            // insert the secondary contacts, if any
	            insert GW_Householding.secondContacts;
	            GW_Householding.secondContacts.clear();
	        }  
	        if (!GW_Householding.nowCopyingAddresses) {
	            Set<Id> HHChanges = new Set<Id>();
	            Map<Id, Contact> AddressChanges = new Map<Id, Contact>{};
	    
	            for (SObject obj : Trigger.isDelete ? Trigger.old : Trigger.new) {
					Contact ContactAfter = (Contact)obj;
	                // track whether to update the address
	                Boolean addressChange = false;
	                Boolean hhChange = false;
	                
	                if (!Trigger.isUpdate) {
	                    // add this id (and the old one) to the list of changed households
	                    HHChanges.add(ContactAfter.onen_household__c);
	                    addressChange = !Trigger.isDelete;
	                } else {
	                    // for update trigger, check for changes to the data
	                    Contact ContactBefore = (Contact)trigger.oldmap.get(ContactAfter.id);
	                    hhChange = ContactBefore.onen_household__c!=ContactAfter.onen_household__c || ContactBefore.Not_in_HH_Name__c!=ContactAfter.Not_in_HH_Name__c;        
	                    Boolean nameChange = ContactBefore.FirstName!=ContactAfter.FirstName||ContactBefore.LastName!=ContactAfter.LastName||ContactBefore.Salutation!=ContactAfter.Salutation;
	                    addressChange = ContactBefore.OtherStreet!=ContactAfter.OtherStreet||ContactBefore.OtherCity!=ContactAfter.OtherCity||ContactBefore.OtherState!=ContactAfter.OtherState||ContactBefore.OtherPostalCode!=ContactAfter.OtherPostalCode||ContactBefore.OtherCountry!=ContactAfter.OtherCountry;
	
	                    if (hhChange || nameChange) {
	                        HHChanges.add(ContactBefore.onen_household__c);
	                        HHChanges.add(ContactAfter.onen_household__c);
	                    }
	                }
	                // mark addresses that need propagating
	                if (hhChange || addressChange) {
	                    AddressChanges.put(ContactAfter.onen_household__c, ContactAfter);
	                }
	            }
	            
	            // call the update code for householding
	            GW_Householding gwhh = new GW_Householding();	            
	            if (!HHChanges.isEmpty()) gwhh.UpdateNames(HHChanges);
	            if (!AddressChanges.isEmpty()) gwhh.UpdateAddresses(AddressChanges);
	        }
	    }		
	}		
		
    /*********************************************************************************
    * TEST METHODS
    *********************************************************************************/
    public static testMethod void TestNaming() {
    	GW_Householding gwhh = new GW_Householding(); 
        contact[] cons = new contact[]{new contact(lastname='Jones', firstname='Tom')};
        system.assertequals('Tom Jones', gwhh.getHHName(cons));
        system.assertequals('Tom', gwhh.getHHGreeting(cons));
        if (includeSalutation) {
            cons[0].salutation = 'Mr.';
            system.assertequals('Mr. Tom Jones', gwhh.getHHName(cons));
            cons[0].salutation = null;
        }

        cons.add(new contact(lastname='Jones', firstname='Tim'));
        system.assertequals('Tom and Tim Jones', gwhh.getHHName(cons));
        system.assertequals('Tom and Tim', gwhh.getHHGreeting(cons));
        if (includeSalutation) {
            cons[0].salutation = 'Dr.';
            cons[1].salutation = 'Ms.';
            system.assertequals('Dr. & Ms. Tom and Tim Jones', gwhh.getHHName(cons));
            cons[0].salutation = null;
            cons[1].salutation = null;
            cons[0].salutation = 'Mr.';
            cons[1].salutation = 'Mr.';
            system.assertequals('Mr. Tom Jones and Mr. Tim Jones', gwhh.getHHName(cons));
            cons[0].salutation = null;
            cons[1].salutation = null;
        }

        cons[1].lastname='Smith';
        system.assertequals('Tom Jones and Tim Smith', gwhh.getHHName(cons));    
        system.assertequals('Tom and Tim', gwhh.getHHGreeting(cons));
        if (includeSalutation) {
            cons[0].salutation = 'Dr.';
            cons[1].salutation = 'Mr.';
            system.assertequals('Dr. Tom Jones and Mr. Tim Smith', gwhh.getHHName(cons));
            cons[0].salutation = null;
            cons[1].salutation = null;
        }

        cons.add(new contact(lastname='Smith', firstname='Ann'));
        system.assertequals('The Jones/Smith Family', gwhh.getHHName(cons));
        system.assertequals('Tom, Tim and Ann', gwhh.getHHGreeting(cons));

    }

	/*********************************************************************************
    * Test creation of one contact. Household should be created and naming should
    * meet expectations
    *********************************************************************************/
    public static testMethod void TestAutoCreationDeactivated() {    

        Id HHId;
        Id FirstContactId;
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        //system.debug('Insert First Contact');
        insert firstContact;
        
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, onen_household__r.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        //FirstContactId = firstHouseholdMember[0].id;
        //households should no longer exist without the Manage HH interface creating them OR through data migration into
        //the secondcontact first and last name fields
        system.assertEquals(null, firstHouseholdMember[0].onen_household__c);
    }

    /*********************************************************************************
    * Test creation of one contact. Household should be created and naming should
    * meet expectations
    *********************************************************************************/
    public static testMethod void TestHHForOneContact() {    

        Id HHId;
        Id FirstContactId;
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
        
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        //system.debug('Insert First Contact');
        insert firstContact;
        
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, onen_household__r.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstHouseholdMember[0].id;
        
        onen_household__c[] CurrentHousehold = [select id, name, Greeting__c from onen_household__c where Id =:firstHouseholdMember[0].onen_household__c];
        //it should have his address and recognition names on the HH and the Contact record should be right
        HHId = CurrentHousehold[0].Id;
        //HH name is as expected?
        System.assertEquals('Joe Johanssen',CurrentHousehold[0].Name);
        //HH greeting is as expected?
        System.assertEquals('Joe',CurrentHousehold[0].Greeting__c);
        //HH name is in sync between contact and HH?
        System.assertEquals(firstHouseholdMember[0].onen_household__r.Name,CurrentHousehold[0].Name);
        //greeting is in sync between contact and HH
        System.assertEquals(firstHouseholdMember[0].householdGreeting__c,CurrentHousehold[0].Greeting__c);
        //contact address is as expected
        System.assertEquals('123 Elm St',firstHouseholdMember[0].otherStreet);          
		
		// try to delete a HH -- trigger does not allow it
		try {
			delete currentHousehold;
			system.assert(false);    // should not get here
		} catch (exception e) {
		}	
				
    }

	/*********************************************************************************
	* Test creation of two contacts in a Household. Household should be created and
	* naming should meet expectations
	*********************************************************************************/
	public static testMethod void TestHHForOneContactWithNullValues() {	 
		
		Id HHId;
		Id FirstContactId;
		
		//now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
		//create first contact
		Contact firstContact = new Contact (
			LastName='Johanssen',
			ONEN_Household__c = hh.id			
		);
		//system.debug('Insert First Contact');
		insert firstContact;
		Contact[] firstHouseholdMember = [select id,ONEN_Household__c,OtherStreet,Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where Id =:firstContact.id];
		FirstContactId = firstHouseholdMember[0].id;
		
		ONEN_Household__c[] CurrentHousehold = [select id,Member_Count__c,Greeting__c from ONEN_Household__c where Id =:firstHouseholdMember[0].ONEN_Household__c];
		//it should have his address and recognition names on the HH and the Contact record should be right
		HHId = CurrentHousehold[0].Id;
		//one contact in HH?
		System.assertEquals(1,CurrentHousehold[0].Member_Count__c);
		//HH name is as expected?
		System.assertEquals('Johanssen',firstHouseholdMember[0].HouseholdName__c);
		//HH greeting is as expected?
		System.assertEquals('Friend',firstHouseholdMember[0].HouseholdGreeting__c);
		
	}

    /*********************************************************************************
    * Test one contact name change. Household name should change as well.
    *********************************************************************************/
    public static testMethod void TestContactNameChange() {  

        Id HHId;
        Id FirstContactId;
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        //system.debug('Insert First Contact');
        insert firstContact;
        
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, onen_household__r.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstHouseholdMember[0].id;
    
        onen_household__c[] CurrentHousehold = [select id, name, Greeting__c from onen_household__c where Id =:firstHouseholdMember[0].onen_household__c];

        //names are as expected?
        System.assertEquals('Joe Johanssen',CurrentHousehold[0].Name);
        System.assertEquals('Joe Johanssen',firstHouseholdMember[0].onen_household__r.Name);
        //greetings are as expected?
        System.assertEquals('Joe',CurrentHousehold[0].Greeting__c);
        System.assertEquals('Joe',firstHouseholdMember[0].householdGreeting__c);
        
        firstContact.LastName = 'Smith';
        firstContact.FirstName = 'Harry';
        update firstContact;
        
        Contact[] firstHouseholdMember2 = [select id,otherStreet,Account.Name, onen_household__r.Name, householdGreeting__c from Contact where Id =:FirstContactId];
                
        onen_household__c[] CurrentHousehold2 = [select id, Name, Greeting__c from onen_household__c where Id =:firstHouseholdMember[0].onen_household__c];
        
        //names are as expected?
        System.assertEquals('Harry Smith',CurrentHousehold2[0].Name);
        System.assertEquals('Harry Smith',firstHouseholdMember2[0].onen_household__r.Name);
        //greetings are as expected?
        System.assertEquals('Harry',CurrentHousehold2[0].Greeting__c);
        System.assertEquals('Harry',firstHouseholdMember2[0].householdGreeting__c);           
    }
    
	/*******************************************************************************************
	* Test insert household first, then insert contact from contacts related list on household.
	********************************************************************************************/
	public static testMethod void TestInsertHouseholdThenContact() {	 
		
		//create new household
		ONEN_Household__c newHousehold = new ONEN_Household__c (Name='Household_for_tests');
		insert newHousehold;
		
		//create first contact
		Contact firstContact = new Contact (
			LastName='Johanssen_for_tests',
			ONEN_Household__c = newHousehold.id		
		);
		insert firstContact;
		
		Contact[] firstHouseholdMember = [select id,ONEN_Household__c,OtherStreet,Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where Id =:firstContact.id];
		System.assertEquals(1,firstHouseholdMember.size());	
	}
	    
    /*********************************************************************************
    * Test adding a second contact to a household. Naming and address changes should
    * change as expected
    *********************************************************************************/
    public static testMethod void TestSecondContactInHousehold() {   

        Id HHId;
        Id HHId2;
        Id FirstContactId;
        Id SecondContactId;
        String firstContactotherStreet = '123 Elm St';
        String firstContactotherCity = 'Milwaukee';
        String firstContactotherState = 'WI';
        String firstContactotherPostalCode = '53213';
        String firstContactotherCountry = 'USA';
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet=firstContactotherStreet,
            otherCity=firstContactotherCity,
            otherState=firstContactotherState,
            otherPostalCode=firstContactotherPostalCode,
            otherCountry=firstContactotherCountry           
        );
        insert firstContact;
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstContact.id;
        
        //onen_household__c[] CurrentHousehold = [select id,otherStreet__c, otherCity__c, otherState__c, otherPostalCode__c, otherCountry__c,Name, householdGreeting__c from onen_household__c where Id =:firstHouseholdMember[0].onen_household__c];
        //it should have his address and recognition names on the HH and the Contact record should be right
        HHId = firstHouseholdMember[0].onen_household__c;
        //create second contact in that household
        String secondContactotherStreet = '123 Elm St';
        Contact secondContact = new Contact (
            FirstName='Bobby',
            LastName='Johanssen',
            onen_household__c=HHId       
        );
        insert secondContact;
        //there should now be two Contacts in that household
        SecondContactId = secondContact.id;
        System.assertEquals(2,[select count() from Contact where onen_household__c = :HHId]);
        String HHName;
        HHName = 'Joe and Bobby Johanssen';
        String HHGreeting;
        HHGreeting = 'Joe and Bobby';
        onen_household__c[] HHAfterSecondContact = [select id,Name, Greeting__c from onen_household__c where Id =:HHId];
        
        //the recognition name on the household should change
        //HHname should be as expected
        System.assertEquals(HHName,HHAfterSecondContact[0].Name);
        System.assertEquals(HHGreeting,HHAfterSecondContact[0].Greeting__c);
        
        //TODO: need assertions for recognition names on both Contacts
        Contact[] ContactAfterSecondContact = [select FirstName, LastName,onen_household__r.Name,householdGreeting__c,otherStreet,otherCity,otherState,otherPostalCode,otherCountry from Contact where onen_household__c =:HHId];
        //system.debug(ContactAfterSecondContact[0]);
        System.assertEquals(HHName,ContactAfterSecondContact[0].onen_household__r.Name);
        System.assertEquals(HHGreeting,ContactAfterSecondContact[0].householdGreeting__c);        
        System.assertEquals(ContactAfterSecondContact[0].onen_household__r.Name,ContactAfterSecondContact[1].onen_household__r.Name);
        System.assertEquals(ContactAfterSecondContact[0].householdGreeting__c,ContactAfterSecondContact[1].householdGreeting__c);
        //first contact address should match
        System.assertEquals(firstContactotherStreet,ContactAfterSecondContact[0].otherStreet);
        System.assertEquals(firstContactotherCity,ContactAfterSecondContact[0].otherCity);
        System.assertEquals(firstContactotherState,ContactAfterSecondContact[0].otherState);
        System.assertEquals(firstContactotherPostalCode,ContactAfterSecondContact[0].otherPostalCode);
        System.assertEquals(firstContactotherCountry,ContactAfterSecondContact[0].otherCountry);
        //second contact address should match
        System.assertEquals(firstContactotherStreet,ContactAfterSecondContact[1].otherStreet);
        System.assertEquals(firstContactotherCity,ContactAfterSecondContact[1].otherCity);
        System.assertEquals(firstContactotherState,ContactAfterSecondContact[1].otherState);
        System.assertEquals(firstContactotherPostalCode,ContactAfterSecondContact[1].otherPostalCode);
        System.assertEquals(firstContactotherCountry,ContactAfterSecondContact[1].otherCountry);
        
        //what about case where second contact doesn't have address, they should get address
    }
    /*********************************************************************************
    * Test adding a second contact to a household. Naming and address changes should
    * change as expected
    *********************************************************************************/
    public static testMethod void Test3rdContactInHousehold() {  

        Id HHId;
        Id HHId2;
        Id FirstContactId;
        Id SecondContactId;
        String firstContactotherStreet = '123 Elm St';
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet=firstContactotherStreet,
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        insert firstContact;
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstContact.id;
        
        //it should have his address and recognition names on the HH and the Contact record should be right
        HHId = firstHouseholdMember[0].onen_household__c;
        //create second contact in that household
        String secondContactotherStreet = '123 Elm St';
        Contact secondContact = new Contact (
            FirstName='Bobby',
            LastName='Johanssen',
            onen_household__c=HHId       
        );
        insert secondContact;
        
        //there should now be two Contacts in that household
        SecondContactId = secondContact.id;
        System.assertEquals(2,[select count() from Contact where onen_household__c = :HHId]);
        Contact thirdContact = new Contact (
            FirstName='Brad',
            LastName='Johanssen',
            onen_household__c=HHId               
        );
        
        //system.debug('Insert third contact');
        insert thirdContact;
        
        String ExpectedHHName;
        ExpectedHHName = 'The Johanssen Family';
        String ExpectedHHGreeting;
        ExpectedHHGreeting = 'Joe, Bobby and Brad';
        onen_household__c[] HHAfterThirdContact = [select id, Name, Greeting__c from onen_household__c where Id =:HHId];
        //recognition names on that second household should change to the more than
        //2 contact notation
        System.assertEquals(ExpectedHHName,HHAfterThirdContact[0].Name);
        
        //ejc Rarely, this test will fail because of create order
        //System.assertEquals(ExpectedHHGreeting,HHAfterThirdContact[0].Greeting__c);
        system.assert(HHAfterThirdContact[0].Greeting__c.contains('Joe') && 
        	HHAfterThirdContact[0].Greeting__c.contains('Bobby') && 
        	HHAfterThirdContact[0].Greeting__c.contains('and') && 
        	HHAfterThirdContact[0].Greeting__c.contains('Brad'));

        String OverrideName='The Jackhanssens';
        String OverrideGreeting='Joe, Bob and Brad';
        onen_household__c firstHH = new onen_household__c (
            Id=HHId,
            Name=OverrideName,
            Greeting__c=OverrideGreeting,
            auto_hhname__c = false,
            auto_hhgreeting__c = false
        );
        
        //system.debug('Change greeting and Household Name');
        update firstHH;
        onen_household__c[] HHAfterOverride = [select Name, Greeting__c from onen_household__c where Id =:HHId];
        //HH name should change when overridden
        System.assertEquals(OverrideName,HHAfterOverride[0].Name);
        //HH greeting should change when overridden
        System.assertEquals(OverrideGreeting,HHAfterOverride[0].Greeting__c);
        //add tests for contacts
        
        //change a contact and make sure overrides aren't overridden
        
        onen_household__c HHOverrideNull = new onen_household__c (
            Id=HHId,
            auto_hhname__c = true,
            auto_hhgreeting__c = true
        );
        
        update HHOverrideNull;
        onen_household__c[] HHAfterOverrideNull = [select Name, Greeting__c from onen_household__c where Id =:HHId];
        //HH name should change when overridden
        System.assertEquals(ExpectedHHName,HHAfterOverrideNull[0].Name);
        //HH greeting should change when overridden
        system.assert( HHAfterThirdContact[0].Greeting__c.contains('Bobby') );
        //add tests for contacts
        
        //what about case where second contact doesn't have address, they should get address
    }
    
    
    /*********************************************************************************
    * Test creation of one contact and change address. Household address should change
    * as well.
    *********************************************************************************/
    public static testMethod void TestChangeContactAddress() {   

        Id HHId;
        Id FirstContactId;
        Id SecondContactId;
        String firstContactotherStreet = '123 Elm St';
        String firstContactotherCity = 'Milwaukee';
        String firstContactotherState = 'WI';
        String firstContactotherPostalCode = '53213';
        String firstContactotherCountry = 'USA';
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
        
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet=firstContactotherStreet,
            otherCity=firstContactotherCity,
            otherState=firstContactotherState,
            otherPostalCode=firstContactotherPostalCode,
            otherCountry=firstContactotherCountry           
        );
        insert firstContact;
        
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstHouseholdMember[0].id;
        HHId = firstHouseholdMember[0].onen_household__c;
        
        //create second contact in that household
        Contact secondContact = new Contact (
            FirstName='Bobby',
            LastName='Johanssen',
            onen_household__c=HHId       
        );
        insert secondContact;
        
        String secondContactotherStreet = '12345 Elm St';
        String secondContactotherCity = 'Toronto';
        String secondContactotherState = 'ON';
        String secondContactotherPostalCode = 'V67 F45';
        String secondContactotherCountry = 'CAN';       
        
        Contact firstContactChanged = new Contact (
            id=FirstContactId,
            otherStreet=secondContactotherStreet,
            otherCity=secondContactotherCity,
            otherState=secondContactotherState,
            otherPostalCode=secondContactotherPostalCode,
            otherCountry=secondContactotherCountry
        );
        update firstContactChanged;
        onen_household__c[] CurrentHousehold = [select id,Name, Greeting__c from onen_household__c where Id =:HHId];
                
        Contact[] householdMembersAfterAddressChange = [select id,onen_household__c,otherStreet,otherCity,otherState,otherPostalCode,otherCountry,Primary_Address__c from Contact where onen_household__c =:HHId];
        //first contact's addresses should match
        System.assertEquals(secondContactotherStreet,householdMembersAfterAddressChange[0].otherStreet);
        System.assertEquals(secondContactotherCity,householdMembersAfterAddressChange[0].otherCity);
        System.assertEquals(secondContactotherState,householdMembersAfterAddressChange[0].otherState);
        System.assertEquals(secondContactotherPostalCode,householdMembersAfterAddressChange[0].otherPostalCode);
        System.assertEquals(secondContactotherCountry,householdMembersAfterAddressChange[0].otherCountry);
        //second contact's addresses should match
        System.assertEquals(secondContactotherStreet,householdMembersAfterAddressChange[1].otherStreet);
        System.assertEquals(secondContactotherCity,householdMembersAfterAddressChange[1].otherCity);
        System.assertEquals(secondContactotherState,householdMembersAfterAddressChange[1].otherState);
        System.assertEquals(secondContactotherPostalCode,householdMembersAfterAddressChange[1].otherPostalCode);
        System.assertEquals(secondContactotherCountry,householdMembersAfterAddressChange[1].otherCountry);
        
        System.assertEquals('Home', householdMembersAfterAddressChange[0].Primary_Address__c);
        System.assertEquals('Home', householdMembersAfterAddressChange[1].Primary_Address__c);
    }

    /*********************************************************************************
    * Test deletion of contact from household. Household should be renamed to meet
    * changes in membership
    *********************************************************************************/
    public static testMethod void TestDeleteContactFromHousehold() {     

        Id HHId;
        Id FirstContactId;
        Id SecondContactId;
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
        
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        insert firstContact;
        
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstContact.id;
        
        //it should have his address and recognition names on the HH and the Contact record should be right
        HHId = firstHouseholdMember[0].onen_household__c;
        //create second contact in that household
        Contact secondContact = new Contact (
            FirstName='Bobby',
            LastName='Johanssen',
            onen_household__c=HHId,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        insert secondContact;       
        //are two people in hh now?
        System.assertEquals(2,[select count() from Contact where onen_household__c = :HHId]);
        delete secondContact;       
        
        /*********  Long term, we should be deleting households with only one member */
        
        //that household should now have only one Contact in it
        System.assertEquals(1,[select count() from Contact where onen_household__c = :HHId]);
        onen_household__c[] CurrentHousehold = [select id,Name, Greeting__c from onen_household__c where Id =:HHId];
        System.assertEquals('Joe Johanssen',CurrentHousehold[0].Name);
        System.assertEquals('Joe',CurrentHousehold[0].Greeting__c);
    }
    
    /*********************************************************************************
    * Test deletion of last contact from household. Household should be deleted when
    * it has no members left
    *********************************************************************************/
    public static testMethod void TestDeleteLastContactFromHousehold() {     

        Id HHId;
        Id FirstContactId;
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;

        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        insert firstContact;
        
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstHouseholdMember[0].id;
        onen_household__c[] CurrentHousehold = [select id,Name, Greeting__c from onen_household__c where Id =:firstHouseholdMember[0].onen_household__c];
        //it should have his address and recognition names on the HH and the Contact record should be right
        HHId = CurrentHousehold[0].Id;
        //hh should exist
        System.assertEquals(1,[select count() from onen_household__c where Id =:HHId]);
        
        delete firstContact;
        //the household should now be deleted since it has no members
        System.assertEquals(0,[select count() from onen_household__c where Id =:HHId]);
        
    }
    
    /*********************************************************************************
    * Test move a contact from one household to another. Both household should be 
    * handled accoring to the change in membership
    *********************************************************************************/
    public static testMethod void TestMoveContactBetweenHouseholds() {   

        Id HHId;
        Id HHId2;
        Id FirstContactId;
        Id SecondContactId;
        Id ThirdContactId;
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
        //create first contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen',
            ONEN_Household__c = hh.id,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        //system.debug('Insert First Contact');
        insert firstContact;
        Contact[] firstHouseholdMember = [select id,onen_household__c,otherStreet,Account.Name, householdGreeting__c from Contact where Id =:firstContact.id];
        FirstContactId = firstContact.id;
        
        //it should have his address and recognition names on the HH and the Contact record should be right
        HHId = firstHouseholdMember[0].onen_household__c;
        //create second contact in that household
        Contact secondContact = new Contact (
            FirstName='Bobby',
            LastName='Johanssen',
            onen_household__c=HHId,
            otherStreet='123 Elm St',
            otherCity='Wauwatosa',
            otherState='WI',
            otherPostalCode='53213',
            otherCountry='USA'          
        );
        //system.debug('Insert Second Contact');
        insert secondContact;
        
        SecondContactId = secondContact.Id;
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh2 = new ONEN_Household__c(Name='Foo_Household');
		insert hh2;
        
        //create a Contact with a new household
        Contact thirdContact = new Contact (
            FirstName='Samuel',
            LastName='Jackson',
            ONEN_Household__c = hh2.id          
        );      
        //system.debug('Insert Third Contact');
        insert thirdContact;
        ThirdContactId = thirdContact.id;
        
        Contact[] thirdHHMember = [select id,onen_household__c from Contact where Id =:ThirdContactId];
        HHId2 = thirdHHMember[0].onen_household__c;      
        
        //remove the second person from the first Household
        Contact updateSecondContact1 = new Contact (
            id=SecondContactId,
            onen_household__c=HHId2          
        );  
        //test for what happens to first hh 
        //system.debug('Move Second Contact');
        update updateSecondContact1;
        Contact[] bettyMoved = [select id,FirstName, LastName, onen_household__c from Contact where id =:SecondContactId];
        system.assertEquals(HHId2,bettyMoved[0].onen_household__c);
        Contact[] secondHHMembers = [select id,FirstName, LastName from Contact where onen_household__c =:HHId2];
        system.debug(secondHHMembers);
        
        onen_household__c[] HHAfter4Contact = [select id,Name, Greeting__c from onen_household__c where Id =:HHId2];
        //recognition names on that second household should change
        System.assert(HHAfter4Contact[0].Name=='Bobby Johanssen and Samuel Jackson' || HHAfter4Contact[0].Name=='Samuel Jackson and Bobby Johanssen');
        
    }
 
  	/*********************************************************************************
	* Test adding a contact with different address values to an existing HH. Should be
	* discarded unless HH address is null
	*********************************************************************************/
	public static testMethod void TestInsertingNewHouseholdMemberWithDifferentAddress() {
		Id HHId;
		Id HHId2;
		Id FirstContactId;
		Id SecondContactId;
		Id ThirdContactId;
		
		//now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
		//create first contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen',
			ONEN_Household__c = hh.id		
		);
		//system.debug('Insert First Contact');
		insert firstContact;
		Contact[] firstHouseholdMember = [select id,ONEN_Household__c,OtherStreet,Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where Id =:firstContact.id];
		FirstContactId = firstContact.id;
		
		ONEN_Household__c[] CurrentHousehold = [select id,Member_Count__c, Name, Greeting__c from ONEN_Household__c where Id =:firstHouseholdMember[0].ONEN_Household__c];

		HHId = firstHouseholdMember[0].ONEN_Household__c;
		
		String secondContactMailingStreet = '123 Elm St';
		String secondContactMailingCity = 'Milwaukee';
		String secondContactMailingState = 'WI';
		String secondContactMailingPostalCode = '53213';
		String secondContactMailingCounty = 'Milwaukee';
		String secondContactMailingCountry = 'USA';
		
		
		Contact secondContact = new Contact (
			FirstName='Bobby',
			LastName='Johanssen',
			ONEN_Household__c=HHId,
			OtherStreet=secondContactMailingStreet,
			OtherCity=secondContactMailingCity,
			OtherState=secondContactMailingState,
			OtherPostalCode=secondContactMailingPostalCode,
			Home_County__c=secondContactMailingCounty,
			OtherCountry=secondContactMailingCountry			
		);
		//system.debug('Insert Second Contact');
		insert secondContact;
		
		ONEN_Household__c[] CurrentHousehold2 = [select id,Member_Count__c, Name, Greeting__c from ONEN_Household__c where Id =:firstHouseholdMember[0].ONEN_Household__c];
		Contact[] HouseholdMembers = [select id,ONEN_Household__c,OtherStreet,OtherCity,OtherState,OtherPostalCode,OtherCountry, Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where ONEN_Household__c =:HHId];
		//address should match on first contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers[0].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers[0].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers[0].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers[0].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers[0].OtherCountry);
		//address should match on second contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers[1].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers[1].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers[1].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers[1].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers[1].OtherCountry);
		
		Contact thirdContact = new Contact (
			FirstName='Samuel',
			LastName='Jackson',
			ONEN_Household__c=HHId		
		);		
		//system.debug('Insert Third Contact');
		insert thirdContact;
		
		ONEN_Household__c[] CurrentHousehold3 = [select id,Member_Count__c, Name, Greeting__c from ONEN_Household__c where Id =:firstHouseholdMember[0].ONEN_Household__c];
		Contact[] HouseholdMembers2 = [select id,ONEN_Household__c,OtherStreet,OtherCity,OtherState,OtherPostalCode,OtherCountry, Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where ONEN_Household__c =:HHId];
		//address should match on first contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers2[0].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers2[0].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers2[0].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers2[0].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers2[0].OtherCountry);
		//address should match on second contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers2[1].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers2[1].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers2[1].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers2[1].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers2[1].OtherCountry);
		//address should match on third contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers2[2].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers2[2].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers2[2].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers2[2].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers2[2].OtherCountry);
	}
	/*********************************************************************************
	* Test moving a contact with different address values into an existing HH.
	*********************************************************************************/
	public static testMethod void TestMovingHouseholdMemberWithDifferentAddress() {
		Id HHId;
		Id HHId2;
		Id FirstContactId;
		Id SecondContactId;
		Id ThirdContactId;
		
		//now must create the HH first since automated HH'ing is no more as of 11/2011
		ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
		insert hh;
		
		//create first contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen',
			ONEN_Household__c = hh.id
		);
		insert firstContact;
		Contact[] firstHouseholdMember = [select id,ONEN_Household__c,OtherStreet,Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where Id =:firstContact.id];
		FirstContactId = firstContact.id;		
		ONEN_Household__c[] CurrentHousehold = [select id,Member_Count__c,Name, Greeting__c from ONEN_Household__c where Id =:firstHouseholdMember[0].ONEN_Household__c];

		HHId = firstHouseholdMember[0].ONEN_Household__c;
		
		String secondContactMailingStreet = '123 Elm St';
		String secondContactMailingCity = 'Milwaukee';
		String secondContactMailingState = 'WI';
		String secondContactMailingPostalCode = '53213';
		String secondContactMailingCounty = 'Milwaukee';
		String secondContactMailingCountry = 'USA';
		
		
		Contact secondContact = new Contact (
			FirstName='Bobby',
			LastName='Johanssen',
			OtherStreet=secondContactMailingStreet,
			OtherCity=secondContactMailingCity,
			OtherState=secondContactMailingState,
			OtherPostalCode=secondContactMailingPostalCode,
			Home_County__c = secondContactMailingCounty,
			OtherCountry=secondContactMailingCountry			
		);
		insert secondContact;
		
		secondContact.ONEN_Household__c=HHId;
		
		update secondContact;
		Contact[] HouseholdMembers = [select id,FirstName,ONEN_Household__c,OtherStreet,OtherCity,OtherState,OtherPostalCode,OtherCountry, Account.Name, HouseholdGreeting__c,HouseholdName__c from Contact where ONEN_Household__c =:HHId];
		//address should match on first contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers[0].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers[0].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers[0].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers[0].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers[0].OtherCountry);
		//address should match on second contact
		system.assertEquals(secondContactMailingStreet,HouseholdMembers[1].OtherStreet);
		system.assertEquals(secondContactMailingCity,HouseholdMembers[1].OtherCity);
		system.assertEquals(secondContactMailingState,HouseholdMembers[1].OtherState);
		system.assertEquals(secondContactMailingPostalCode,HouseholdMembers[1].OtherPostalCode);
		system.assertEquals(secondContactMailingCountry,HouseholdMembers[1].OtherCountry);
	}

	/* Need to fix up this test for bulk */
	public static testMethod void testBulkContactAdd () {
	
		integer howMany = 50;
		Date datClose = System.Today();
			
		// create & insert contact(s)
		Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany );
		//only time households should be auto-created is when SecondContact fields are filled out
		for (Contact c : TestCons) {
			c.SecondContactFirstName__c = 'George';
			c.SecondContactLastName__c = 'Costanza';
		}
		
		Test.StartTest();
		insert TestCons; 
		Test.StopTest();
		
		//now test that a contact has received the proper member stats from the trigger
		Contact[] newCons = [SELECT Id,FirstName, LastName, ONEN_Household__c, HouseholdName__c FROM Contact WHERE id IN :TestCons AND ONEN_Household__c != null];
		//should have 200 auto-created households because we had secondContact fields filled out
		System.AssertEquals ( howMany, newCons.size());
		
	}
	
	public static testMethod void testBulkContactChange () {
	
		integer howMany = 50;
		Date datClose = System.Today();
		
		list<ONEN_Household__c> newHHs = new list<ONEN_Household__c>();
		for (integer i=0;i < howMany ; i++) {
			ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
			newHHs.add(hh);
		}
		insert newHHs;	
			
		// create & insert contact(s)
		Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany );
		//only time households should be auto-created is when SecondContact fields are filled out
		for (integer i=0;i < TestCons.size() ; i++) {
			TestCons[i].ONEN_Household__c = newHHs[i].id;
		}
		
		test.startTest();
		insert TestCons;
		
		//now test that a contact has received the proper member stats from the trigger
		Contact newCon = [SELECT Id,FirstName, LastName, ONEN_Household__c, HouseholdName__c FROM Contact WHERE FirstName = 'Number1'];
		Id FirstConId = newCon.Id;
		
		String FirstConFirstName = newCon.FirstName;
		String FirstConLastName = newCon.LastName;
		
		//system.debug(FirstConFirstName);
		//system.debug(FirstConLastName);
		
		
		Id FirstConHHId = newCon.ONEN_Household__c;
		System.AssertEquals ( FirstConFirstName + ' ' + FirstConLastName, newCon.HouseholdName__c);
		
		list<Id> newConIds = new list<Id>();
		
		for (Contact thisNewCon : TestCons) {
			newConIds.add(thisNewCon.Id);
		}
		Contact[] newConsList = [SELECT Id, FirstName, LastName, ONEN_Household__c FROM Contact WHERE Id IN :newConIds order by FirstName];
		//system.debug(newConsList.size());
		
		// create & insert contact(s)
		Contact[] TestSecondCons = ONEN_UnitTestData.CreateMultipleTestContactsInHouseholds (newConsList) ;
		//system.debug(TestSecondCons);
		
		insert TestSecondCons;
		Test.StopTest();
		Contact[] allContacts = [select firstname, lastname, onen_Household__r.Name, ONEN_Household__r.Greeting__c, HouseholdName__c, HouseholdGreeting__c from Contact where lastname='Doppelganger'];
		for(Contact c : allContacts) {
			system.assertEquals(c.onen_Household__r.Name,c.HouseholdName__c);
			system.assertNotEquals(null,c.HouseholdName__c);
			system.assertNotEquals(null,c.onen_Household__c);
		}
		Contact[] newCon2 = [SELECT FirstName, LastName, ONEN_Household__r.Name,HouseholdName__c FROM Contact WHERE ONEN_Household__c  = :FirstConHHId];
		
		
		//system.debug(newCon2);
		String contactFirstName=newCon2[0].FirstName;
		String contactLastName=newCon2[0].LastName;
		String secondContactFirstName=newCon2[1].FirstName;
		String secondContactLastName=newCon2[1].LastName;
		System.AssertEquals ( 2, newCon2.size());
		
		system.AssertEquals(contactFirstName,newCon2[0].FirstName);
		system.Assert(newCon2[0].ONEN_Household__r.Name.contains(contactFirstName));
		system.Assert(newCon2[0].ONEN_Household__r.Name.contains(secondContactFirstName));
		system.Assert(newCon2[0].ONEN_Household__r.Name.contains(contactLastName));
		
		system.AssertEquals(secondContactFirstName,newCon2[1].FirstName);
		system.Assert(newCon2[1].HouseholdName__c.contains(contactFirstName));
		system.Assert(newCon2[1].HouseholdName__c.contains(secondContactFirstName));
		system.Assert(newCon2[1].HouseholdName__c.contains(contactLastName));	
	
	}
}