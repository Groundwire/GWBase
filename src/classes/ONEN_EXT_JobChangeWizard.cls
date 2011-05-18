public class ONEN_EXT_JobChangeWizard {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	id OldAccountId;
	
	Contact contact = new Contact();
	
	Account_Relationship__c relationship = new Account_Relationship__c (); 

    public ONEN_EXT_JobChangeWizard(ApexPages.StandardController controller) {
        this.contact = (Contact)controller.getRecord();
    	//capture the AccountId for the contact before it changes via the form
        OldAccountId = this.contact.AccountId;
        contact.AccountId = null;
	}

	//getter for the relationship object for the form
    public Account_Relationship__c  getRelationship() {
        if(relationship == null) relationship = new Account_Relationship__c ();
        return relationship;
    } 
    //getter for the contact
    public Contact getContact() {         
        if(contact == null) contact = new Contact();        
        return contact;
    }
    //save action
    public PageReference save() {
        try {
         	update contact;
         
	    } catch (DmlException e) {
            ApexPages.addMessages(e);   
            return null;         	         
	    }
          
        //if they aren't coming from the Individual Account, create the relationship
        if(OldAccountId <> ONEN_DefaultAccount.GetIndividualAccountId()) { 
	        relationship.Related_Account__c = OldAccountId;
	        relationship.Contact__c = contact.id;
	        relationship.Relationship__c = ONEN_Constants.StrJobChangeWizardEmployeeRelationship;
	        
	        try {
     			insert relationship;
     
    		} catch (DmlException e) {
	            ApexPages.addMessages(e);   
	            return null;         	                  
    		}
	        
	        
        }
           
        PageReference p = new PageReference('/' + contact.id);
        //refresh page
        p.setRedirect(true);
        return p;
    }


/////////////////////////////////////////
// TEST CODE
/////////////////////////////////////////

 	static testMethod void ONEN_Test_Changing_The_Job() {  
		  
		Test.setCurrentPageReference(new PageReference('Page.Job_Change'));		 
		Id oldAccountId;
		Id newAccountId; 
		  
		//create first account
		Account oldAccount = new Account (
			name='XYZ Organization'
		);
		insert oldAccount;
		oldAccountId = oldAccount.id;
		  
		//create first contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Schmoe',
			AccountId=oldAccountId  
		);
		insert firstContact;
		  
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(firstContact);
		//pass the controller into the extension
		ONEN_EXT_JobChangeWizard ext = new ONEN_EXT_JobChangeWizard(sc);  
		    
		//create second account
		Account newAccount = new Account (
			name='ABC Organization'
		);
		insert newAccount;
		  
		newAccountId = newAccount.id; 
		   
		//Get the contact from the extension and associate it with a new account
		ext.getContact().AccountId = newAccountId;
		//Call the save method to save the page and activate the extension
		String savePage = ext.save().getUrl();
		  
		Contact createdContact = [select Account.Name from Contact where Id =:firstContact.id];
		   
		//Test to see if the contact now has the new AccountId
		System.assertEquals('ABC Organization',createdContact.Account.Name);
		   
		Account_Relationship__c relationship = [select id, Contact__c, Relationship__c, Related_Account__c, To_Date__c from Account_Relationship__c where Contact__c = :firstContact.id limit 1]; 
		  
		//Test to see if the child record that get created has the old Org. Id and apprpriate relationship type
		System.assertEquals(oldAccountId,relationship.Related_Account__c);
		System.assertEquals('Employee',relationship.Relationship__c);
		  
		System.Assert(ext.Contact != null);
		System.Assert(ext.getRelationship() != null);
	}
 
 	static testMethod void ONEN_Test_Changing_The_Job_from_individual() {  
		//the relationship shouldn't be created if the contact was in the
		//individual account
		Test.setCurrentPageReference(new PageReference('Page.Job_Change'));
		 
		Id newAccountId; 
		  		  
		//create first contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Schmoe',
			AccountId=ONEN_DefaultAccount.GetIndividualAccountId() 
		);
		insert firstContact;
		  
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(firstContact);
		//pass the controller into the extension
		ONEN_EXT_JobChangeWizard ext = new ONEN_EXT_JobChangeWizard(sc);  
		    
		//create second account
		Account newAccount = new Account (
			name='ABC Organization'
		);
		insert newAccount;
		  
		newAccountId = newAccount.id; 
		   
		//Get the contact from the extension and associate it with a new account
		ext.getContact().AccountId = newAccountId;
		//Call the save method to save the page and activate the extension
		String savePage = ext.save().getUrl();
		   
		Account_Relationship__c[] relationship = [select id, Contact__c, Related_Account__c, Relationship__c, To_Date__c from Account_Relationship__c where Contact__c = :firstContact.id limit 1]; 
		  
		//Test to see that the relationship wasn't created
		System.assertEquals(0,relationship.size());		  
		  
 	}
}