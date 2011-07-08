// Copyright (c) 2009 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Evan Callahan, Matthew Scholtz, Steve Andersen
* @date 01/01/2011
* @description This class contains helper methods for maintaining accounts.
*/
global virtual class ONEN_AccountMaintenance {

	private static boolean firstRun = true;
	  
	/*******************************************************************************************************
	* @description This function sets a primary contact for each account you pass in -- and fixes the primary.
	* Used when inserting new accounts
	* @param acctIds Set of account ids for which you want a primary contact
	*/ 	
    global void SetPrimaryContact(set<Id> acctIds) {
    	//SWA: added support for ignoring default account
    	//SWA: get default account id
		// new method to lookup individual acct id
		Id DefaultAccountId = ONEN_DefaultAccount.GetIndividualAccountId();
		//system.debug ('defaultaccountID: ' + DefaultAccountId);		
		
	   	// don't allow recursion
	   	if (firstrun) {	   		
	    	firstRun = false; 
	
			// get the accounts in the set
			Account[] accts = [select id, primary_contact__c from account where id IN :acctIds];
			
			// added MMS
			set<id> existingPCs = new set<id>();
			for ( Account thisAcct : accts) {
				if (thisAcct.primary_contact__c != null) {
					existingPCs.add (thisAcct.primary_contact__c);
				}
			}
				
			// get all the contacts for the accounts in the set
			//SWA: add criteria to ignore contacts in the default account
			//SWA: need to deal with large return sets. Will get soql return set limits at some point
			
			// chgd MMS
			Contact[] cons = new list<Contact>();
			if ( ! (existingPCs.size() > 0) ) {
				cons = [select id, accountid, title from contact where (accountid IN :acctIds and AccountId!=:DefaultAccountId)  order by accountid, createddate];
			} else {
				cons = [select id, accountid, title from contact where (accountid IN :acctIds and AccountId!=:DefaultAccountId) OR Id IN :existingPCs order by accountid, createddate];
			}

			Map<Id, Contact> cMap = new Map<Id, Contact>();
			cMap.PutAll(cons);			

			// loop through the contacts to assign one to each account
			Map<Id, Id> primaryMap = new Map<Id, Id>();
			for (integer i=0; i<cons.size(); i++) {
				if (!primaryMap.containsKey(cons[i].accountid)) {
					primaryMap.put(cons[i].accountid, cons[i].id);
				}
			}
			
			// create a list of accounts that need updates
			Account[] upAccts = new Account[]{};
			
			// loop through the accounts
			for (Account a : accts) {
				//SWA: ignore the default account
				if (a.Id!=DefaultAccountId) {
					Id pcid = a.primary_contact__c;
					
					// now get a new contact if needed
				   	if (pcid == null) {
				   		if (primaryMap.containsKey(a.id)) {
				   			pcid = primaryMap.get(a.id);
				   		}
					}
					
					// update the account if necessary
						// MMS: only look at contact, not title
					if (pcid != a.primary_contact__c ) {
						upAccts.add(
							new Account (
								id = a.id,
								primary_contact__c = pcid
								// primary_contact_title__c = pct
							)
						);
					}
				}
			}
			// now do the update
			//system.debug('Updating ' + upAccts.size() + ' accounts.');
			if (!upAccts.isEmpty()) {
				UpdateAccounts(upAccts);
			}
	   	}
	   	firstrun=true;
	}

	/*******************************************************************************************************
	* @description This is used by the SetPrimaryContact method to save changes to accounts.  
	* Client should override this method if they have DupeBlocker installed, so that they can
	* disable/reenable DupeBlocker's triggers. The override should look like this:
	*
	*	global virtual void UpdateAccountsDB(list<Account> listAccts) {
	*		CRMfusionDBR101.DB_Globals.triggersDisabled = true;
	*		update listAccts;
	*		CRMfusionDBR101.DB_Globals.triggersDisabled = false;
	*	}
	*			
	* and should be called in an account after insert/update trigger.
	*
	* @param listAccts The list of updated accounts objects that need to be saved.
	*/ 	
	global virtual void UpdateAccounts(list<Account> listAccts) {

    	if (GW_Utilities.IsDupBlockerInstalled) {
   			system.debug('DUPBLOCKER IS INSTALLED, SO THIS INSTANCE NEEDS TO PROVIDE Account Trigger for Enable_Primary_Contact_On_Accounts__c.');
   			system.assert(false);
   		}
		
		// if using Dupeblocker, uncomment the following line, and the one 2 lines down from that
		// CRMfusionDBR101.DB_Globals.triggersDisabled = true;
		update listAccts;
		// CRMfusionDBR101.DB_Globals.triggersDisabled = false;		
	}

	/*******************************************************************************************************
	* @description Used by the individual account maintenance methods to discover whether there is one and 
	* only one "Individual" or bucket account
	* @param indAcctName The name of the Individual or bucket account (usually "Individual")
	* @return Returns the number of accounts in the database that have the name of the Individual account.
	*/ 		
	global static integer getIndAcctCount (string indAcctName) {
		integer count = database.countquery('SELECT count() FROM Account WHERE Name=\'' + indAcctName + '\'');
		if (count == null) {
			count = 0;
		}
		return count;
	}

	/*******************************************************************************************************
	* @description Called by the Account after update trigger; sets the primary contact flag for the contact
	* @param listAcctNew List of accounts from trigger.new
	* @param listAcctOld List of accounts from trigger.old
	*/ 
	global void SetPrimaryContactForAccounts(list<Account> listAcctNew, list<Account> listAcctOld) {

		// update primary contact for all the accounts that were changed
		Set<Id> acctIds = new Set<ID>();
		for (integer i = 0; i < listAcctNew.size(); i++) {
			// check to see if the primary contact was modified
			// mod 2/09 MMS - only look at contact, not Title
			Account aOld = listAcctOld[i];
			Account aNew = listAcctNew[i];
			if (aNew.primary_contact__c != aOld.primary_contact__c) {
		 		acctIds.add(aNew.Id);	
			}
		} 
		// call the update code for the set of accounts
		if (!acctIds.isEmpty()) {
			SetPrimaryContact(acctIds); 
		}
	}

	/*******************************************************************************************************
	* @description Called by the Contact After trigger; updates primary contact on accounts
	* @param listConNew Trigger new list
	* @param listConOld Trigger old list
	* @param isInsert Trigger isInsert
	* @param isDelete Trigger isDelete
	*/ 
	global void SetPrimaryContacts(list<Contact> listConNew, list<Contact> listConOld, boolean isInsert, boolean isDelete) {
		// update primary contact for all the accounts that were changed
		Set<Id> acctIds = new Set<ID>();	
		for (integer i = 0; i < (isDelete ? listConOld.size() : listConNew.size()); i++) {
			// get the old version
			Contact cOld; 
			if (!isInsert) {
				cOld = listConOld[i];
			}
			// get the new version
			Contact cNew;
			if (!isDelete) {
				cNew = listConNew[i];
			}			 
			if (cOld!=null && cNew!=null) {
		     	// check if the person's account or title has changed
		   		if (cNew.AccountID != cOld.AccountID || cNew.Title != cOld.Title) {		
		   			// update contacts old and new accounts, if they exist
		   			if (cOld.AccountId!=null) acctIds.add(cOld.AccountId);
		   			if (cNew.AccountId!=null) acctIds.add(cNew.AccountId);
		  		}
			} else {
				// update the accounts if there are any
	   			if (cOld!=null && cOld.AccountId!=null) acctIds.add(cOld.AccountId);
				if (cNew!=null && cNew.AccountId!=null) acctIds.add(cNew.AccountId);
			}
		}
		
		// call the update code for the set of accounts
		if (!acctIds.isEmpty()) {
			SetPrimaryContact(acctIds); 	
		} 
	}		
	
////////////////////////////////////////////////////////////////////////////////////////
// TEST CODE
////////////////////////////////////////////////////////////////////////////////////////

	static testMethod void testAcctPrimaryContact() {
		
		Account testAcct;
	
		// try the function with no accts 
		ONEN_AccountMaintenance am = new ONEN_AccountMaintenance();
		am.SetPrimaryContact(new Set<ID>());
	
		// first create two test accounts
		Id secondAcctId;
		Account firstAcct = new Account(Name='Blammo Corp');
		insert firstAcct;
		system.debug('Created account: ' + firstAcct.Id);
		Account secondAcct = new Account(Name='Funny Foundation');
		insert secondAcct;
		system.debug('Created account: ' + secondAcct.Id);
		
		// add a contact with a title in that account -- primary fields should get set
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen',
			Title='Head Honcho',
			AccountId=firstAcct.Id
		);
		insert firstContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: that contact should now be the primary contact on the Account
		system.assertEquals(testAcct.primary_contact__c, firstContact.id);
		//SWA: the Account should also show the title
			// MMS: deprecated
		// system.assertEquals(testAcct.primary_contact_title__c, 'Head Honcho');

		// add a contact without a title -- primary stays the same
		Contact secondContact = new Contact (
			FirstName='Cindy',
			LastName='LooHoo',
			AccountId=firstAcct.Id
		);
		insert secondContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: first contact should still be primary contact
		system.assertEquals(testAcct.primary_contact__c, firstContact.id);
		// MMS: deprecated
		//system.assertEquals(testAcct.primary_contact_title__c, 'Head Honcho');
				
		// delete the first contact -- primary changes to the second, title gets cleared
		delete firstContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: second contact should now be primary on that Account, has no title
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		// MMS: deprecated
		// system.assertEquals(testAcct.primary_contact_title__c, null);
		
		// add a third contact -- primary stays the same
		Contact thirdContact = new Contact (
			FirstName='John',
			LastName='Baptist',
			AccountId=firstAcct.Id
		);
		insert thirdContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		
		// move the third contact out of the other account and back -- primary still the same
		thirdContact.AccountId=null;
		update thirdContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		
		thirdContact.AccountId=firstAcct.Id;
		update thirdContact;
		
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		
		// move the second contact to the other account -- check for both primaries
			// MMS: at this pt, contact 2 should be the primary for BOTH accts
		secondContact.AccountId=secondAcct.Id;
		update secondContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		testAcct = [select id, name, primary_contact__c from account where id=:secondAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);

		// try removing the account's primary contact -- it should come back
		firstAcct.primary_contact__c = null;
		update firstAcct;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact should refill if a user tries to remove it
		system.assertEquals(testAcct.primary_contact__c, thirdContact.id);

		// delete the third contact -- account should have no primary
		delete thirdContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: delete only contact from an Account shold remove the primary Contact info from the Account
		system.assertEquals(testAcct.primary_contact__c, null);
			
		// delete accounts
		Account[] testAccts = [select id from Account where name='Blammo Corp' or name='Funny Foundation'];
		system.Debug('Deleting ' + testAccts.size() + ' accounts.');
		delete testAccts;

	}
	
	static testMethod void testAcctPrimaryContactBULK() {
		
		// let's try it in bulk -- testing the governors
		Account[] a200 = new Account[]{};
		for (integer i=0;i<10;i++) {
			a200.add(new Account(Name='Test'+String.valueof(i)));
		}
		insert a200;
		Account[] a200more = new Account[]{};
		for (integer i=0;i<10;i++) {
			a200more.add(new Account(Name='Test'+String.valueof(i+10)));
		}
		insert a200more;
		Contact[] lotsaContacts = new Contact[]{};
		for (integer i=0;i<10;i++) {
			lotsaContacts.add(
				new Contact(				
					LastName='Test'+String.valueof(i),				
					AccountId=a200[i].id
				)
			);
		}
		test.starttest();
		insert lotsaContacts;
		for (integer i=0;i<10;i++) {
			lotsaContacts[i].AccountId=a200more[i].id;
		}
		update lotsaContacts;
		test.stoptest();
	}

}