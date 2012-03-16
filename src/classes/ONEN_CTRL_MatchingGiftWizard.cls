public with sharing class ONEN_CTRL_MatchingGiftWizard {
// Written by Steve Andersen, copyright (c) 2008 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    //new gift
    Opportunity opportunity = new Opportunity();
    
    //contact to hold donor data
    public Contact donor { get {return donor;} set {donor = value;} }
    
    public Double matchMult { get {return matchMult;} set {matchMult = value;} }
    //instantiate the opportunities class
    public ONEN_OpportunityMaintenance newOpp;
    
    //constructor
    public ONEN_CTRL_MatchingGiftWizard(ApexPages.StandardController controller) {
        opportunity = (Opportunity)controller.getRecord();
        //set the class up for a new opp
        newOpp = new ONEN_OpportunityMaintenance(null);
        //get current donor role
        OpportunityContactRole[] ocrs = [Select ContactId from OpportunityContactRole where OpportunityId = :opportunity.id limit 1];
        //if there is a donor, get the id
        if (ocrs.size() > 0) {
        	newOpp.donorRoleOnMatchedGift = ocrs[0];
            newOpp.donorIdOnMatchedGift = newOpp.donorRoleOnMatchedGift.ContactId;

	        //grab donor's record
	        newOpp.donorForMatchingGift = [Select ONEN_Household__r.Name from Contact where Id = :newOpp.donorIdOnMatchedGift limit 1];
	        donor = newOpp.donorForMatchingGift;
        }       

        //instantiate the new matching gift
        newOpp.matchingGift = new Opportunity();
    }
    //save method
    public PageReference save() {
        //if no org, redirect back with a message
        if(opportunity.AccountId==null) {
            PageReference destinationPage = new PageReference('/apex/matchingGiftWizard?id=' + opportunity.id + '&error=noAcct'); 
            destinationPage.setRedirect(true);
            return destinationPage;         
        } else {            
            //get the account id
            newOpp.matchingGift.AccountId = opportunity.AccountId;
            
            //closedate
            newOpp.matchingGift.CloseDate = opportunity.CloseDate;
            //Generate the gift name
            newOpp.matchingGift.Name = newOpp.matchingGiftName(newOpp.matchingGift.CloseDate);
            //if we have a match multiplier, use it to generate the amount
            if (matchMult!=null) {
                newOpp.matchingGift.Amount = opportunity.Amount*matchMult;
            } else {
                newOpp.matchingGift.Amount = opportunity.Amount;
            }
            //grab the default stage
            newOpp.matchingGift.StageName = ONEN_Constants.OPP_DEFAULT_STAGE;
            newOpp.matchingGift.Matching_Gift__c = TRUE;
            //if donor not null, add the donor for the contact roles
            if (newOpp.donorIdOnMatchedGift!=null) {
                newOpp.matchingGift.CR_Contact_Id__c = newOpp.donorIdOnMatchedGift;
                newOpp.matchingGift.CR_Contact_Role__c = ONEN_Constants.OPP_MATCHING_GIFT_DONOR_ROLE;
                newOpp.matchingGift.CR_HHRoles__c = false;
            }
            //create the match
            insert newOpp.matchingGift;
            //redirect to it in edit mode
            PageReference matchingGiftPage = new PageReference('/' + newOpp.matchingGift.id + '/e?retURL=/' + newOpp.matchingGift.id);
            matchingGiftPage.setRedirect(true);
            return matchingGiftPage;
            
        }
        
    }
    
    static testMethod void ONEN_Test_Matching() {  
        
        Test.setCurrentPageReference(new PageReference('Page.matchingGiftWizard'));
        
        //create first account
        Account oldAccount = new Account (
            name='XYZ Organization'
        );
        insert oldAccount;
        
        //create second account
        Account newAccount = new Account (
            name='New Organization'
        );
        insert newAccount;
          
          //create first contact
          Contact firstContact = new Contact (
              FirstName='Joe',
              LastName='Schmoe',
              AccountId=oldAccount.Id  
          );
          insert firstContact;
          
          //create first opp
          Opportunity firstOpportunity = new Opportunity (
          RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
          Name='test opp',
          StageName='Prospecting',
          CloseDate=System.Today(),
          Amount=100,
          AccountId=oldAccount.Id,
          CR_Contact_Id__c = firstContact.Id,
          CR_Contact_Role__c = 'Individual Donor',
          CR_HHRoles__c = true
          );
          insert firstOpportunity; 
          

        
        //pass contact into the controller
          ApexPages.StandardController sc = new ApexPages.standardController(firstOpportunity);
          //pass the controller into the extension
          ONEN_CTRL_MatchingGiftWizard ext = new ONEN_CTRL_MatchingGiftWizard(sc);  
          ext.matchMult=.5;
          String savePage = ext.save().getUrl();
          Id newOppId = savePage.substring(1,19);
          Opportunity matchingOpp = [select id, AccountId, Name, Amount, CloseDate, Matching_Gift__c from Opportunity where Id = :newOppId limit 1]; 
          
          system.assertEquals(oldAccount.Id,matchingOpp.AccountId);
          system.assertEquals(50,matchingOpp.Amount);
          system.assertEquals(True,matchingOpp.Matching_Gift__c);
          
    }
    
    static testMethod void ONEN_Test_Matching_no_org() {  
        
        Test.setCurrentPageReference(new PageReference('Page.matchingGiftWizard'));
        
        //create first account
        Account oldAccount = new Account (
            name='XYZ Organization'
        );
        insert oldAccount;
        
        //create second account
        Account newAccount = new Account (
            name='New Organization'
        );
        insert newAccount;
          
          //create first contact
          Contact firstContact = new Contact (
              FirstName='Joe',
              LastName='Schmoe',
              AccountId=oldAccount.Id  
          );
          insert firstContact;
          
          //create first opp
          Opportunity firstOpportunity = new Opportunity (
          RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
          Name='test opp',
          StageName='Prospecting',
          CloseDate=System.Today(),
          Amount=100,
          CR_Contact_Id__c = firstContact.Id,
          CR_Contact_Role__c = 'Individual Donor',
          CR_HHRoles__c = true
          );
          insert firstOpportunity; 
          

        
        //pass contact into the controller
          ApexPages.StandardController sc = new ApexPages.standardController(firstOpportunity);
          //pass the controller into the extension
          ONEN_CTRL_MatchingGiftWizard ext = new ONEN_CTRL_MatchingGiftWizard(sc);  
          
          String savePage = ext.save().getUrl();
          
          system.assertEquals('apex',savePage.substring(1,5));
          
    }
}