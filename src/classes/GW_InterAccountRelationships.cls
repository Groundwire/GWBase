// Written by Evan Callahan, copyright (c) 2008 NPower Seattle
// Modifications by Steve Andersen, copyright (c) 2008 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

public with sharing class GW_InterAccountRelationships {

/*--------------------------------------------------------------------------------------------------------

InterAccount Relationships

This program is released under the GNU General Public License. http://www.gnu.org/licenses/

After installing this package, do the following:
- In the Account page layout, add the related list for Related Contacts and Related Accounts (but not 
  Reciprocal Relationships).  Then, double-click each of these lists and add the following fields: 
  Related Account/Contact, Relationship, From Date, and To Date (in that order).  Save the page layout.   
- Repeat these steps for the Contact page layout, adding and modifying the two related lists.
- To create a relationship, open a contact or account and click New in either related list.

--------------------------------------------------------------------------------------------------------*/
	//set of IDs of contact relationships whose mirrors were deleted in trigger
	public set<Id> accountRelIdsToDelete = new set<Id>();
	//set of IDs of accounts being deleted for orphan cleanup
	public set<Id> accountIdsForCleanup = new set<Id>();
	//map of contact rels updated in trigger
	public Map<Id,Interaccount_Relationship__c> accountRelUpdateMap = new Map<Id,Interaccount_Relationship__c>();
	//map of contact rels inserted in trigger
	public Map<Id,Interaccount_Relationship__c> accountRelsInsertedToMirror = new Map<Id,Interaccount_Relationship__c>();
	
	//list of rels to update  
	public Interaccount_Relationship__c[] accountRelsToUpdate = new Interaccount_Relationship__c[0];
	//list of rels to insert
	public Interaccount_Relationship__c[] accountRelsToInsert = new Interaccount_Relationship__c[0];
	//list of rels to delete
	public Interaccount_Relationship__c[] accountRelsToDelete = new Interaccount_Relationship__c[0];
	//list of rels to update
	public Interaccount_Relationship__c[] accountRelOriginalsToUpdate = new Interaccount_Relationship__c[0];
	
	public Interaccount_Relationship__c[] orphanedRelsToDelete = new Interaccount_Relationship__c[0];
	
	//method to delete mirrors of deleted relationships
	public void deleteAccountRelationships() {
		accountRelsToDelete = [Select id from Interaccount_Relationship__c where id IN :accountRelIdsToDelete]; 
		if (!accountRelsToDelete.isEmpty()) delete accountRelsToDelete;
		
	}
	
	//method to delete orphaned relationships
	public void deleteOrphanedAccountRelationships() {
		accountRelsToDelete = [Select id from Interaccount_Relationship__c where related_account__c = null limit 200]; 
		if (!accountRelsToDelete.isEmpty()) delete accountRelsToDelete;
		
	}
	//method to update relationships that have changed
	public void updateChangingAccountRelationships() {
		Interaccount_Relationship__c[] accountRelsForChanging = [Select To_Date__c, Relationship__c, Reciprocal_Relationship__c, Notes__c, Id, From_Date__c From Interaccount_Relationship__c where Id IN : accountRelUpdateMap.keySet()];
		//get the new values from the map on the objects if the data is different
		if(accountRelsForChanging.size()>0){
			for(Interaccount_Relationship__c thisaccountRel : accountRelsForChanging) {
				Interaccount_Relationship__c accountRelFromPreviousUpdate = accountRelUpdateMap.get(thisaccountRel.Id);
				Interaccount_Relationship__c accountRelToUpdate = new Interaccount_Relationship__c (
					Id = thisaccountRel.Id,
					To_Date__c = accountRelFromPreviousUpdate.To_Date__c,
					Relationship__c = accountRelFromPreviousUpdate.Reciprocal_Relationship__c,
					Reciprocal_Relationship__c = accountRelFromPreviousUpdate.Relationship__c,
					Notes__c = accountRelFromPreviousUpdate.Notes__c,
					From_Date__c = accountRelFromPreviousUpdate.From_Date__c				
				);
				accountRelsToUpdate.add(accountRelToUpdate);
			}
			if (!accountRelsToUpdate.isEmpty()) update accountRelsToUpdate;
		}	
	}
	//method for mirroring new relationships
	public void processNewAccountRelationships() {
		for (Interaccount_Relationship__c originalAccountRel : accountRelsInsertedToMirror.values()) {
			Interaccount_Relationship__c mirrorAccountRel = new Interaccount_Relationship__c (
				Mirror_Relationship__c = originalAccountRel.Id,
				To_Date__c = originalAccountRel.To_Date__c,
				Relationship__c = originalAccountRel.Reciprocal_Relationship__c,
				Related_Account__c = originalAccountRel.Account__c,
				Reciprocal_Relationship__c = originalAccountRel.Relationship__c,
				Notes__c = originalAccountRel.Notes__c,
				From_Date__c = originalAccountRel.From_Date__c,
				Account__c = originalAccountRel.Related_Account__c
									
			);
			
			accountRelsToInsert.add(mirrorAccountRel);			
			
		}
		if (!accountRelsToInsert.isEmpty()) insert accountRelsToInsert;
		
		
		//loop through results and update the original relationships
		for (Interaccount_Relationship__c newlyCreatedMirrorRel : accountRelsToInsert) {
			
			Interaccount_Relationship__c thisOriginal = new Interaccount_Relationship__c (
				Id = newlyCreatedMirrorRel.Mirror_Relationship__c,
				Mirror_Relationship__c = newlyCreatedMirrorRel.Id
									
			);
			
			accountRelOriginalsToUpdate.add(thisOriginal);	
		}
		if (!accountRelOriginalsToUpdate.isEmpty()) update accountRelOriginalsToUpdate;
	}
	
	// called from Account after trigger
	public static void DeleteInterAccountRelationships(list<Account> listAccts) {
		//intantiate our relationships class
		GW_InterAccountRelationships relationships = new GW_InterAccountRelationships();
		for (Account account : listAccts) {
			relationships.accountIdsForCleanup.add(account.Id);
		}
		//system.debug('count of deleted accounts: ' + relationships.accountIdsForCleanup.size());
		if (relationships.accountIdsForCleanup.size()>0) {
			relationships.deleteOrphanedaccountRelationships();
		}
	}
		
/*TESTS -----------------------------------------------------------------------------------------*/	
	
	public static testMethod void TestaccountRel() {	 
		Account firstAccount = new Account (
			Name='Company 1'
		);
		insert firstAccount;

		Account secondAccount = new Account (
			Name='Company 2'
		);
		insert secondAccount;

		Interaccount_Relationship__c[] interAccountRel = new Interaccount_Relationship__c[]{
			new Interaccount_Relationship__c(Account__c = firstAccount.id, related_Account__c = secondAccount.id, relationship__c='Vendor', reciprocal_relationship__c='Customer')
		};
		insert interAccountRel;
		
		// check that rel gets created
		Interaccount_Relationship__c interAccountRel_original = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from Interaccount_Relationship__c where id=:interAccountRel[0].Id];
		//relationship should be set right
		System.assertEquals(interAccountRel_original.relationship__c, 'Vendor');
		//reciprocal relationship should be set right
		System.assertEquals(interAccountRel_original.reciprocal_relationship__c, 'Customer');
		// check for mirror rel
		Interaccount_Relationship__c interAccountRel_mirror = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from Interaccount_Relationship__c where mirror_relationship__c=:interAccountRel_original.Id];
		//mirror should reference the original
		System.assertEquals(interAccountRel_mirror.mirror_relationship__c, interAccountRel_original.Id);
		//mirror should have the relationship set right
		System.assertEquals(interAccountRel_mirror.relationship__c, 'Customer');
		//mirror should have the reiprocal relationship set right
		System.assertEquals(interAccountRel_mirror.reciprocal_relationship__c, 'Vendor');
		//original should reference the mirror
		System.assertEquals(interAccountRel_original.mirror_relationship__c, interAccountRel_mirror.Id);
		
		
		
		// test changing the relationship
		Interaccount_Relationship__c updated_original = 
			new Interaccount_Relationship__c(id = interAccountRel_original.id, relationship__c='Core Organization', reciprocal_relationship__c='Branch / Department', notes__c = 'test')
		;
		update updated_original;
		
		// test change to the rel
		updated_original = [select id, notes__c, reciprocal_relationship__c, relationship__c from Interaccount_Relationship__c where id = :interAccountRel_original.Id];
		//original should have updated relationship
		System.assertEquals('Core Organization', updated_original.relationship__c);
		//original should have updated relationship
		System.assertEquals('Branch / Department', updated_original.reciprocal_relationship__c);
		//original should have updated notes
		System.assertEquals('test', updated_original.notes__c);
		
		Interaccount_Relationship__c updated_mirror = [select id, notes__c, reciprocal_relationship__c, relationship__c from Interaccount_Relationship__c where Mirror_Relationship__c = :interAccountRel_original.Id];
		//mirror should have relationship set right
		System.assertEquals('Branch / Department', updated_mirror.relationship__c);
		//mirror should have relationship set right
		System.assertEquals('Core Organization', updated_mirror.reciprocal_relationship__c);
		//mirror should have updated notes
		System.assertEquals('test', updated_mirror.notes__c);

		// test deleting the rel
		delete updated_original;
		Interaccount_Relationship__c[] mirror_after_original_deleted = [select id from Interaccount_Relationship__c where Mirror_Relationship__c = :interAccountRel_original.Id];
		//mirror should be deleted as well
		System.assertEquals(0, mirror_after_original_deleted.size());

	}

public static testMethod void TestOrphanedRelDelete() {	 
		
		Account firstAccount = new Account (
			Name='Company 1'
		);
		insert firstAccount;

		Account secondAccount = new Account (
			Name='Company 2'
		);
		insert secondAccount;

		Interaccount_Relationship__c[] interAccountRel = new Interaccount_Relationship__c[]{
			new Interaccount_Relationship__c(Account__c = firstAccount.id, related_Account__c = secondAccount.id, relationship__c='Vendor', reciprocal_relationship__c='Customer')
		};
		insert interAccountRel;
		
		// check that rel gets created
		Interaccount_Relationship__c interAccountRel_original = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from Interaccount_Relationship__c where id=:interAccountRel[0].Id];
		//relationship should be set right
		System.assertEquals(interAccountRel_original.relationship__c, 'Vendor');
		
		// check for mirror rel
		Interaccount_Relationship__c interAccountRel_mirror = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from Interaccount_Relationship__c where mirror_relationship__c=:interAccountRel_original.Id];
		//mirror should reference the original
		System.assertEquals(interAccountRel_mirror.mirror_relationship__c, interAccountRel_original.Id);
		
		
		Account secondAccountForDelete = [select id from account where id=:secondAccount.id];
		delete secondAccountForDelete;
		
		// test change to the rel
		Interaccount_Relationship__c[] orphanedRel = [select id from Interaccount_Relationship__c where id = :interAccountRel_original.Id];
		//original should have updated relationship
		System.assertEquals(0, orphanedRel.size());
		

	}

}