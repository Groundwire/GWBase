// Written by Steve Andersen, copyright (c) 2008 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Steve Andersen, David Habib
* @date 01/01/2008, 04/01/2011
* @description Visualforce page Controller class for the NewOppWizard.  The NewOppWizard is a custom
* Visualforce page that GWBase provides to override the standard Salesforce page for New Opportunity.
* The wizard provides a nicer ui that handles both contact and organization opportunities, such as
* gifts, grants, membership, etc.  Custom settings allow the customization of behavior for the NewOppWizard,
* such as only exposing the Opportunity record types that are appropriate for contacts, when a contact
* is selected.  See the help property for these settings in the Opportunity & Rollup Settings custom
* settings object.  The NewOppWizard also handles creating three specific types of opportunities: 1) Single
* Payments, 2) Pledges with a fixed number of installments, and 3) Recurring Payments, with an ongoing 
* payment schedule.  GWBase exposes this controller and some of its methods and properties globally, to
* allow clients to customize the behavior of the wizard.
*/
global with sharing virtual class ONEN_CTRL_NewOppWizard {
    
    /**
	* @description The Opportunity object being created by the wizard.
	*/
    global Opportunity opportunity = new Opportunity();
    
    /**
	* @description The RecurringPaymentProfile object being created by the wizard.  This will be null
	* for Single Payments and Pledges.
	*/
    global Recurring_Payment_Profile__c rpProfile { get; set; }
    
    /**
	* @description A temporary object to get the Contact lookup field. It is never saved to Salesforce; just used for it's picker
	*/
    global OpportunityContactRole contactRole { get; set; }
    
    /**
	* @description boolean to indicate whether or not the first Pledge Installment is received or not
	*/
    global Boolean paymentReceived { get; set; }
    
    /**
	* @description boolean to indicate whether or not to display the 3 radio buttons for Payment Type.
	*/
    global Boolean displayPaymentTypes { get; set; }

    /**
	* @description string to hold type of payment we are creating: Single, Pledge, or Recurring.
	*/
    global string strPaymentType { get; set; } 
    
    /**
	* @description integer to hold number of occurrences for pledges/installments.
	*/
    global integer cOccurrences { get; set; }
    
    /**
	* @description primary Contact for the opportunity.
	*/
    global Contact primaryContact = new Contact();
    /**
	* @description primary Account for the opportunity.
	*/
    global Account primaryOrg = new Account();
    /**
	* @description Id of the primary contact.
	*/    
    global id primaryContactId; 
    /**
	* @description Id of the primary account.
	*/
    global id primaryAccountId;
    
    /**
	* @description The currently selected record type. (Bound to the recordtype picklist).
	*/
    global Id oppRecordTypeId { get; set; }
    
    /**
	* @description The list of allowed record types for the contact or account.
	*/
    global List<RecordType> recordTypeList { get; set; }

    /**
	* @description A string to report any errors to the user on Save.
	*/    
    global String errorMessageText { get; set; }
    
    /**
	* @description A specific error message string.
	*/
    global String errorMessageIndividualOrgForOrgOpp = 'You cannot create Organizational gifts for the Individual Organization. Create a gift for the Contact or create an Organizational gift for a different Organization.';

    /**
	* @description A specific error message string.
	*/
    global String errorMessageNoOrgForOrgOpp = 'You must select an Organization for gifts that are applied to an Organization.';

    /**
	* @description A specific error message string.
	*/
    global String errorMessageNoContactForContactOpp = 'You must select a Contact for gifts that are applied to a Contact.';
 
    /**
	* @description A specific error message string.
	*/
    global String errorMessageNoCloseDate = 'Please specify a Close Date.';
 
    /**
	* @description A specific error message string.
	*/
    global String errorMessageNoAmount = 'Please specify a Payment Amount.';
 
    /**
	* @description A specific error message string.
	*/
    global String errorMessageNoStartDate = 'Please specify a Payment Start Date.';
  
    /**
	* @description A specific error message string.
	*/
    global String errorMessageNoOccurrences = 'Please specify the Number of Payments.';
    
    /**
	* @description list to hold open opps
	*/
    global List<Opportunity> openOppList {get{return openOppList;}set{openOppList=value;}}
    
    /**
	* @description SelectOptions for the record type picklist
	*/
    global List<SelectOption> recordTypeNameList {get{return recordTypeNameList;}set{recordTypeNameList = value;}}

    /**
	* @description Holds the Opportunity & Rollup Settings custom settings object, which provides access to
	* various settings the NewOppWizard uses. 
	*/    
    global OppRollupSettings__c oppSettings;
    
	/*******************************************************************************************************
	* @description Constructor for this controller class.
	* @param controller The standard controller object for an Opportunity.
	*/ 		
    global ONEN_CTRL_NewOppWizard (ApexPages.StandardController controller) {

        oppSettings = OppRollupSettings__c.getInstance();
        
        //get record from standard controller
        this.opportunity = (Opportunity)controller.getRecord();
    
        //instantiate dummy object for Contact lookup
        contactRole = new OpportunityContactRole();

        //create the empty list for opps
        openOppList = new List<Opportunity>();
        
        //initialize newOpp variable, using virtual method clients can override.
        NewOppMaintenance(); 
        
        //grab the id of the account and the contact
        newOpp.primaryAccountId = opportunity.AccountId;
        newOpp.primaryContactId = contactRole.ContactId;
        
        primaryContactId = contactRole.ContactId;
        primaryAccountId = opportunity.AccountId;
        
        //default recurring gift payment received to checked
        paymentReceived = TRUE;
    
        // create the object and property to hold recurring payment profile info
        rpProfile = new Recurring_Payment_Profile__c();
        rpProfile.Frequency__c = 1;
        rpProfile.Payment_Period__c = 'Month';
        rpProfile.Start_Date__c = opportunity.CloseDate != null ? opportunity.CloseDate : Date.today();
        
        setOppDefaults();

        setRecordTypes (); 
       	
       	// in case user went thru pick your record type screen,
       	// or they have a default record type set in their profile,
       	// let's set the initial record type to it.
       	oppRecordTypeId = this.Opportunity.RecordTypeId; 
       	ChangeOppType();
            
    }
    
    /*******************************************************************************************************
	* @description property that holds the current instance of the ONEN_OpportunityMaintenance helper class.
	*/
    global ONEN_OpportunityMaintenance newOpp { get; set; }
    
    /*******************************************************************************************************
	* @description overridable function to create the ONEN_OpportunityMaintenance helper class.
	* @return an instance of ONEN_OpportunityMaintenance
	*/ 		
    global virtual ONEN_OpportunityMaintenance NewOppMaintenance() {
        if (newOpp == null) {
            newOpp = new ONEN_OpportunityMaintenance(null);
        }
        return newOpp;
    }
    
    /*******************************************************************************************************
	* @description Called by the constructor to initialize the wizard, and handle any parameters passed to it.
	*/ 	   
    global virtual void setOppDefaults () {
        // called by constructor on load
        
        //get the vars from the querystring
        opportunity.AccountId = ApexPages.currentPage().getParameters().get('accid');
        opportunity.CampaignId = ApexPages.currentPage().getParameters().get('campid');
        contactRole.ContactId = ApexPages.currentPage().getParameters().get('conid');
    
        //make the CloseDate Today
        opportunity.CloseDate = system.Today();
        
        //if we have a contactId from the querystring, or don't have an accid, then assume it's a Contact Opp
        if(ApexPages.currentPage().getParameters().get('conid')!=null||ApexPages.currentPage().getParameters().get('accid')==null) {
            oppApplicant = 'Contact';            
        } else {
            oppApplicant = 'Organization';
        }
        
        // always default to single payment opp
        strPaymentType = 'single';
    }
    
    /*******************************************************************************************************
	* @description Tells the wizard to refill its list of record types for the given state of the wizard 
	* (Contact vs. Organization).
	*/ 	     
    global virtual void setRecordTypes () {
        //get the list of acceptable recordTypes
        resetRecordTypeArray();
        oppRecordTypeId =  GW_RecTypes.GetRecordTypeId('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);  
        errorMessageText = null;
    }
    
    
    /*******************************************************************************************************
	* @description string from radio selector 
	*/ 
	global String oppApplicant { 
        get {
            return oppApplicant;
        }
        set {
            errorMessageText=null;
            oppApplicant = value;
            // refill list of open opps, since they will change.
            getOpenOpps(); 
        }
    }

    /*******************************************************************************************************
	* @description Get open opps for this donor.  Clients can override this method if they want to customize
	* which open opportunities get displayed in the wizard.
	*/ 	     
    global virtual void getOpenOpps(){
        if (oppApplicant=='Contact') {
            //get the latest ContactId
            newOpp.primaryContactId = contactRole.ContactId;
            //get the openopps list for this contact
            openOppList = newOpp.getContactOpenOpps();
        } else {
            //get the latest accountid
            newOpp.primaryAccountId = opportunity.AccountId;
            //get the openopps list for this account
            openOppList = newOpp.getAccountOpenOpps();
        }   
    }
    
    /*******************************************************************************************************
	* @description get the list of acceptable record types for the given oppApplicant.  
	*/ 	    
    global virtual void resetRecordTypeArray() {
        //blank out the list for the select options
        recordTypeNameList = new List<SelectOption>();
        
        Map<String, Id> rtidMap = GW_RecTypes.GetRecordTypeIdMap('Opportunity'); 
        
        // find out which opp record types to exclude.
        set<string> opprtExcludeContact = new set<string>();
        set<string> opprtExcludeOrg = new set<string>();        

        if (oppSettings != null) {
            if (oppSettings.Opp_Rectypes_Excluded_New_Opp_Contact__c != null) {
                opprtExcludeContact = new set<string>(oppSettings.Opp_Rectypes_Excluded_New_Opp_Contact__c.split(';'));
            }
            if (oppSettings.Opp_Rectypes_Excluded_New_Opp_Org__c != null) {
                opprtExcludeOrg = new set<string>(oppSettings.Opp_Rectypes_Excluded_New_Opp_Org__c.split(';'));
            }
        }
        
        //loop through the record types for Opportunity
        for ( string thisRecordType : rtidMap.keySet()) {
            //if we're creating a Contact Opp, get all the right record types
            if(oppApplicant == 'Contact') {
                if (!opprtExcludeContact.contains(thisRecordType)) {
                    recordTypeNameList.add(new SelectOption(rtidMap.get(thisRecordType),thisRecordType));
                }
            //if we're creating an Organization Opp, get all the right record types
            } else {
                if (!opprtExcludeOrg.contains(thisRecordType)) {
                    recordTypeNameList.add(new SelectOption(rtidMap.get(thisRecordType),thisRecordType));
                }
            }
        }
    }

    
    /*******************************************************************************************************
	* @description Save the opportunity
	*/ 	
    global virtual PageReference save() {

        newOpp.primaryAccountId = opportunity.AccountId;
        newOpp.primaryContactId = contactRole.ContactId;
        opportunity.RecordTypeId = oppRecordTypeId;
    
        //if we've got a Contact id on our dummy object, get the contact, put the id on the Opp
        // so conrole will be created by trigger
        if (contactRole.ContactId!=null) {
            primaryContact = newOpp.getPrimaryContact();
            opportunity.CR_Contact_Id__c = contactRole.ContactId;
            // inherit the contact's anonymous setting
            opportunity.Anonymous__c = primaryContact != null ? primaryContact.Anonymous__c : false;            
        }

        //if the Account Id isn't null, get the Account and put the Id on the Opp
        // note: the value returned here isn't used anywhere in this controller (method should be void)
        // but this is necessary b/c the value in the OppMaintenance class is used later
        if (opportunity.AccountId!=null) {
            primaryOrg = newOpp.getPrimaryAccount();            
        }
        
        // with new PrimaryContact support, Opps always have AccountId or PrimaryContact set, but never both!
        if (oppApplicant=='Contact') {
            opportunity.ContactId__c = contactRole.ContactId;
            opportunity.AccountId = null;                   
        } else {
            opportunity.ContactId__c = null;
        }

        if (saveErrorCheck() == true) {
            return null;
        } else {
            //if we've selected a Contact, null out the org on the opp & set role & soft credit
            if (oppApplicant=='Contact') {
                opportunity.AccountId=null;
                opportunity.CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',oppRecordTypeId));
                opportunity.CR_HHroles__c = true;
            } else {
                // if org, set role etc accordingly
                opportunity.CR_Contact_Role__c = ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',oppRecordTypeId));
                opportunity.CR_HHroles__c = false;
            }

            // write opp name & stage 
            newOpp.newOpp = opportunity;
            // don't name the opp yet.  let it happen later, so that we use
            // correct naming rules depending on whether it is a single opp, recurring, pledged, etc.
            
            // now save the opportunity based on its payment type.
            if (strPaymentType == 'single') {               
                opportunity.StageName = ONEN_Constants.OPP_DEFAULT_STAGE;
                CustomOppProcessing();
                try {
                    insert opportunity;
                } catch (exception ex) {
                    errorMessageText = ex.getMessage();
                    return null;
                }
            } else if (strPaymentType == 'pledge') {                
                
                // create a list of payments
                list<OppPayment__c> listPayment = ONEN_OpportunityInstallments.createInstallmentList(
                    opportunity, rpProfile.Start_Date__c, rpProfile.Amount__c, integer.valueOf(rpProfile.Frequency__c),
                    rpProfile.Payment_Period__c, cOccurrences);
                    
                // give client code chance to modify the opp and then create it
                opportunity.StageName = ONEN_Constants.OPP_DEFAULT_PLEDGED_STAGE;
                CustomOppProcessing();
                try {
                    insert opportunity;
                } catch (exception ex) {
                    errorMessageText = ex.getMessage();
                    return null;
                }
                
                // fixup the payments and save them
                boolean isFirstPaid = paymentReceived;
                for (OppPayment__c pmt : listPayment) {
                    pmt.Opportunity__c = opportunity.id;
                    pmt.Opp_For_Installment__c = opportunity.id;
                    pmt.Paid__c = isFirstPaid;
                    isFirstPaid = false;                    
                }
                insert listPayment;
                
                // remove the obsolete mirror payment(s)
                listPayment = [Select Id from OppPayment__c where IsInstallment__c=false and Opportunity__c=:opportunity.id];
                if (!listPayment.isEmpty())
                    delete listPayment;             
                 
            } else if (strPaymentType == 'recurring') {
                rpProfile.Contact__c = newOpp.primaryContactId;
                rpProfile.Account__c = opportunity.AccountId;
                rpProfile.Type__c = opportunity.Type;               
                //rpProfile.Amount__c = set by page
                //rpProfile.Frequency__c = set by page
                //rpProfiles.End_Date__c = null for recurring
                //rpProfile.Payment_Period__c = set by page
                //rpProfile.Start_Date__c = set by page
                
                rpProfile.Name = GW_RecurringPayments.strNameForRPP(rpProfile);
                try {
                    insert rpProfile;
                } catch (exception ex) {
                    errorMessageText = ex.getMessage();
                    return null;
                }

                // now we have the profile to store in the opp.
                opportunity.Recurring_Payment_Profile__c = rpProfile.Id;
                
                // for now, create a single opp.
                // in the future, we might consider adding a custom setting to create
                // pledged opps thru the end of the fiscal/calendar year.
                opportunity.StageName = paymentReceived ? ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE : 
                    ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE;
                opportunity.Amount = rpProfile.Amount__c;
                opportunity.CloseDate = rpProfile.Start_Date__c;                
                                
                // give client code chance to modify the opp and then create it
                CustomOppProcessing();
                try {
                    insert opportunity;
                } catch (exception ex) {
                    errorMessageText = ex.getMessage();
                    return null;
                }
            } 
            
            
            //redirect to newly created opp in edit mode
            PageReference newOppDetail = new PageReference('/' + opportunity.id +'/e?retURL=/' + opportunity.id);
            newOppDetail.setRedirect(true);
            return newOppDetail;
        }
    }


    /*******************************************************************************************************
	* @description Routine to check for all required fields and dependent constraints.  Some of our fields we
	* can't mark required in the visualforce page, because they are only required if another control is set, 
	* and visualforce doesn't support dynamic changing of required.
    * @return true if there is an error, false if there is no error.
	*/ 		
    global virtual boolean saveErrorCheck () {
        //if this is an org gift for the individual account, flag that as a problem
        if (oppApplicant=='Organization'&&newOpp.isIndividualAccount) {
            errorMessageText = errorMessageIndividualOrgForOrgOpp;
            return true;    
        }       
        if (oppApplicant=='Organization'&&opportunity.AccountId==null) {
            errorMessageText = errorMessageNoOrgForOrgOpp;
            return true;
        }       
        if (oppApplicant=='Contact'&&opportunity.CR_Contact_Id__c==null) {
            errorMessageText = errorMessageNoContactForContactOpp;
            return true;
        } 
        if (opportunity.CloseDate==null) {
            errorMessageText = errorMessageNoCloseDate;
            return true;                
        }               
        if (strPaymentType != 'single') {
            if (rpProfile.Amount__c == null) {
                errorMessageText = errorMessageNoAmount;
                return true;
            }
            if (rpProfile.Start_Date__c == null) {
                errorMessageText = errorMessageNoStartDate;
                return true;                
            }
        }       
        if (strPaymentType == 'pledge' && cOccurrences == null) { 
            errorMessageText = errorMessageNoOccurrences; 
            return true;
        } 
        
    return false;       
    }
    
    /*******************************************************************************************************
	* @description Called when the user changes the Payment Type.  Clears errors.
	*/
    global void ChangePaymentType() {
        errorMessageText = null;
    }

    /*******************************************************************************************************
	* @description Called when the user changes the Opportunity Record Type.  Shows/hides payment panel.
	*/
    global virtual void ChangeOppType() {

		displayPaymentTypes = true;
		
        if (oppSettings != null) {
	        set<string> opprtExcludePaymentTypes = new set<string>();
	        string strOppNameCurrent;
	                
            if (oppSettings.Opp_Rectypes_Excluded_New_Opp_Payments__c != null) {
                opprtExcludePaymentTypes = new set<string>(oppSettings.Opp_Rectypes_Excluded_New_Opp_Payments__c.split(';'));
            
            	if (opprtExcludePaymentTypes.contains(GW_RecTypes.getRecordTypeName('Opportunity',oppRecordTypeId))) {
            		displayPaymentTypes = false;
            	}                
            }            
        }        
    }
    
    /*******************************************************************************************************
	* @description Virtual method called during the save operation.  The client can override this method
	* to provide there own custom code.  This is called just before the Opportunity is inserted.
	*/
    global virtual void CustomOppProcessing () {
        // override w/ custom code
        // this is run just before opp insert
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// TEST CODE
/////////////////////////////////////////////////////////////////////////////////////////////////////////

    static testmethod void testContactOpp () {      
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)      
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        //create an Contact
        Contact secondContact = new Contact (
            FirstName='Albert',
            LastName = 'Moyo'       
        );
        insert secondContact;
        
        //create an opp for this contact
        //create an opportunity
        Opportunity secondContactOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name = 'Test second contact opp',
            amount=100,
            StageName='Prospecting',
            CloseDate = system.Today(),
            CR_Contact_Id__c = secondContact.id,
            CR_Contact_Role__c = 'Individual Donor'
        );
        
        insert secondContactOpp;
        
        //create an Account
        Account firstAccount = new Account (
            Name='XYZ Org'      
        );
        insert firstAccount;
        
        //create an opportunity
        Opportunity firstAccountOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name = 'Test first account opp',
            amount=100,
            AccountId=firstAccount.Id,
            StageName='Prospecting',
            CloseDate = system.Today()
        );
        
        insert firstAccountOpp;
        
        //create an opportunity
        Opportunity firstAccountOpp1 = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name = 'Test first account opp',
            amount=100,
            AccountId=firstAccount.Id,
            StageName='Prospecting',
            CloseDate = system.Today()
        );
        
        insert firstAccountOpp1;
        
        //create two opps for this account
        
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        //put the contact and account id on the page
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        ApexPages.currentPage().getParameters().put('accid', firstAccount.id);
        
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        //pass the controller into the extension
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
        //since we have a contact id, we should be in contact mode      
        system.AssertEquals('Contact',ext.OppApplicant);
        //should show no gifts for this contact
        system.AssertEquals(0,ext.openOppList.size());
        //change to second contact
        ext.contactRole.ContactId = secondContact.Id;
        //get the open opps
        ext.getOpenOpps();
        //should be one gift for this contact
        system.AssertEquals(1,ext.openOppList.size());
        //switch to Organization gifts
        ext.OppApplicant='Account';
        //change to Account
        ext.opportunity.AccountId = firstAccount.Id;
        //get opps
        ext.getOpenOpps();
        //should be two gifts for this account
        system.AssertEquals(2,ext.openOppList.size());
        //change to second contact
        ext.contactRole.ContactId = secondContact.Id;
        //get the open opps
        ext.getOpenOpps();
        //should be two gifts for this account because we didn't change applicant
        system.AssertEquals(2,ext.openOppList.size());
        //switch to Contact gifts
        ext.OppApplicant='Contact';
        //get the open opps
        ext.getOpenOpps();
        //should be one gift for this contact
        system.AssertEquals(1,ext.openOppList.size());
        
        
        
        /*left to test
            1. org gift - DONE
            2. record type exclusion lists
            3. contact and account selection boxes = DONE
            4. campaign id - DONE
            5. opplist as the primary contact and account changes - DONE    
        */
        
    }
    
    static testmethod void testOrgOpp () {  
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        //create an Campaign
        Campaign firstCampaign = new Campaign (
            Name = 'Test Campaign'      
        );
        insert firstCampaign;
        
        //create an Account
        Account firstAccount = new Account (
            Name='XYZ Org'      
        );
        insert firstAccount;
        
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        //put the contact and account id on the page
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        ApexPages.currentPage().getParameters().put('accid', firstAccount.id);
        ApexPages.currentPage().getParameters().put('campid', firstCampaign.id);
        
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        //pass the controller into the extension
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
        //since we have a contact id, we should be in contact mode  
        ext.OppApplicant = 'Organization';  
        system.AssertEquals('Organization',ext.OppApplicant);
        id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
        ext.oppRecordTypeId = rtid;
        //next step
        //ext.step2();
        //eet a valid close date
        //ext.opportunity.CloseDate = system.Today();
        //dave
        String savePage = ext.save().getUrl();
        //get the id from the pageref
        Id newOppId = savePage.substring(1,19);
        //lookup the newly created opp
        Opportunity newOpp = [select id, RecordTypeId, RecordType.Name, CampaignId,AccountId, Name, CloseDate,CR_Contact_Id__c from Opportunity where Id = :newOppId limit 1]; 
        //make sure the rt got set correctly
        system.assertEquals(rtid,newOpp.RecordTypeId);
        //did it get to the campaign
        system.assertEquals(firstCampaign.id,newOpp.CampaignId);
        //find the contact role
        OpportunityContactRole[] newCR = [select Role, IsPrimary from OpportunityContactRole where OpportunityId = :newOppId and ContactId = :firstContact.id];
        //should be 1
        system.assertEquals(1,newCR.size());
        //org donor role
        system.assertEquals(ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',newOpp.RecordTypeId)),newCR[0].Role);
        
        
    }
    static testmethod void testOpenOppListAsDonorChanges () {   
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        //create an Campaign
        Campaign firstCampaign = new Campaign (
            Name = 'Test Campaign'      
        );
        insert firstCampaign;
        
        //create an Account
        Account firstAccount = new Account (
            Name='XYZ Org'      
        );
        insert firstAccount;
        
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        //put the contact and account id on the page
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        ApexPages.currentPage().getParameters().put('accid', firstAccount.id);
        ApexPages.currentPage().getParameters().put('campid', firstCampaign.id);
        
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        //pass the controller into the extension
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
        //since we have a contact id, we should be in contact mode  
        ext.OppApplicant = 'Organization';  
        system.AssertEquals('Organization',ext.OppApplicant);
        id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
        ext.oppRecordTypeId = rtid;
        //next step
        //ext.step2();
        //eet a valid close date
        //ext.opportunity.CloseDate = system.Today();
        //dave
        String savePage = ext.save().getUrl();
        //get the id from the pageref
        Id newOppId = savePage.substring(1,19);
        //lookup the newly created opp
        Opportunity newOpp = [select id, RecordTypeId, RecordType.Name, CampaignId,AccountId, Name, CloseDate,CR_Contact_Id__c from Opportunity where Id = :newOppId limit 1]; 
        //make sure the rt got set correctly
        system.assertEquals(rtid,newOpp.RecordTypeId);
        //did it get to the campaign
        system.assertEquals(firstCampaign.id,newOpp.CampaignId);
        //find the contact role
        OpportunityContactRole[] newCR = [select Role, IsPrimary from OpportunityContactRole where OpportunityId = :newOppId and ContactId = :firstContact.id];
        //should be 1
        system.assertEquals(1,newCR.size());
        //org donor role
        system.assertEquals(ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity', newOpp.RecordTypeId)),newCR[0].Role);
        
        
    }
    
    static testmethod void testMonthlyOppPaymentReceived() {    
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        //put the contact and account id on the page
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        //pass the controller into the extension
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
        //since we have a contact id, we should be in contact mode  
        ext.OppApplicant = 'Contact';   
        
        ext.oppRecordTypeId = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
        ext.strPaymentType = 'pledge';
        //start date for first payment
        ext.rpProfile.Start_Date__c = Date.newInstance( 2005,1,1);
        ext.rpProfile.Amount__c = 10;
        ext.paymentReceived = true;
        ext.rpProfile.Payment_Period__c = 'Month';
        ext.rpProfile.Frequency__c = 1;
        ext.cOccurrences = 12;
        
        String savePage = ext.save().getUrl();
        //get the id from the pageref
        Id newOppId = savePage.substring(1,19);
        //lookup the newly created opp
        Opportunity newOpp = [select id, Amount, Total_Paid__c, Total_Unpaid__c from Opportunity where Id = :newOppId limit 1]; 
        //make sure the rt got set correctly
        system.assertEquals(120,newOpp.Amount);
        system.assertEquals(10,newOpp.Total_Paid__c);
        system.assertEquals(110,newOpp.Total_Unpaid__c);        
        
    }
    

    static testmethod void testMonthlyOppAltFY() {  
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 

        //since we have a contact id, we should be in contact mode  
        ext.OppApplicant = 'Contact';   
        ext.oppRecordTypeId = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
        ext.strPaymentType = 'pledge';
        //start date for first payment
        ext.rpProfile.Start_Date__c = Date.newInstance( 2005,7,1);
        ext.rpProfile.Amount__c = 10;
        ext.paymentReceived = true;
        ext.rpProfile.Payment_Period__c = 'Month';
        ext.rpProfile.Frequency__c = 1;
        ext.cOccurrences = 10;
        
        String savePage = ext.save().getUrl();
        //get the id from the pageref
        Id newOppId = savePage.substring(1,19);
        //lookup the newly created opp
        Opportunity newOpp = [select id, Amount, Total_Paid__c, Total_Unpaid__c from Opportunity where Id = :newOppId limit 1]; 
        //make sure the rt got set correctly - should be 10 mos. of payments, even though it goes over a calendar year.
        system.assertEquals(100,newOpp.Amount);
        system.assertEquals(10,newOpp.Total_Paid__c);
        system.assertEquals(90,newOpp.Total_Unpaid__c); 
        
        OppPayment__c[] installs = [SELECT Id,Opportunity__c,Amount__c FROM OppPayment__c WHERE Opportunity__c = :newOpp.Id];
        system.assertEquals (10 , installs.size() );    
        
    }   
    
    /*************************************************
    *                                                *
    *   TESTS                                        *
    *                                                *
    **************************************************/
    
    static testmethod void TestInstallments () {
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.installmentWizard'));
        
        //create an opportunity
        Opportunity firstOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
            Name='Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.Today(),
            Amount=100          
        );
        
        insert firstOpp;
        //trigger will have created one mirror payment
        
        //get the created opp Id
        ApexPages.currentPage().getParameters().put('id', firstOpp.id);
        //instantiate the controller for this opp
        ONEN_CTRL_InstallmentWizard controller = new ONEN_CTRL_InstallmentWizard();
                
                
        system.AssertNotEquals(0,controller.getItems().size());
        system.AssertNotEquals(0,controller.getIntervals().size());
        system.AssertNotEquals(0,controller.getIntervalUnits().size());
        //set the interval unit 
        String unit = 'Year';   
        controller.Intervalunit = unit;
        system.AssertEquals(unit,controller.Intervalunit);
        
        //set the number of installments
        Integer paymentCount = 3;
        controller.numberofinstallments = paymentCount;
        system.AssertEquals(paymentCount,controller.numberofinstallments);
        
        //set the interval
        Integer intervalCount = 2;
        controller.interval = intervalCount;
        system.AssertEquals(intervalCount,controller.interval);
        
        //a list for the new payments
        List<OppPayment__c> newPayments = new List<OppPayment__c>();
        //create the new payment objects
        newPayments = controller.getPayments();
        
        //there should be the payment count
        system.AssertEquals(paymentCount,newPayments.size());
        
        //create the installments
        controller.createInstallments();
        
        //query the newly created installments
        OppPayment__c[] createdPayments = [select Id,IsInstallment__c,Date__c from OppPayment__c where Opportunity__c =:firstOpp.id ORDER BY Date__c];
            system.debug ('installments created: ' + createdPayments);
        //should match the payment count
        system.AssertEquals(paymentCount,createdPayments.size());
        //date should be the same
        system.AssertEquals(system.Today(),createdPayments[0].Date__c);
        //next payment date should be out the interval
        system.AssertEquals(system.Today().addYears(intervalCount),createdPayments[1].Date__c);     
        
        // now chg the Opp's amount & stage, the installments shouldn't chg
        firstOpp.Amount = 1500;
        firstOpp.StageName = 'Closed Won';
        update firstOpp;
        
        OppPayment__c[] Installments = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id ORDER BY Date__c];
        System.AssertEquals ( paymentCount , Installments.size() );
        
        OppPayment__c OP1 = Installments[0];
        System.AssertEquals ( 33, OP1.Amount__c);
        System.AssertEquals ( firstOpp.CloseDate, OP1.Date__c);
        System.AssertEquals ( true , OP1.IsInstallment__c);
        System.AssertEquals ( false , OP1.Paid__c);
        
        // now delete all the installments
        // we should end up w/ one mirror pmt
        
        delete Installments;
         
        Installments = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id];
        System.AssertEquals ( 1 , Installments.size() );
        
        OP1 = Installments[0];
        System.AssertEquals ( 1500, OP1.Amount__c);
        System.AssertEquals ( firstOpp.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( true , OP1.Paid__c);
        
    }
    
    static testmethod void testRecurring() {    
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        //put the contact and account id on the page
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        //pass the controller into the extension
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
        //since we have a contact id, we should be in contact mode  
        ext.OppApplicant = 'Contact';   
        
        ext.oppRecordTypeId = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
        ext.strPaymentType = 'recurring';
        //start date for first opp
        ext.rpProfile.Start_Date__c = Date.newInstance(2011,1,1);
        ext.rpProfile.Amount__c = 10;
        ext.paymentReceived = true;
        ext.rpProfile.Payment_Period__c = 'Month';
        ext.rpProfile.Frequency__c = 1;
        ext.paymentReceived = true;
        
        String savePage = ext.save().getUrl();
        //get the id from the pageref
        Id newOppId = savePage.substring(1,19);
        //lookup the newly created opp
        Opportunity newOpp = [select id, Amount, Total_Paid__c, Total_Unpaid__c, Recurring_Payment_Profile__c from Opportunity where Id = :newOppId limit 1]; 
        //make sure the rt got set correctly
        system.assertEquals(10,newOpp.Amount);
        system.assertEquals(10,newOpp.Total_Paid__c);
        system.assertEquals(0,newOpp.Total_Unpaid__c);
        
        // now make sure a RecurringPaymentProfile was created!
        system.assert(newOpp.Recurring_Payment_Profile__c != null);
        Recurring_Payment_Profile__c rpp = [select Id, Start_Date__c, Amount__c, Payment_Period__c, Frequency__c, End_Date__c, isActive__c
            from Recurring_Payment_Profile__c where Id = :newOpp.Recurring_Payment_Profile__c limit 1];
        system.assertEquals(ext.rpProfile.Start_Date__c, rpp.Start_Date__c);
        system.assertEquals(ext.rpProfile.Amount__c, rpp.Amount__c);
        system.assertEquals(ext.rpProfile.Payment_Period__c, rpp.Payment_Period__c);
        system.assertEquals(ext.rpProfile.Frequency__c, rpp.Frequency__c);
        system.assertEquals(null, rpp.End_Date__c);
        system.assertEquals('Yes', rpp.isActive__c);                    
    }

    static testmethod void testErrorValidation() {  
        
        //create an opportunity
        Opportunity theOpp = new Opportunity (
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
        );
        
        //create an Contact
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName = 'Smith'      
        );
        insert firstContact;
        
        //point to our VF page
        Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
        //put the contact and account id on the page
        ApexPages.currentPage().getParameters().put('conid', firstContact.id);
        
        //pass contact into the controller
        ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
        //pass the controller into the extension
        ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
        //since we have a contact id, we should be in contact mode  
        ext.OppApplicant = 'Contact';
        
        ext.opportunity.CloseDate = null;       
        system.assertEquals(null, ext.save());
        system.assert(ext.errorMessageText != null);
        
        ext.opportunity.CloseDate = Date.newInstance(2011,1,1);
        ext.strPaymentType = 'pledge';
        ext.rpProfile.Amount__c = null;
        system.assertEquals(null, ext.save());
        system.assert(ext.errorMessageText != null);
            
        ext.rpProfile.Amount__c = 10;
        ext.rpProfile.Start_Date__c = null;
        system.assertEquals(null, ext.save());
        system.assert(ext.errorMessageText != null);
            
        ext.rpProfile.Start_Date__c = Date.newInstance(2011,1,1);
        ext.cOccurrences = null;
        system.assertEquals(null, ext.save());
        system.assert(ext.errorMessageText != null);
    }   
    
}