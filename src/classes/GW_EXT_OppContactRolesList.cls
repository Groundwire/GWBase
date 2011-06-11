public with sharing class GW_EXT_OppContactRolesList {

    //list of all contact roles, existing and blank for the page
    public List<OpportunityContactRole> conRolesList { get; set; }
    public OpportunityContactRole editConRole { get; set; }
    public boolean nowAdding { get; private set; }
    
    public List<OpportunityContactRole> fullConRolesList { get {
        List<OpportunityContactRole> fullConRolesList = new List<OpportunityContactRole>();
        fullConRolesList.addAll(conRolesList);
        if (nowAdding != null && nowAdding && editConRole != null) {
            fullConRolesList.add(editConRole);
        }
        return fullConRolesList;
    }}
    
    public boolean hasMessages { get {return ApexPages.hasMessages();} }
    
    //opporunity id from the page
    public id oppId {get; set
        {
            this.oppId = value;
            conRolesList = queryConRolesList();
        } 
    }
    
    public GW_EXT_OppContactRolesList(ApexPages.StandardController stdController) {
        //grab the opportunity Id from the opp record we're on
        oppId = stdController.getId();
        nowAdding = false;
    }

    public void addNewRow() {
        OpportunityContactRole newRow = new OpportunityContactRole(opportunityid = oppId, Role=null);
        editConRole = newRow;
        nowAdding = true;
    }

    //These methods are responsible for editing and deleting an EXISTING condition
    public String getParam(String name) {
        return ApexPages.currentPage().getParameters().get(name);  
    }

    public void delConRole() {
        String delid = getParam('delid');
        try {
            OpportunityContactRole ocr = [SELECT Id FROM OpportunityContactRole WHERE ID=:delid];
            delete ocr;
            conRolesList = queryConRolesList();
        } catch (system.Dmlexception e) {
            ApexPages.addMessages(e);
        }
    }
    
    public void editOneConRole() {
        String editid = getParam('editid');
        editConRole  = [SELECT id, ContactId, isPrimary, Role, Contact.Email, Contact.Account.Name, Contact.Name,
              Contact.AccountId, Contact.Phone, Opportunity.ContactId__c, Opportunity.AccountId, OpportunityId FROM
              OpportunityContactRole where id = :editId]; 
    }

    
    public void cancelEdit() {
        editConRole = null;
        nowAdding = false;
    }
    
    public void saveEdit() { 
        try { 
            boolean primaryAssigned = false;
            // Refresh list of contact roles
            List<OpportunityContactRole> existingConRoles = queryConRolesList();

            List<OpportunityContactRole> conRolesToUpsert = new List<OpportunityContactRole>();
            
            // if there's no existing contact role
            if (existingConRoles.size() == 0) {
                editConRole.isPrimary = true;
                primaryAssigned = true;
            } else {
	            for (OpportunityContactRole ocr : existingConRoles) {
	                if (ocr.IsPrimary == true && ocr.id != editConRole.id) {
	                    primaryAssigned = true;
	                    if (editConRole.isPrimary) ocr.IsPrimary = false;
	                    conRolesToUpsert.add(ocr);
	                    break;
	                }
	            }
            }
            
            if (primaryAssigned || editConRole.isPrimary) {
                //system.debug('Edit ConRole '+ editconrole);
                //system.debug('ConRoles for my update ' + conRolesToUpsert);
     
                conRolesToUpsert.add(editConRole);
                upsert conRolesToUpsert id; 
                
                editConRole = null;
                nowAdding = false;
                
                conRolesList = queryConRolesList();
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Fatal, 'You must assign a primary contact.'));
            }
            
        } catch (system.Dmlexception e) {
            ApexPages.addMessages(e);
        }
        
        //return null;
    } 
    
    private List<OpportunityContactRole> queryConRolesList() {
     	return [SELECT id, ContactId, isPrimary, Role, Contact.Email,Opportunity.ContactId__c, Contact.Name, Contact.Account.Name, 
              Contact.AccountId, Contact.Phone, OpportunityId, Opportunity.AccountId FROM
              OpportunityContactRole WHERE
              OpportunityId = :oppId ORDER BY IsPrimary DESC,LastModifiedDate];
    } 
    
    /******************* TESTS ********************/
  
    static testmethod void addNewConRole() {
        Opportunity opp = new Opportunity(
            Name='Test_Opportunity',
            CloseDate = system.today(),
            StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            Amount = 100
            );
        insert opp;
        
        Contact con = new Contact (LastName = 'Vandalay_');
        insert con;
        
        PageReference pageRef = new PageReference(opp.id);
        Test.setCurrentPageReference(pageRef);
        
        ApexPages.Standardcontroller OppController = new ApexPages.Standardcontroller(opp);
        ApexPages.currentPage().getParameters().put('id',opp.id);
        GW_EXT_OppContactRolesList crl = new GW_EXT_OppContactRolesList(OppController);
        
        system.assertEquals(0,crl.conRolesList.size());
        crl.addNewRow();
        crl.editConRole.isPrimary = true;
        crl.editConRole.Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
        crl.editConRole.ContactId = con.id;
        crl.saveEdit();
        
        List<OpportunityContactRole> createdOCRs = [SELECT ContactId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId = :opp.id AND ContactId = :con.id];
        system.assertEquals(true,createdOCRs[0].isPrimary);
        system.assertEquals(ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS),createdOCRs[0].Role);
    
    } 
    
    static testmethod void updateOneToNoPrimaryConRole() {
        Opportunity opp = new Opportunity(
            Name='Test_Opportunity',
            CloseDate = system.today(),
            StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            Amount = 100
            );
        insert opp;
        
        Contact con = new Contact (LastName = 'Vandalay_');
        insert con;
        
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.id, 
            ContactId = con.id, 
            Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            IsPrimary = true); 
        insert ocr;
        
        PageReference pageRef = new PageReference(opp.id);
        Test.setCurrentPageReference(pageRef);
        
        ApexPages.Standardcontroller OppController = new ApexPages.Standardcontroller(opp);
        ApexPages.currentPage().getParameters().put('id',opp.id);
        GW_EXT_OppContactRolesList crl = new GW_EXT_OppContactRolesList(OppController);
        
        ApexPages.currentPage().getParameters().put('editid',ocr.id);
        crl.editOneConRole();
        crl.editConRole.isPrimary = false;
        crl.saveEdit();
        
        system.assert(apexPages.hasMessages()); 
            
    }
    
    static testmethod void updateTwoToNoPrimaryConRoles() {
        Opportunity opp = new Opportunity(
            Name='Test_Opportunity',
            CloseDate = system.today(),
            StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            Amount = 100
            );
        insert opp;
        
        Contact con = new Contact (LastName = 'Vandalay_');
        insert con;
        
        Contact con2 = new Contact (LastName = 'Vandalay_');
        insert con2;
        
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.id, 
            ContactId = con.id, 
            Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            IsPrimary = true); 
        insert ocr;
        
        OpportunityContactRole ocr2 = new OpportunityContactRole(
            OpportunityId = opp.id, 
            ContactId = con2.id, 
            Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            IsPrimary = false); 
        insert ocr2;
        
        PageReference pageRef = new PageReference(opp.id);
        Test.setCurrentPageReference(pageRef);
        
        ApexPages.Standardcontroller OppController = new ApexPages.Standardcontroller(opp);
        ApexPages.currentPage().getParameters().put('id',opp.id);
        GW_EXT_OppContactRolesList crl = new GW_EXT_OppContactRolesList(OppController);
        
        ApexPages.currentPage().getParameters().put('editid',ocr.id);
        system.assertEquals(ocr.id,crl.getParam('editid'));
        
        crl.editOneConRole();
        crl.editConRole.isPrimary = false;
        crl.saveEdit();
        
        system.assert(apexPages.hasMessages()); 
        
        ApexPages.currentPage().getParameters().put('editid',ocr.id);
        crl.editOneConRole();
        crl.cancelEdit();
        
    }
    
    static testmethod void updateTwoToNewPrimaryConRole() {
        Opportunity opp = new Opportunity(
            Name='Test_Opportunity',
            CloseDate = system.today(),
            StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            Amount = 100
            );
        insert opp;
        
        Contact con = new Contact (LastName = 'Vandalay_');
        insert con;
        
        Contact con2 = new Contact (LastName = 'Vandalay_');
        insert con2;
        
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.id, 
            ContactId = con.id, 
            Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            IsPrimary = true); 
        insert ocr;
        
        OpportunityContactRole ocr2 = new OpportunityContactRole(
            OpportunityId = opp.id, 
            ContactId = con2.id, 
            Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            IsPrimary = false); 
        insert ocr2;
        
        PageReference pageRef = new PageReference(opp.id);
        Test.setCurrentPageReference(pageRef);
        
        ApexPages.Standardcontroller OppController = new ApexPages.Standardcontroller(opp);
        ApexPages.currentPage().getParameters().put('id',opp.id);
        GW_EXT_OppContactRolesList crl = new GW_EXT_OppContactRolesList(OppController);
        
        ApexPages.currentPage().getParameters().put('editid',ocr2.id);
        crl.editOneConRole();
        crl.editConRole.isPrimary = true;
        crl.saveEdit();
        
        List<OpportunityContactRole> newPrimaryOCRs = [SELECT ContactId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId = :opp.id AND ContactId = :con2.id];
        system.assertEquals(true,newPrimaryOCRs[0].isPrimary);
        
        List<OpportunityContactRole> nonPrimaryOCRs = [SELECT ContactId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId = :opp.id AND ContactId = :con.id];
        system.assertEquals(false,nonPrimaryOCRs[0].isPrimary);
        
    } 
    
    static testmethod void deleteExistingConRole() {
        Opportunity opp = new Opportunity(
            Name='Test_Opportunity',
            CloseDate = system.today(),
            StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            Amount = 100
            );
        insert opp;
        
        Contact con = new Contact (LastName = 'Vandalay_');
        insert con;
        
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opp.id, 
            ContactId = con.id, 
            Role = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            IsPrimary = true); 
        insert ocr;
        
        ApexPages.Standardcontroller OppController = new ApexPages.Standardcontroller(opp);
        ApexPages.currentPage().getParameters().put('id',opp.id);
        GW_EXT_OppContactRolesList crl = new GW_EXT_OppContactRolesList(OppController);
        
        ApexPages.currentPage().getParameters().put('delid',ocr.id);
        crl.delConRole(); 
        
        List<OpportunityContactRole> deletedOCRs = [SELECT ContactId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId = :opp.id AND ContactId = :con.id];
        system.assertEquals(0,deletedOCRs.size());
    }
  
}