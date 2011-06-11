public with sharing class ONEN_EXT_OpportunitiesMarkAs {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    public List<Opportunity> selectedOpps;

    public ONEN_EXT_OpportunitiesMarkAs(ApexPages.StandardSetController controller) {
        this.selectedOpps = (List<Opportunity>)controller.getSelected();
    }
    
    public pageReference MarkAsWon() {
        
        List<Opportunity> OppsToUpdate = new List<Opportunity>();
        for (Opportunity newOpp : selectedOpps) {
            newOpp = new Opportunity (
                id = newOpp.id,
                StageName = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE
            );
            OppsToUpdate.add(newOpp);
        }
        
        if (OppsToUpdate.size() > 0) {
            update OppsToUpdate;
        }
        PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
        
    }
    
    public pageReference MarkAsLost() {
        
        List<Opportunity> OppsToUpdate = new List<Opportunity>();
        for (Opportunity newOpp : selectedOpps) {
            newOpp = new Opportunity (
                id = newOpp.id,
                StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE
            );
            OppsToUpdate.add(newOpp);
        }
        
        if (OppsToUpdate.size() > 0) {
            update OppsToUpdate;
        }
        
        PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
        
    }
    
    public pageReference MarkAsThanked() {
        
        List<Opportunity> OppsToUpdate = new List<Opportunity>();
        for (Opportunity newOpp : selectedOpps) {
            newOpp = new Opportunity (
                id = newOpp.id,
                StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE
            );
            OppsToUpdate.add(newOpp);
        }
        
        if (OppsToUpdate.size() > 0) {
            update OppsToUpdate;
        }
        
        PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
        
    }

//////////////////
// TEST METHODS
///////////////////
    public static testMethod void TestMarkAsWon() {
    
    //new contact
    //create first contact
      Contact firstContact = new Contact (
      FirstName='Joe',
      LastName='Schmoe_for_tests'
      );
      insert firstContact;
    
    //new opp for contact
    Opportunity firstOpp = new Opportunity (
        RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
        Name = 'Test first contact opp',
        amount=100,
        StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
        CloseDate=Date.newInstance(2005,10,10),
        CR_Contact_Id__c = firstContact.id,
        CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
    );
    
    insert firstOpp;
    
    List<Opportunity> selectedOpps = new List<Opportunity>();
    
    selectedOpps.add(firstOpp);
    
    PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
    Test.setCurrentPage(p);
    
    //pass selected opportunities into the controller
    ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
    sc.setSelected(selectedOpps);
    //pass the controller into the extension
    ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
    
    ext.MarkAsWon();
    
    Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id = :firstOpp.id ];
    system.assertEquals(1,Opps.size());
    System.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE,Opps[0].StageName);
    
    }
    
    
    public static testMethod void TestMarkAsThanked() {
    
    //new contact
    //create first contact
      Contact firstContact = new Contact (
      FirstName='Joe',
      LastName='Schmoe_for_tests'
      );
      insert firstContact;
    
    //new opp for contact
    Opportunity firstOpp = new Opportunity (
        RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
        Name = 'Test first contact opp',
        amount=100,
        StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
        CloseDate=Date.newInstance(2005,10,10),
        CR_Contact_Id__c = firstContact.id,
        CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
    );
    
    insert firstOpp;
    
    List<Opportunity> selectedOpps = new List<Opportunity>();
    
    selectedOpps.add(firstOpp);
    
    PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
    Test.setCurrentPage(p);
    
    //pass selected opportunities into the controller
    ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
    sc.setSelected(selectedOpps);
    //pass the controller into the extension
    ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
    
    ext.MarkAsThanked();
    
    Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id = :firstOpp.id ];
    system.assertEquals(1,Opps.size());
    System.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,Opps[0].StageName);
    
    }

    public static testMethod void TestMarkAsThankedMany() {
    
    //new contact
    //create first contact
      Contact firstContact = new Contact (
      FirstName='Joe',
      LastName='Schmoe_for_tests'
      );
      insert firstContact;
    
    //new opps for contact
    List<Opportunity> selectedOpps = new List<Opportunity>();
    integer cOpp = 10; // Salesforce Bug! If you make this 100, you hit too many SOQL queries, because SF isn't batching correctly.
    for (integer i = 0; i < cOpp; i++) {
        Opportunity firstOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name = 'Test first contact opp ' + string.valueOf(i),
            amount=100,
            StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
            CloseDate=(Date.newInstance(2005,10,10)).AddMonths(i),
            CR_Contact_Id__c = firstContact.id,
            CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
        );
        
        selectedOpps.add(firstOpp);
    }   
    insert selectedOpps;
    
    PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
    Test.setCurrentPage(p);
    
    //pass selected opportunities into the controller
    ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
    sc.setSelected(selectedOpps);
    //pass the controller into the extension
    ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
    
    ext.MarkAsThanked();
    
    // verify
    set<ID> setOppId = new set<ID>();
    for (integer i = 0; i < cOpp; i++) {
        setOppId.add(selectedOpps[i].id);
    }
    Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id in :setOppId];
    system.assertEquals(cOpp,Opps.size());
    System.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,Opps[0].StageName);
    
    }

    public static testMethod void TestMarkAsLost() {
    
    //new contact
    //create first contact
      Contact firstContact = new Contact (
      FirstName='Joe',
      LastName='Schmoe_for_tests'
      );
      insert firstContact;
    
    //new opp for contact
    Opportunity firstOpp = new Opportunity (
        RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
        Name = 'Test first contact opp',
        amount=100,
        StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
        CloseDate=Date.newInstance(2005,10,10),
        CR_Contact_Id__c = firstContact.id,
        CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
    );
    
    insert firstOpp;
    
    List<Opportunity> selectedOpps = new List<Opportunity>();
    
    selectedOpps.add(firstOpp);
    
    PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
    Test.setCurrentPage(p);
    
    //pass selected opportunities into the controller
    ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
    sc.setSelected(selectedOpps);
    //pass the controller into the extension
    ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
    
    ext.MarkAsLost();
    
    Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id = :firstOpp.id ];
    system.assertEquals(1,Opps.size());
    System.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE,Opps[0].StageName);
    
    }

}