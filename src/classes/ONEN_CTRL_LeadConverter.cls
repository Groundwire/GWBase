global virtual class ONEN_CTRL_LeadConverter {

// Page controller for ONEN_CTRL_LeadConverter page 
// Written by Evan Callahan (evan@groundwire.org) and Dave Manelski (davem@groundwire.org)
// Copyright (c) 2008, NPower Seattle, 403 23rd Ave S, Seattle, WA 98144
// Portions copyright (c) 2010 Groundwire, 1402 3rd Ave., Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

// To load a single lead, pass the lead ID in a URL parameter called 'id'

// TODO: might want to update opp stage to closed for matched opp? make that an option?
// TODO: display convert errors in converts list? display status? 
// TODO: more tests with varied lead values, error handling for fringe cases
// TODO: display link to open existing contact or opp match in a new window 

	// set to the maximum number of leads you want to load
	public final integer MAX_LEADS_PER_PAGE = 20; 
	public static id IndividualAccountId;
	public static string IndividualAccountName;
	public static string NotProvidedLabel;
	
	//properties that control the rendering of the batch auto-converter
	public boolean batching { get; set; }
	public boolean batchRunning { get; set; }

	// private object lists for lead conversion object and results
	protected ONEN_LeadConversion lc = new ONEN_LeadConversion(MAX_LEADS_PER_PAGE);
    protected leadResult[] results;
    protected ConvertedLead[] convertedLeads;
     
  	//constructor
	global ONEN_CTRL_LeadConverter() {
		//individual account id
		IndividualAccountId = ONEN_DefaultAccount.getIndividualAccountId();
		//individual account name
		IndividualAccountName = ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;
		//set the org name not provided default label
		NotProvidedLabel = ONEN_Constants.NOT_PROVIDED_LABEL;
		//set the duplicate contact flag to false
		dupContact = false;
		//make sure the batch status compenent is not visible on page load
		batchRunning = false;
	}
  
    public string leadSource { get; set; }
    public boolean havePayments { get; private set; }

	// flag that tells page there are no leads
	public virtual boolean getNoOpenLeads() {
		integer i = [select count() from lead where isConverted = false limit 1];
		return (i==0);
	}
	
	// flag duplicate contacts in conversion set, to throw an error to VF page
	public Boolean dupContact { get {return dupContact;} set {dupContact = value;} } 
	
	// getter for lead sources -- only shows sources for which there are open leads
    public List<SelectOption> getSources() {
        List<SelectOption> options = new List<SelectOption>();
   		options.add(new SelectOption('','- Select Lead Source -'));
   		options.add(new SelectOption('All','All Open Leads'));
    	set<string> sourceSet = new set<string>{};
    	for (lead ld : [select leadSource from lead where leadSource != null and isConverted = false order by createddate desc, leadsource limit 100]) {
    		if (!sourceSet.contains(ld.leadSource)) { 			
    			sourceSet.add(ld.leadSource);	 
		        //deal with the case where there is no lead source 
		        if(ld.leadSource!=null) {
		           	options.add(new SelectOption(ld.leadSource, 'Lead Source: ' + ld.leadSource));
		        } else {
		        	options.add(new SelectOption(' ', 'Lead Source: None Selected'));
		       	}
    		}
    	}
        return options;
    }
    
	//grab the Opp RecordTypes and throw them into a SelectOptions list
	private static Schema.DescribeSObjectResult OppRT = Opportunity.sObjectType.getDescribe();
	private static List<Schema.RecordTypeInfo> RT = OppRT.getRecordTypeInfos();
	
    // this class represents one row in the leads list
    global virtual class leadResult {
    	
		ONEN_LeadConversion.LeadMatchup lm;
    	lead theLead;		
    	
        // lead getter
        global lead getLead() { return theLead; }
        
	    // options for contacts dropdown list
	    global List<SelectOption> cOptions { get; private set; }
	    
	    // map of the account dropdown list options for each contact option
	    map<string, List<SelectOption>> aOptionsMap;

	    // options for opportunity dropdown list
	    List<SelectOption> oOptions;
	    List<SelectOption> RToptions;
	    
		// properties that determine whether to enable the lists
    	global boolean noChoice { get {return (cOptions.size() < 2);} }	
    	global boolean noAChoice { get {return (aOptionsMap.get(match).size() < 2);} }	
    	global boolean noOChoice { get {return (oOptions.size() < 2);} }	
        global boolean oneAOption { get { return (aOptions.size()<2); } }

		// link to display for the lead record
    	global string leadUrl { get {return '/' + theLead.id;} }  

		// properties that return the selections the user has made
        global boolean selected { get; set; }

        // contact picklist selection
        global string match { get; set; }

		// one item picklist containing account for selected contact
		global List<SelectOption> cAccount { get; set; }

        // account picklist selection for unmatched contact
		global List<SelectOption> aOptions { get; private set; }
        global string amatch { get; set; }

		// opp picklist
	    global string omatch { get; set; }
    	//global boolean createOpp { get; set; }
	    global string oRecType { get {oRecType = theLead.Opportunity_Record_Type__c; return oRecType;} set {oRecType = value; theLead.Opportunity_Record_Type__c = value;} }

		// properties that indicate which account list to show
		global string alistStyle { get { return (match=='') ? 'show' : 'hide'; } } 
		global string dummyStyle { get { return (match=='') ? 'hide' : 'show'; } } 
				
		// constructor
	    global leadResult(ONEN_LeadConversion.LeadMatchup matchup) { 
    		lm = matchup;
    		lead ld = theLead = lm.theLead;
	    	selected = false;

			// build the contact, account, and opportunity option lists
	        cOptions = new List<SelectOption>();
	        aOptions = new List<SelectOption>();
	        aOptionsMap = new Map<string, List<SelectOption>>();
	        oOptions = new List<SelectOption>();
			cAccount=new list<SelectOption>();         
	        RTOptions = new List<SelectOption>();
	    
			if (lm.cons==null) {
				cOptions.add(new SelectOption('', 'Create new: ' + ld.Name));

			} else {				
				//add any matched by Id to the list
				for (contact c : lm.cons) {
					cOptions.add(new SelectOption(c.id, 'Merge with: ' + c.Name + ((lm.conMatchMap.get(c.id) == 'id') ? ' (ID match)' : ((lm.conMatchMap.get(c.id) == 'email') ? ' (email match)' : ''))));

                    // create a one-item Account Options list for this contact                    
                    SelectOption[] acctOpts = new SelectOption[] {
                    	new SelectOption((c.accountid!=null) ? c.accountid : ONEN_DefaultAccount.getIndividualAccountId(), 'Place in: ' + ((c.accountid!=null) ? c.account.name : ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME))
                    };
                    aOptionsMap.put(c.id, acctOpts);
                    
                    // if this is the first contact, save this list to the cAccount property
                    if (cAccount.isEmpty()) cAccount = acctOpts;

				}

				// if we only matched by last name, put 'Create New' first
				if (lm.conMatchMap.get(lm.cons[0].id) == 'last') {
					cOptions.add(0, new SelectOption('', 'Create new: ' + ld.Name));
				} else {
					cOptions.add(new SelectOption('', 'Create new: ' + ld.Name));
				}
			}

			// set the contact match field to the first selection
			match = cOptions[0].getvalue();
	    	
	    	RToptions.add(new SelectOption('','--Select Record Type--'));
	        for ( Schema.RecordTypeInfo thisRT : RT ) {
		        RToptions.add(new SelectOption(thisRT.getName(),thisRT.getName()));
	        }
	        
	        
			/* These values are gotten in the constructor, but if they are, they aren't available for the initializtion of this class. So
			** we get them again here. This seems to make the code work and the tests pass without relying on a real production individual
			** account.
			*/
			
			//get individual account id
			IndividualAccountId = ONEN_DefaultAccount.getIndividualAccountId();
			//individual account name
			IndividualAccountName = ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;
			//set the org name not provided default label
			NotProvidedLabel = ONEN_Constants.NOT_PROVIDED_LABEL;
			
	        // always add an account option list for creating a new contact from the lead
	        aOptions = new List<SelectOption>();     
			if (ld.company==null || ld.company=='' || ld.company==NotProvidedLabel || ld.company==IndividualAccountName) {
				// use individual account
				aOptions.add(new SelectOption(IndividualAccountId, 'Place in: ' + IndividualAccountName));
			} else {
				// now provide the list of accounts
				if (lm.accts != null) {
					for (account a : lm.accts) { 
						aOptions.add(new SelectOption(a.Id, 'Place in: ' + dq(a.Name)));
					}
				}
			
				// option to create new account
				aOptions.add(new SelectOption('', 'New account: ' + dq(ld.company)));
				
				// option for individual account
				aOptions.add(new SelectOption(IndividualAccountId, 'Place in: ' + IndividualAccountName)); 
			}
	        aOptionsMap.put('', aOptions);  
	        
			// set the account field to the first selection
			amatch = aOptionsMap.get(match)[0].getvalue();					
				
	    	// if there is a donation, build the opp list	    		
			if (ld.opportunity_amount__c != null && ld.opportunity_amount__c > 0) {

	    		// first look for an id match, which is indicated in the description field
				if (lm.opps != null && lm.opps[0].description=='id') {
					oOptions.add(new SelectOption(lm.opps[0].id, 'ID Matches: ' + lm.opps[0].name));
				} else {
			    	// now look for opp matches on contact and date 
			    	if (lm.opps !=null) {
						for (opportunity o : lm.opps) {
							oOptions.add(new SelectOption(o.Id, 'Matches: ' + o.name));
						}
					}
					oOptions.add(new SelectOption('create_new', 'Create new opportunity') ); 
					oOptions.add(new SelectOption('none', 'Do not create opportunity') );
				}

				// set the opp match field to the first selection
				omatch = oOptions[0].getvalue();
	    	}
	    	system.debug('options and matches');
	    	system.debug(coptions);
	    	system.debug(aoptionsmap);
	    	system.debug(ooptions);
	    	system.debug(match);
	    	system.debug(amatch);
			system.debug(omatch);
	    }
	    
	    global virtual List<SelectOption> getMatches() {			
			return cOptions;
	    }    

	    global virtual List<SelectOption> getOMatches() {			
			return oOptions;
	    }    

		global virtual List<SelectOption> getORecTypes() {
	    	return RToptions;
	    }
	    
		// fill the accounts list for this lead
	    global virtual List<SelectOption> getAMatches() {
	        List<SelectOption> aOptions = aOptionsMap.get(match);
			
			return aOptions;
		}
		
		global virtual string[] getArrayData() {
			// build an array of account matches for this lead
			// this will get passed into Javascript so the account dropdown can update dynamically
			string[] alist = new string[0];
			for (string cid : aOptionsMap.keyset()) {
				for (SelectOption opt : aOptionsMap.get(cid)) {
					alist.add(cid);
					alist.add(opt.getValue());
					alist.add(opt.getLabel()); // the split avoids a crash when there a double quote in the name					
				}
			}
			return alist;
		}
    }
    
    global virtual List<LeadResult> getResults() {
    	if (leadSource=='All') {	    		
			lc.loadAllLeads();
			
    	} else if (leadSource != null && leadSource != '') {
			lc.loadLeadsBySource(leadsource);
			
    	} else if (ApexPages.currentPage().getParameters().containsKey('id')) {
			lc.loadOneLead(ApexPages.currentPage().getParameters().get('id'));
			
    	}
    	
    	if (lc.leads==null || lc.leads.isEmpty()) {
    		results = null;
    	} else {
			// create the lead result records				
	    	results = new leadResult[0];
	    	for (lead ld : lc.leads) {	    		
	    		results.add(new leadResult(lc.matchMap.get(ld.id)));
	    	}
    	}
    	return results;
    }
    
    // this gets called by the Convert button
    global virtual pageReference convertLeads() {
		
		//Create a map for duplicate contact matches
		Map<String,Boolean> cmatches = new Map<String,Boolean>();
		
		// set up the list of leads to convert
		ONEN_LeadConversion.convertSpec[] cs = new ONEN_LeadConversion.convertSpec[0];

    	if (results != null) {
    		for (leadResult lr : results) {
    			if (lr.selected) {
					
					//create a map to test whether or not duplicate contacts are being
					//added to the map, since we can't perform the ContactFix updates
					//to a list of contacts that contains dupes. If a duplicate ID is found
					//stop the conversion, return null, and set a flag which renders as 
					//an error message on the VF page.
					if ( cmatches.get(lr.match) == null ) {
						if ( lr.match != null && lr.match != '' ) {
							cmatches.put(lr.match,true);
						}
					} else {
						dupContact = true;
						return null;
					}
					
					ONEN_LeadConversion.ConvertSpec cs1 = new ONEN_LeadConversion.ConvertSpec();
					cs1.leadId = lr.getLead().id;
					cs1.contactId = lr.match;
                    // for a new contact, use the specified account; otherwise use the contact's account
					cs1.accountId = 
						(lr.match==null || lr.match=='') ?
						lr.amatch : lr.aOptionsMap.get(lr.match)[0].getValue() ;
					cs1.oppId = lr.omatch;
					cs.add(cs1);
    			}
    		}
    		try {
    			// convert them
    			ONEN_LeadConversion.Conversion[] converts = lc.convertLeads(cs);
    		
    			// create the list to display the conversions
    			convertedLeads = new ConvertedLead[0];
    			for (ONEN_LeadConversion.Conversion conv : converts) {
    				ConvertedLead cl = new ConvertedLead();
    				cl.contactId = conv.contactId;
    				cl.contactName = conv.contactName;
    				cl.accountId = conv.accountId;
    				cl.accountName = conv.accountName;
    				cl.oppId = conv.oppId;
    				cl.oppName = conv.oppName;
    				convertedLeads.add(cl);
    		    }			 
			} catch (System.DmlException e) {
				for (Integer i = 0; i < e.getNumDml(); i++) {
					// Process exception here
					System.debug(e.getDmlMessage(i));
				}
			}
    		
    		//if (!convertedLeads.isEmpty()) statusText = 'Converted ' + string.valueOf(convertedLeads.size()) + ' lead' + ((convertedLeads.size()>1) ? 's.' : '.');
    	}
    	return null;	
    }
    
    public void batchConvert() {
   		//instantite the batch conversion class and call the convert methods that initiate batch
    	GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion();
    	if (leadSource != null && leadSource != '' && leadSource != 'All') {
			system.debug('MY LEADSOURCE: ' + leadSource);
			batch.convertAllLeadsByLeadSource(leadSource);
    	} else {
    		batch.convertAllLeads();
    	}
    	batchRunning = true;
    }
    
    public void cancel() {
        batching = false;
    }
    
    public pageReference openBatchDialog() {
        batching = true;
        return null;
    }

	// class to display converted leads
    global virtual class ConvertedLead {
    	global boolean success { get { return (contactId!=null); } }
    	global string contactId { get {return contactId;} set {contactId = value;} }	
    	global string contactName { get {return contactName;} set {contactName = value;} }
    	global string contactUrl { get {return (contactId==null) ? null : '/' + contactId;} }	
    	global string accountId { get {return accountId;} set {accountId = value;} }	
    	global string accountName { get {return accountName;} set {accountName = value;} }	
    	global string accountUrl { get {return (accountId==null) ? null : '/' + accountId;} }    		
    	global string oppId { get {return oppId;} set {oppId = value;} }	
    	global string oppName { get {return oppName;} set {oppName = value;} }	
    	global string oppUrl { get {return (oppId==null) ? null : '/' + oppId;} }
    }

	// displays the coverted leads list
	public ConvertedLead[] getConversions() { 
		return ((convertedLeads==null || convertedLeads.isEmpty()) ? null : convertedLeads);
	}
	
    public pageReference deleteLeads() {
    	if (results != null) {
    		lead[] dels = new lead[0];
    		for (leadResult lr : results) {
    			if (lr.selected) dels.add(lr.getLead());
    		}
    		if (!dels.isEmpty()) {
    			delete dels;
    			//statusText = 'Deleted ' + string.valueOf(dels.size()) + ' lead' + ((dels.size()>1) ? 's.' : '.');
    		}	
    	}
    	return null;	
    }

    //not calculating the total records converted or deleted, but we could
    //global string statusText { get {return statusText;} set {statusText = value;} }
    
	// get rid of double quotes
	static string dq(string original) {
		if (original==null) {
			return null;
		} else {
			string fixed = '';
			string[] ss = original.split('"', -1);
			for (string s : ss) fixed += s;
			return fixed;
		}
	}
	 
	static string getOneEmail(string input) {
		if (input!=null) {
			string[] words = input.split('[,;\\s]', -1);
			pattern emailPattern=Pattern.compile('^\\S+@\\S+\\.+\\S+$');
			for (string s : words) {
				matcher m = emailPattern.matcher(s); 
				if(m.matches()) return s;
			}
		}
		return null;
	}

	/* TESTS */
	
	static testMethod void TestOneEmail() {
		
		system.assertEquals('evanc@npowerseattle.org', getOneEmail('evanc@npowerseattle.org'));
		system.assertEquals('evanc@npowerseattle.org', getOneEmail(' evanc@npowerseattle.org; '));
		system.assertEquals('evanc@npowerseattle.org', getOneEmail('evanc@npowerseattle.org;tom@this.com'));
		system.assertEquals('evanc@npowerseattle.org', getOneEmail('evanc@npowerseattle.org,tom@this.com'));
		system.assertEquals('evanc@npowerseattle.org', getOneEmail('something else evanc@npowerseattle.org '));
		system.assertEquals('evanc@npowerseattle.org', getOneEmail('evanc@npowerseattle.org 12/&*^#%\n@('));
		system.assertEquals(null, getOneEmail('something else'));
	}

	static testMethod void TestPage() {
	// this tests the main page functions, including conversion
	
		// load the page
		ONEN_CTRL_LeadConverter controller = new ONEN_CTRL_LeadConverter();
		
		//test empty lead results set
		controller.leadsource = 'Empty_LeadSource';
		List<LeadResult> emptyList = controller.getResults();
		system.assertEquals(emptyList, null);
		
		//grab a list of LeadSource values
		Schema.DescribeFieldResult L = Lead.LeadSource.getDescribe();
		List<Schema.PicklistEntry> ls = L.getPicklistValues();
	
		lead ld1 = new Lead (
			FirstName='Peter',
			LastName='Prongs_for_tests',
			company=NotProvidedLabel,
			email='pete@prongs.org',
			leadsource='bogus_leadsource',
			opportunity_date__c=system.today(),
			opportunity_amount__c=50,
			opportunity_record_type__c=ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS
		);
		insert ld1;
		
		account a1 = new account (
			Name='Rats R Us'
		);
		insert a1;
		
		contact c1 = new contact (
			FirstName = 'Peter', 
			LastName = 'Prongs_for_tests',
			AccountId = a1.id
		);
		insert c1;

		Opportunity newOpp = new Opportunity();
		newOpp.Amount = 50;
		newOpp.CloseDate = System.Today();
		newOpp.StageName = ONEN_LeadConversion.OppWonStageName;
		

		newOpp.RecordTypeID = GW_RecTypes.GetRecordTypeId('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		newOpp.CR_Contact_Id__c = c1.id; 
		newOpp.CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		newOpp.name = 'Peter Prongs_for_tests ' + system.today().year() + ' ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;  
		insert newOpp;

		lead ld2 = new Lead (
			FirstName='delete',
			LastName='me',
			leadsource='bogus_leadsource',
			company='delco',
			opportunity_amount__c=5
		);
		insert ld2;
		
		test.starttest();
		system.assert(controller.getNoOpenLeads()==false);
		system.assert(controller.getSources().size() > 2);
		
		controller.leadsource = 'All';
		List<LeadResult> secondList = controller.getResults();
		system.assert(secondList.size()>=2);
		
		controller.leadsource = 'bogus_leadsource';
		List<LeadResult> theList = controller.getResults();
		integer partnerCount = theList.size(); 
		system.assert(theList.size()>=2); 
		system.assertEquals(theList[0].noChoice, false); 
		system.assertEquals(theList[0].noAChoice, true); 
		system.assertEquals(theList[0].noOChoice, false);
		theList[0].oRecType = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
		system.assert(theList[0].oRecType == ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS); 
		system.assert(theList[0].leadUrl == '/' + ld1.id);
		system.assertEquals(theList[0].getlead().lastname, 'Prongs_for_tests');
		
		//test contact matches
		List<SelectOption> cMatches = theList[0].getMatches();
		system.assertEquals(cmatches.size(), 2);
		
		//test opportunity matches
		List<SelectOption> oMatches = theList[0].getOMatches();
		system.assertEquals(omatches.size(), 3);
		
		//test opp record types
		List<SelectOption> oRTs = theList[0].getORecTypes();
		system.assertEquals(oRTs.size(), RT.size() + 1);
		
		//test account matches
		List<SelectOption> aMatches = theList[0].getAMatches();
		system.assertEquals(amatches.size(), 1);
		
		
		// delete a lead
		theList[1].selected = true;
		controller.deleteLeads();
		theList = controller.getResults();
		system.assert(theList.size() == partnerCount - 1);
		
		// do a conversion
		theList[0].selected = true;
		system.assertEquals(theList[0].match, [select id from contact where lastName = 'Prongs_for_tests'].id); 		
		system.assertEquals(theList[0].amatch, [select accountid from contact where lastName = 'Prongs_for_tests'].accountid); 		
		controller.convertLeads();
		ConvertedLead[] cvns = controller.getConversions();		
		system.assert(cvns != null && !cvns.isEmpty());
		system.assertEquals(cvns[0].contactName, 'Peter Prongs_for_tests'); 
		system.assertEquals(cvns[0].success, true); 
		system.assertEquals(cvns[0].contactid, c1.id); 
		system.assertEquals(cvns[0].contacturl, '/'  + c1.id); 
		system.assertEquals(cvns[0].accountid, a1.id);
		system.assertEquals(cvns[0].accounturl, '/'  + a1.id); 
		system.assertEquals(cvns[0].accountName, 'Rats R Us'); 		
		system.assertEquals(cvns[0].oppName, 'Peter Prongs_for_tests ' + system.today().year() + ' Gift'); 
		system.assertEquals(cvns[0].oppid, newopp.id);
		system.assertEquals(cvns[0].oppurl, '/' + newOpp.id);
		test.stoptest();
	}
	
	static testMethod void convertOneLead() {
	// this tests the main page functions, including conversion
		
		// load the page
		ONEN_CTRL_LeadConverter controller = new ONEN_CTRL_LeadConverter();
		
	
		lead ld1 = new Lead (
			FirstName='Peter',
			LastName='Prongs_for_tests',
			company=NotProvidedLabel,
			email='pete_for_tests@prongs.org',
			leadsource='bogus_leadsource',
			opportunity_date__c=system.today(),
			opportunity_amount__c=50
		);
		insert ld1;
		
		account a1 = new account (
			Name='Rats R Us'
		);
		insert a1;
		
		contact c1 = new contact (
			FirstName = 'Peter',
			LastName = 'Prongs_for_tests',
			AccountId = a1.id
		);
		insert c1;

		Opportunity newOpp = new Opportunity();
		newOpp.Amount = 50;
		newOpp.CloseDate = System.Today();
		newOpp.StageName = ONEN_LeadConversion.OppWonStageName;
		
		
		newOpp.RecordTypeID = GW_RecTypes.GetRecordTypeId('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		newOpp.CR_Contact_Id__c = c1.id; 
		newOpp.CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		newOpp.name = 'Peter Prongs_for_tests ' + system.today().year() + ' ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;  
		insert newOpp;
		
		System.currentPageReference().getParameters().put('id', ld1.id);
		List<LeadResult> theList = controller.getResults();
		integer partnerCount = theList.size(); 
		system.assert(theList.size()==1); 
		system.assertEquals(theList[0].getlead().lastname, 'Prongs_for_tests');
		
		// do a conversion
		theList[0].selected = true;
		system.assertEquals(theList[0].match, [select id from contact where lastName = 'Prongs_for_tests'].id); 		
		system.assertEquals(theList[0].amatch, [select accountid from contact where lastName = 'Prongs_for_tests'].accountid); 		
		controller.convertLeads();
		ConvertedLead[] cvns = controller.getConversions();		
		system.assert(cvns != null && !cvns.isEmpty());
		system.assertEquals(cvns[0].contactName, 'Peter Prongs_for_tests'); 		
		system.assertEquals(cvns[0].accountName, 'Rats R Us'); 		
		system.assertEquals(cvns[0].oppName, 'Peter Prongs_for_tests ' + system.today().year() + ' Gift'); 
	}

	static testMethod void TestPageMax() {
	// this tests the page loading and converting the max number of leads

		// create a lot of leads
		lead[] lds = new Lead[0];
		for (integer i=0; i<20; i++) {
			lds.add(new Lead (
				FirstName='Jack' + string.valueof(i),
				LastName='Black' + string.valueof(i),
				company=(i>12 && i<17 ? 'Sasquatch' : NotProvidedLabel),
				email='jack' + string.valueof(i) + '@prongs.org',
				leadsource='bogus_leadsource',
				opportunity_date__c=system.today(),
				opportunity_amount__c=i
			));
		}
		insert lds;
		
		account a1 = new account (
			Name='D'
		);
		insert a1;

		// create 10 contacts
		contact[] cons = new Contact[0];		
		for (integer i=0; i<10; i++) {
			contact c = new contact (
				FirstName='Jack' + string.valueof(i),
				LastName='Black' + string.valueof(i),
				AccountId = a1.id
			);
			cons.add(c);
		}
		insert cons;

		// load the page
		ONEN_CTRL_LeadConverter controller = new ONEN_CTRL_LeadConverter(); 
		system.assert(controller.getNoOpenLeads()==false);
		system.assert(controller.getSources().size() > 2);
		
		controller.leadsource = 'bogus_leadsource'; 
		List<LeadResult> theList = controller.getResults();
		integer partnerCount = theList.size(); 
		system.assert(theList.size() > 19);
		system.assert(theList[0].getlead().lastname.startswith('Black'));
		system.assertEquals(theList[1].omatch, 'create_new');
		string leadname = theList[0].getlead().firstname + ' ' + theList[0].getlead().lastName;
		
		// do a big conversion
		for (LeadResult lr : theList) lr.selected = true;
		controller.convertLeads();
		ConvertedLead[] cvns = controller.getConversions();		
		system.assertNotEquals(cvns, null);
		system.assert(cvns.size() > 19);
		system.assertequals(cvns[0].contactName, leadname); 		
		system.assert(cvns[1].oppName != null); 
	}


}