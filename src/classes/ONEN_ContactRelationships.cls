public class ONEN_ContactRelationships {
// Written by Evan Callahan, copyright (c) 2008 NPower Seattle
// Modifications by Steve Andersen, copyright (c) 2008 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*--------------------------------------------------------------------------------------------------------

Contact Relationships

After installing this package, do the following:
- In the Account page layout, add the related list for Related Contacts and Related Accounts (but not 
  Reciprocal Relationships).  Then, double-click each of these lists and add the following fields: 
  Related Account/Contact, Relationship, From Date, and To Date (in that order).  Save the page layout.   
- Repeat these steps for the Contact page layout, adding and modifying the two related lists.
- To create a relationship, open a contact or account and click New in either related list.

--------------------------------------------------------------------------------------------------------*/
	//set of IDs of contact relationships whose mirrors were deleted in trigger
	public set<Id> contactRelIdsToDelete = new set<Id>();
	//set of IDs of contacts being deleted for orphan cleanup
	public set<Id> contactIdsForCleanup = new set<Id>();
	//map of contact rels updated in trigger
	public Map<Id,Contact_Relationship__c> contactRelUpdateMap = new Map<Id,Contact_Relationship__c>();
	//map of contact rels inserted in trigger
	public Map<Id,Contact_Relationship__c> contactRelsInsertedToMirror = new Map<Id,Contact_Relationship__c>();
	
	//list of rels to update 
	public Contact_Relationship__c[] contactRelsToUpdate = new Contact_Relationship__c[0];
	//list of rels to insert
	public Contact_Relationship__c[] contactRelsToInsert = new Contact_Relationship__c[0];
	//list of rels to delete
	public Contact_Relationship__c[] contactRelsToDelete = new Contact_Relationship__c[0];
	//list of rels to update
	public Contact_Relationship__c[] contactRelOriginalsToUpdate = new Contact_Relationship__c[0];
	
	public Contact_Relationship__c[] orphanedRelsToDelete = new Contact_Relationship__c[0];
	
	//method to delete mirrors of deleted relationships
	public void deleteContactRelationships() {
		contactRelsToDelete = [Select id from Contact_Relationship__c where id IN :contactRelIdsToDelete]; 
		if (!contactRelsToDelete.isEmpty()) delete contactRelsToDelete;
		
	}
	
	//method to delete orphaned relationships
	public void deleteOrphanedContactRelationships() {
		contactRelsToDelete = [Select id from Contact_Relationship__c where related_contact__c = null limit 200]; 
		if (!contactRelsToDelete.isEmpty()) delete contactRelsToDelete;
		
	}
	//method to update relationships that have changed
	public void updateChangingContactRelationships() {
		Contact_Relationship__c[] contactRelsForChanging = [Select To_Date__c, Relationship__c, Reciprocal_Relationship__c, Notes__c, Id, From_Date__c From Contact_Relationship__c where Id IN : contactRelUpdateMap.keySet()];
		//get the new values from the map on the objects if the data is different
		if(contactRelsForChanging.size()>0){
			for(Contact_Relationship__c thisContactRel : contactRelsForChanging) {
				Contact_Relationship__c contactRelFromPreviousUpdate = contactRelUpdateMap.get(thisContactRel.Id);
				Contact_Relationship__c contactRelToUpdate = new Contact_Relationship__c (
					Id = thisContactRel.Id,
					To_Date__c = contactRelFromPreviousUpdate.To_Date__c,
					Relationship__c = contactRelFromPreviousUpdate.Reciprocal_Relationship__c,
					Reciprocal_Relationship__c = contactRelFromPreviousUpdate.Relationship__c,
					Notes__c = contactRelFromPreviousUpdate.Notes__c,
					From_Date__c = contactRelFromPreviousUpdate.From_Date__c				
				);
				contactRelsToUpdate.add(contactRelToUpdate);
			}
			if (!contactRelsToUpdate.isEmpty()) update contactRelsToUpdate;
		}	
	}
	//method for mirroring new relationships
	public void processNewContactRelationships() {
		for (Contact_Relationship__c originalContactRel : contactRelsInsertedToMirror.values()) {
			Contact_Relationship__c mirrorContactRel = new Contact_Relationship__c (
				Mirror_Relationship__c = originalContactRel.Id,
				To_Date__c = originalContactRel.To_Date__c,
				Relationship__c = originalContactRel.Reciprocal_Relationship__c,
				Related_Contact__c = originalContactRel.Contact__c,
				Reciprocal_Relationship__c = originalContactRel.Relationship__c,
				Notes__c = originalContactRel.Notes__c,
				From_Date__c = originalContactRel.From_Date__c,
				Contact__c = originalContactRel.Related_Contact__c
									
			);
			
			contactRelsToInsert.add(mirrorContactRel);			
			
		}
		if (!contactRelsToInsert.isEmpty()) insert contactRelsToInsert;
		
		
		//loop through results and update the original relationships
		for (Contact_Relationship__c newlyCreatedMirrorRel : contactRelsToInsert) {
			
			Contact_Relationship__c thisOriginal = new Contact_Relationship__c (
				Id = newlyCreatedMirrorRel.Mirror_Relationship__c,
				Mirror_Relationship__c = newlyCreatedMirrorRel.Id
									
			);
			
			contactRelOriginalsToUpdate.add(thisOriginal);	
		}
		if (!contactRelOriginalsToUpdate.isEmpty()) update contactRelOriginalsToUpdate;
	}
	

	// called from the Contact after trigger
	public static void DeleteOrphanedRelationships(list<Contact> listContact) {
	
		//intantiate our relationships class
		ONEN_ContactRelationships relationships = new ONEN_ContactRelationships();
		for (Contact contact : listContact) {
			relationships.contactIdsForCleanup.add(contact.Id);
		}
		//system.debug('count of deleted contacts: ' + relationships.contactIdsForCleanup.size());
		if (relationships.contactIdsForCleanup.size()>0) {
			relationships.deleteOrphanedContactRelationships();
		}		
	}
	
/*TESTS -----------------------------------------------------------------------------------------*/	
	
	public static testMethod void TestContactRel() {
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen'
		);
		insert firstContact;

		Contact secondContact = new Contact (
			FirstName='Bobby',
			LastName='Johanssen'
		);
		insert secondContact;

		contact_relationship__c[] crel = new contact_relationship__c[]{
			new contact_relationship__c(contact__c = firstContact.id, related_contact__c = secondContact.id, relationship__c='Uncle', reciprocal_relationship__c='Nephew')
		};
		insert crel;
		
		// check that rel gets created
		contact_relationship__c crel_original = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from contact_relationship__c where id=:crel[0].Id];
		//relationship should be set right
		System.assertEquals(crel_original.relationship__c, 'Uncle');
		//reciprocal relationship should be set right
		System.assertEquals(crel_original.reciprocal_relationship__c, 'Nephew');
		// check for mirror rel
		contact_relationship__c crel_mirror = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from contact_relationship__c where mirror_relationship__c=:crel_original.Id];
		//mirror should reference the original
		System.assertEquals(crel_mirror.mirror_relationship__c, crel_original.Id);
		//mirror should have the relationship set right
		System.assertEquals(crel_mirror.relationship__c, 'Nephew');
		//mirror should have the reiprocal relationship set right
		System.assertEquals(crel_mirror.reciprocal_relationship__c, 'Uncle');
		//original should reference the mirror
		System.assertEquals(crel_original.mirror_relationship__c, crel_mirror.Id);
		
		
		
		// test changing the relationship
		contact_relationship__c updated_original = 
			new contact_relationship__c(id = crel_original.id, relationship__c='Aunt', reciprocal_relationship__c='Niece', notes__c = 'test')
		;
		update updated_original;
		
		// test change to the rel
		updated_original = [select id, notes__c, reciprocal_relationship__c, relationship__c from contact_relationship__c where id = :crel_original.Id];
		//original should have updated relationship
		System.assertEquals('Aunt', updated_original.relationship__c);
		//original should have updated relationship
		System.assertEquals('Niece', updated_original.reciprocal_relationship__c);
		//original should have updated notes
		System.assertEquals('test', updated_original.notes__c);
		
		contact_relationship__c updated_mirror = [select id, notes__c, reciprocal_relationship__c, relationship__c from contact_relationship__c where Mirror_Relationship__c = :crel_original.Id];
		//mirror should have relationship set right
		System.assertEquals('Niece', updated_mirror.relationship__c);
		//mirror should have relationship set right
		System.assertEquals('Aunt', updated_mirror.reciprocal_relationship__c);
		//mirror should have updated notes
		System.assertEquals('test', updated_mirror.notes__c);

		// test deleting the rel
		delete updated_original;
		contact_relationship__c[] mirror_after_original_deleted = [select id from contact_relationship__c where Mirror_Relationship__c = :crel_original.Id];
		//mirror should be deleted as well
		System.assertEquals(0, mirror_after_original_deleted.size());

	}
	
	public static testMethod void TestOrphanedRelDelete() {	 
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen'
		);
		insert firstContact;

		Contact secondContact = new Contact (
			FirstName='Bobby',
			LastName='Johanssen'
		);
		insert secondContact;

		contact_relationship__c[] crel = new contact_relationship__c[]{
			new contact_relationship__c(contact__c = firstContact.id, related_contact__c = secondContact.id, relationship__c='Uncle', reciprocal_relationship__c='Nephew')
		};
		insert crel;
		
		// check that rel gets created
		contact_relationship__c crel_original = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from contact_relationship__c where id=:crel[0].Id];
		//relationship should be set right
		System.assertEquals(crel_original.relationship__c, 'Uncle');

		// check for mirror rel
		contact_relationship__c crel_mirror = [select id, notes__c, reciprocal_relationship__c, relationship__c,mirror_relationship__c from contact_relationship__c where mirror_relationship__c=:crel_original.Id];
		//mirror should reference the original
		System.assertEquals(crel_mirror.mirror_relationship__c, crel_original.Id);
		Contact secondContactForDelete = [select id from contact where id=:secondContact.id];
		delete secondContactForDelete;
		
		// test change to the rel
		contact_relationship__c[] orphanedCrel = [select id from contact_relationship__c where id = :crel_original.Id];
		//original should have updated relationship
		System.assertEquals(0, orphanedCrel.size());
		

	}

}