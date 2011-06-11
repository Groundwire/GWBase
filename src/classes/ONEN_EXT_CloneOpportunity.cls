public with sharing class ONEN_EXT_CloneOpportunity {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Verison 3. http://www.gnu.org/licenses/
    
    Opportunity opportunity = new Opportunity();
    ONEN_OpportunityMaintenance newOpp;
    Integer Offset;
    String OffsetUnit;
    Public Id newOppId;
    
    public ONEN_EXT_CloneOpportunity(ApexPages.StandardController controller) {
        this.opportunity = (Opportunity)controller.getRecord();
        newOpp = new ONEN_OpportunityMaintenance(null);
        newOpp.thisOpp = [SELECT Id, Name, CloseDate, AccountId, Amount,CampaignId,RecordTypeId,StageName FROM Opportunity WHERE id=:opportunity.id LIMIT 1];
        Offset = Integer.valueOf(System.currentPageReference().getParameters().get('offset'));
        OffsetUnit = System.currentPageReference().getParameters().get('offsetunit');
    }
    
    Public PageReference cloneOpp() {
        newOppId = newOpp.cloneThisOpp(Offset,OffsetUnit);
        PageReference p = new PageReference('/' + newOppId + '/e?retURL=/' + newOppId);
        p.setRedirect(true);
        return p;
    }
    static testMethod void test_clone_one_month() { 
        
        Test.setCurrentPageReference(new PageReference('Page.cloneOpp')); 
        ApexPages.currentPage().getParameters().put('offset','1');
        ApexPages.currentPage().getParameters().put('offsetunit','Month');
        
        //create first contact
          Contact firstContact = new Contact (
          FirstName='Joe',
          LastName='Schmoe_for_tests'
          );
          insert firstContact;
        
        //new opp for contact
        Opportunity firstOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name = 'Test frst  contact opp',
            amount=100,
            StageName='Prospecting',
            CloseDate=Date.newInstance(2005,10,10),
            CR_Contact_Id__c = firstContact.id,
            CR_Contact_Role__c = 'Individual Donor'
        );
        
        insert firstOpp;
        //ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(firstOpp);
        //pass the controller into the extension
        ONEN_EXT_CloneOpportunity ext = new ONEN_EXT_CloneOpportunity(sc); 
        
        //system.assertEquals('junk','This Opp: ' + ext.opportunity);
        
        PageReference newOppPageRef = ext.cloneOpp();
        
        Opportunity[] Opps = [SELECT Name, CloseDate FROM Opportunity where CR_Contact_Id__c = :firstContact.id order by CloseDate];
        system.assertEquals(2,Opps.size());
        System.assertEquals('Joe Schmoe_for_tests 11/2005 ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,Opps[1].Name);
        //system.assertEquals(system.Today().addMonths(1),clonedOpp.CloseDate);
        OpportunityContactRole[] clonedOppRole = [SELECT OpportunityId,Opportunity.CloseDate from OpportunityContactRole WHERE ContactId=:firstContact.id];
        system.assertEquals(2,clonedOppRole.size());
        //system.assertEquals(system.Today().addMonths(1),clonedOppRole.Opportunity.CloseDate);

    }
    static testMethod void test_clone_two_years() { 
        
        Test.setCurrentPageReference(new PageReference('Page.cloneOpp')); 
        ApexPages.currentPage().getParameters().put('offset','2');
        ApexPages.currentPage().getParameters().put('offsetunit','year');
        
        //create first contact
          Contact firstContact = new Contact (
          FirstName='Joe',
          LastName='Schmoe_for_tests'
          );
          insert firstContact;
        
        //new opp for contact
        Opportunity firstOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name = 'Test frst  contact opp',
            amount=100,
            StageName='Prospecting',
            CloseDate=Date.newInstance(2005,10,10),
            CR_Contact_Id__c = firstContact.id,
            CR_Contact_Role__c = 'Individual Donor'
        );
        
        insert firstOpp;
        //ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(firstOpp);
        //pass the controller into the extension
        ONEN_EXT_CloneOpportunity ext = new ONEN_EXT_CloneOpportunity(sc); 
          PageReference newOppPageRef = ext.cloneOpp();
        
        Opportunity clonedOpp = [SELECT Name, AccountId, StageName, CloseDate FROM Opportunity where id=:ext.newOppId];
        
        system.assertEquals(Date.newInstance(2005,10,10).addYears(2),clonedOpp.CloseDate);
        //new opp should be created with correct name
    //  System.assertEquals('Org 1 2006 ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,clonedOpp[0].Name);
        /*System.assertEquals(firstAccount.Id,clonedOpp[0].AccountId);
        System.assertEquals(ONEN_Constants.OPP_DEFAULT_STAGE,clonedOpp[0].StageName); 
        System.assertEquals(opp1.CloseDate.addYears(1),clonedOpp[0].CloseDate); 
        */

    }
    
    static testMethod void testCloneOppAccount(){
        Test.setCurrentPageReference(new PageReference('Page.cloneOpp')); 
        ApexPages.currentPage().getParameters().put('offset','1');
        ApexPages.currentPage().getParameters().put('offsetunit','year');
        //create a contact
        Account firstAccount = new Account (
            Name='Org 1'            
        );
    
        insert firstAccount;
        
        //create a gift
        Opportunity opp1 = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name='Org 1 Gift',
            CloseDate=Date.newInstance(2005,10,10),
            StageName='Closed Won',
            Amount=100,
            AccountId = firstAccount.Id
        );
        
        insert opp1;
        Id NewOppId;
    
        system.debug ('TEST>>>>> cloning Opp 1 - 1 year out');
        //ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(opp1);
        //pass the controller into the extension
        ONEN_EXT_CloneOpportunity ext = new ONEN_EXT_CloneOpportunity(sc); 
          
        PageReference newOppPageRef = ext.cloneOpp();
        Opportunity clonedOpp = [SELECT Name, AccountId, StageName, CloseDate FROM Opportunity where id=:ext.newOppId];
    
        //new opp should be created with correct name
        //System.assertEquals('Org 1 2006 ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,clonedOpp.Name);
        System.assertEquals(firstAccount.Id,clonedOpp.AccountId);
        System.assertEquals(ONEN_Constants.OPP_DEFAULT_STAGE,clonedOpp.StageName); 
        System.assertEquals(opp1.CloseDate.addYears(1),clonedOpp.CloseDate); 
    
    
    
    }
}