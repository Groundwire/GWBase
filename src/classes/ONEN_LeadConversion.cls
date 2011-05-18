global virtual class ONEN_LeadConversion {
// Written by Evan Callahan (evan@groundwire.org) and Dave Manelski (davem@groundwire.org)
// Copyright (c) 2008, NPower Seattle, 403 23rd Ave S, Seattle, WA 98144
// Portions copyright (c) 2010 Groundwire, 1402 3rd Ave., Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

// class to assist in converting leads in bulk

	// constants for lead conversion
	public static final string OppWonStageName = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE;
	public static final string OppContactRole = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
	private static string GiftRectype = ONEN_Constants.OPP_NONMEMBER_RECTYPE_FORTESTS;

	// if opps have a "match" and are not yet closed, we'll update them to this stage
	public static final string OppStageForUpdates = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE;
	
	//boolean to limit size of SOQL queries for tests - set in the test itself
	public boolean IsATest = false;
	Integer limitSize;
	
	Conversion conv;
	Lead ld = new Lead();
	Contact con = new Contact();
	Contact[] contactFixes = new Contact[0];

	// class that represents the set of possible contact/account matches for a given lead
	global class LeadMatchup {
		public lead theLead;
		public map<id, string> conMatchMap;  //create a map to store the matching criteria
		public contact[] cons;		// list of all possible contact matches
		public account[] accts;  // map of leadid to account name/lead company matches
		public opportunity[] opps;  // list of all possible opp matches
		public string campaignId;	// campaign id of the campaign this lead is in
		
		public LeadMatchup(lead ld) {
			theLead = ld;
		}
	}

	// class to store the list of leads to convert
	public class ConvertSpec {
		public string leadId;
		public string contactId;
		public string accountId;
		public string oppId;
	}
	
	// class to return the conversion results
    public class Conversion {
    	public boolean success;
    	public string errors;
    	public string leadId;
    	public string contactId;
    	public string contactName;
    	public string accountId;
    	public string accountName;
    	public string oppId;
    	public string oppName;
    }

	// list and map for leads, matches, and conversions
	public lead[] leads;
	public map<id, LeadMatchup> matchMap;

	// need to grab the list of multiselect fields we want to map after converting, if any
	public string multiselectFields = '';
	
	// constructor - specify the maximum number of leads to load (defaults to 100)
	integer queryLimit;
	global ONEN_LeadConversion(integer leadLimit) {
		queryLimit = (leadLimit==null || leadLimit<1) ? 100 : leadLimit;
		matchMap = new map<id, LeadMatchup>();
	
		// get any multiselect field names for the contact query
		for ( Lead_Converter_Field_Map__c fm : Lead_Converter_Field_Map__c.getAll().values() ) {
			if (fm.field_type__c=='MultiSelect') multiselectFields += ',' + fm.contact_field__c;
		}	
	}
	 
	//describe call to get lead fields for dynamic SOQL
	Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
	
	//variable to hold dynamic SOQL of lead fields
	string querySOQL;
	
	// need to store this for later
	map<id, opportunity> leadsThatNeedOpps;
	// if opps are matched, we will update their stage and show them in the converted list
	map<id, opportunity> leadsWithOppUpdates;		
	// we will need to fix some leads before conversion
	lead[] leadFixes;
	// this needs to be transient when not in method scope - see http://community.salesforce.com/sforce/board/message?board.id=Visualforce&message.id=7701
  	// transient Database.LeadConvert[] lcs = new Database.LeadConvert[0] ;
	// this is where we compile the complete results
	Conversion[] conversions; 
			
	// get all open leads
	public integer loadAllLeads() {
		system.debug ('lead schema map: ' + leadFieldMap); 
    	querySOQL = 'SELECT ';
    	querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (string fieldname : leadFieldMap.keyset()) {
        	querySOQL += fieldname + ', ';
        }
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE isConverted = false';
        querySOQL += ' ORDER BY createddate limit :queryLimit'; 	
    	system.debug ('query string: ' + querySOQL);
    	leads = Database.Query(querySOQL);
		if (leads.isEmpty()) { 
			return 0; 
		} else {
			matchLeads();
			return leads.size();
		}
	}
	
	// get all open leads for specified LeadSource 
	public integer loadLeadsBySource(string LeadSource) {
		system.debug ('lead schema map: ' + leadFieldMap); 
    	querySOQL = 'SELECT ';
    	querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (string fieldname : leadFieldMap.keyset()) {
        	querySOQL += fieldname + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE leadSource=:LeadSource AND isConverted = false';
        querySOQL += ' ORDER BY createddate limit :queryLimit'; 	
    	system.debug ('query string: ' + querySOQL);
    	leads = Database.Query(querySOQL);
		if (leads.isEmpty()) { 
			return 0; 
		} else {
			matchLeads();
			return leads.size();
		}
	}
		
	// get specified lead 
	public integer loadOneLead(string leadId) {
    	querySOQL = 'SELECT ';
    	querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (string fieldname : leadFieldMap.keyset()) {
        	querySOQL += fieldname + ', ';
        }
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id=:leadId AND isConverted = false'; 	
    	
    	leads = Database.Query(querySOQL);
		if (leads.isEmpty()) { 
			return 0; 
		} else {
			matchLeads();
			return leads.size();
		}
	}

	// fill the matchMap with all the possible accounts, contacts, and opps for the entire lead list
	global virtual void matchLeads() {
		matchMap.clear();
		
		// build lists of all lead last names, emails, company names, and external ids
		string[] lastnames = new string[0];
		string[] fullnames = new string[0];
		string[] emails = new string[0];
		string[] conids = new string[0];
		string[] companyNames = new string[0]; 
		string[] eids = new string[0]; 
		string[] oppids = new string[0];
		for (lead ld : leads) {
			lastnames.add(ld.lastname);
			fullnames.add(((ld.firstname == null) ? '' : ld.firstname + ' ') + ld.lastname);
			string oneEmail = getOneEmail(ld.Email);
			if (oneEmail != null) {
				emails.add(oneEmail);
			}
			if (ld.company != null) companyNames.add(ld.company);
			if (ld.Contact_Id__c != null) conids.add(ld.Contact_Id__c);	
			if (ld.external_Id__c != null) eids.add(ld.external_Id__c);	
			// if (ld.Donation_ID__c != null) oppIds.add(ld.Donation_ID__c);	
		}
		
		//set the SOQL limit size to avoid test failures - "Too Many Rows"
		if (IsATest) {
			limitSize = 100;
		} else {
			limitSize = 500;
		}
		
		// query for all possible matches
		Map<Id, contact> allcons = new Map<Id, contact>([select Id, Name, FirstName, LastName, AccountId, Account.Name, Email, External_Id__c from Contact 
										where External_ID__c in :eids or email in :emails or 
										Name in :fullnames or id in :conids
										order by lastmodifieddate desc limit :limitSize]);
		allcons.putAll([select Id, Name, FirstName, LastName, AccountId, Account.Name, Email, External_Id__c from Contact 
										where External_ID__c in :eids or email in :emails or 
										(LastName in :lastnames and name not in :fullnames) 
										or id in :conids
										order by firstname limit :(limitSize-allcons.size()+1)]);
		account[] allaccts = [select id, name from account where name in :companyNames order by name];
		//opportunity[] allopps = [select id, name, donation_ID__c, amount, closedate, stagename from opportunity where donation_ID__c in :oppids];
		opportunitycontactrole[] allocrs = [select opportunityId, opportunity.Name, contactId, opportunity.amount, opportunity.closedate, opportunity.stagename
												from opportunitycontactrole where  
												opportunity.closedate > :system.today().addmonths(-3) and 
												contactID in :allcons.keyset() and isPrimary=true
												order by opportunity.closedate desc limit :limitSize];

		// for each lead, walk through the list and map the matches
		for (lead ld : leads) {
			LeadMatchup lm = new LeadMatchup(ld);
			if (!ld.campaignmembers.isEmpty()) lm.campaignId = ld.campaignmembers[0].campaignid; 
			
			string oneEmail = getOneEmail(ld.email);

			for (contact c : allcons.values()) {
				
				//first look for contact id match and just return that one
				if (ld.Contact_Id__c != null && c.id == ld.Contact_Id__c) {
					lm.cons = new contact[]{c};
					lm.conMatchMap = new map<id,string>();
					lm.conMatchMap.put(c.id, 'id');
					break;
				}				
				//next look for external id match and just return that one
				if (ld.External_Id__c != null && c.External_Id__c == ld.External_Id__c) {
					lm.cons = new contact[]{c};
					lm.conMatchMap = new map<id,string>();
					lm.conMatchMap.put(c.id, 'id');
					break;
				}
				//next try email
				if (oneEmail != null && c.email == oneEmail) {
					if (lm.cons==null) {
						lm.cons = new contact[]{c};
						lm.conMatchMap = new map<id,string>();
						lm.conMatchMap.put(c.id, 'email');
					} else {
						lm.cons.add(0, c);
						lm.conMatchMap.put(c.id, 'email');
					}
				// finally try name
				} else if (c.lastname == ld.lastname) {
					if (c.firstname == ld.firstname) {
						if (lm.cons==null) {
							lm.cons = new contact[]{c};
							lm.conMatchMap = new map<id,string>();
							lm.conMatchMap.put(c.id, 'firstlast');
						} else {
							lm.cons.add(c);
							lm.conMatchMap.put(c.id, 'firstlast');
						}
					// also add last name only matches - but only up to 40 so we have room for all exact name matches
					} else if (lm.cons==null || lm.cons.size() < 40) {
						if (lm.cons==null) {
							system.debug('Last only cons list created ' + lm.cons);	
							lm.cons = new list<contact>();
							lm.conMatchMap = new map<id,string>();
							lm.conMatchMap.put(c.id, 'last');
							
						} 
						lm.cons.add(c);
						lm.conMatchMap.put(c.id, 'last');
					}
				}
				if (lm.cons !=null && lm.cons.size()==50) break;
			}
			// look for company name matches
			for (account a : allaccts) {
				if (a.name == ld.company) {
					if (lm.accts==null) lm.accts = new account[0];
					lm.accts.add(a);
				}
			}
			// look for a matching donation ID
			//for (opportunity o : allopps) {
				//if (o.donation_ID__c == ld.donation_ID__c) {
					//o.description = 'id';
					//lm.opps = new opportunity[]{o};
					//break;
				//}
			//}
			// now look through opps with roles - unless the lead already matches by ID or unless you found no contacts at all 
			if (lm.opps == null && lm.cons != null) {
				for (opportunitycontactrole ocr : allocrs) {
					// if amount matches, look for this contactid in the contact matches for this lead
					//if (ocr.opportunity.amount == ld.opportunity_amount__c) {
						for (contact c : lm.cons) {
							if (c.id == ocr.contactid) {
								opportunity o = new opportunity(
									id=ocr.opportunityid, 
									name=ocr.opportunity.name,
									amount=ocr.opportunity.amount, 
									closedate=ocr.opportunity.closedate, 
									stagename=ocr.opportunity.stagename
								);
								
								// we have a match on amount and contact, now check date
								if (ocr.opportunity.closedate == ld.opportunity_date__c) {
									o.description = 'dateamount';
									if (lm.opps==null) {
										lm.opps = new opportunity[]{o};
									} else {
										lm.opps.add(0, o);
									}
								} else {
									o.description = 'amount';					
									if (lm.opps==null) lm.opps = new opportunity[0];
									lm.opps.add(o);
								}
								break;
							}
						}
					//}					
				}
			}
			matchMap.put(ld.Id, lm);		
		}
		
	}

	// function to convert one lead
	public Conversion convertLead(ConvertSpec spec) {
		ConvertSpec[] cs = new ConvertSpec[0];
		cs.add(spec);
		conversion[] c = convertLeads(cs);
		return (c.isEmpty() ? null : c[0]);
	} 

	
	//function to append values to a multiselect picklist
	private String AddToMultiselect(string MultiselectValue, string AddedValue) {  

		string NewMultiselectString = ''; 
		
		Set<string> MultiselectValueSet = new Set<string>();
		if( MultiselectValue != null ) {
			NewMultiselectString = ';' + MultiselectValue;
			MultiselectValueSet.addAll( MultiSelectValue.split(';') );
		}

		if (addedValue != null) {
			for( string newValue : AddedValue.split(';') ) {
				if ( newValue != null && !MultiselectValueSet.contains(newValue) ) {
					NewMultiselectString += ';' + newValue;		
					MultiselectValueSet.add(newValue);
				}
			}
		}
		
		return (NewMultiselectString == '') ? null : NewMultiselectString.substring(1); 
	}
		
	// function to convert leads as specified
	public Conversion[] convertLeads(ConvertSpec[] specs) {
		
		leadsThatNeedOpps = new map<id, opportunity>();
		leadsWithOppUpdates = new map<id, opportunity>();		

		conversions = new Conversion[0];
		contactFixes = new Contact[0];
		Database.LeadConvert[] lcs = prepareConversions(specs); 
		
		// fix leads if needed
		if (!leadFixes.isEmpty()) update leadFixes;
		
		// now convert all the leads
		//system.debug('Converting leads: ' + string.valueof(lcs.size()));

		Database.leadConvertResult[] lcrs = Database.convertLead(lcs, false);		
		//system.debug ('Conversion Set: '+ lcrs);
		//system.debug('Converted ' + string.valueof(lcrs.size()) + ' lead(s).');

		postProcessAndPrepareOpps(lcrs);
		
		//system.debug ('Leads Needing Opps: ' + leadsThatNeedOpps.values());
		
		// create opps
		if (!leadsThatNeedOpps.isEmpty()) {
	 		try {
				database.saveresult[] dsrs = database.insert(leadsThatNeedOpps.values(), false);
				//for (database.saveresult dsr : dsrs)
					//system.debug(logginglevel.error, dsr.getErrors());
			} catch (System.DmlException e) {		
				//for (Integer k = 0; k < e.getNumDml(); k++) System.debug(logginglevel.error, e.getDmlMessage(k)); 
			}
	 	}

		// now find matches for each opp that was created or updated
		if (!leadsThatNeedOpps.isEmpty() || !leadsWithOppUpdates.isEmpty()) {
			for (conversion conv : conversions) { 
				if (conv.success) {
					if (leadsThatNeedOpps.containsKey(conv.leadId)) {
						opportunity newOpp = leadsThatNeedOpps.get(conv.leadId);				
						conv.oppId = newOpp.id;
						conv.oppName = newOpp.name;
					} else if (leadsWithOppUpdates.containsKey(conv.leadId)) {
						opportunity updatedOpp = leadsWithOppUpdates.get(conv.leadId);				
						conv.oppId = updatedOpp.id;
						conv.oppName = updatedOpp.name;
					}
				}
			}
		}

	    return conversions;
	    
	}
	
	global virtual void postProcessAndPrepareOpps (Database.leadConvertResult[] lcrs) {
		// factored out 8/09 MS for the sake of modularity/overrideability
		// TBD split out opp prep to separate method??
		
		// need all the contact and account names
		set<id> conIds = new set<id>();
		for (Database.leadConvertResult lcr : lcrs) conIds.add(lcr.getContactId()); 		
		Map<id, contact> cMap = new Map<id, contact>();
		
		for ( contact c : database.query(
				'select Id, FirstName, LastName, MailingStreet, ' +
				GW_Utilities.StrTokenNSPrefix('Do_Not_Mail__c') + ', DoNotCall, ' +
				'HasOptedOutOfEmail, HomePhone, MailingCity, MailingState, MailingPostalCode, OtherStreet, ' +
				'OtherState, OtherCity,	OtherPostalCode,  Account.Name' + multiSelectFields +
				' from Contact where Id in :conIds')
				 ) cMap.put(c.id, c);
	
		// may need to update contacts
		customContactProcessing(lcrs, cMap);
		
		for (Database.leadConvertResult lcr : lcrs) { 		
			conv = new Conversion();
			conv.success = lcr.isSuccess();
			conv.leadId = lcr.getLeadId();
			
			if (lcr.isSuccess()) {
				con = cMap.get(lcr.getContactId());
				conv.contactId = con.id;
				conv.contactName = ((con.firstName==null) ? '' : con.firstName + ' ') + con.lastName;
				conv.accountId = lcr.getAccountId();
				conv.accountName = con.account.name;
				
				// fix the contact, if needed
				fixContact(lcr);
				
				// if there is donation data, create a donation opp
				if (leadsThatNeedOpps.containsKey(conv.leadId)) {
					Opportunity newOpp = leadsThatNeedOpps.get(conv.leadId);
					newOpp.Amount = ld.Opportunity_Amount__c;
					newOpp.CloseDate = (ld.Opportunity_Date__c != null) ? ld.Opportunity_Date__c : System.Today(); 
					newOpp.LeadSource = ld.LeadSource;
					
					if (ld.Opportunity_Stage__c == null) {
						newOpp.StageName = OppWonStageName;
					} else {
						newOpp.StageName = ld.Opportunity_Stage__c;
					}
					Map<String, Id> RecordTypeMap = new Map<String, Id>(GW_RecTypes.GetRecordTypeIdMap('Opportunity'));	
					if (ld.Opportunity_Record_Type__c == null || RecordTypeMap.get(ld.Opportunity_Record_Type__c) == null) {
						newOpp.RecordTypeID = RecordTypeMap.get(ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
						//newOpp.Name = con.firstName +  ' ' +  con.lastName + ' ' +  newOpp.CloseDate.year() + ' ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT;
					} else { 
						newOpp.RecordTypeID = RecordTypeMap.get(ld.Opportunity_Record_Type__c);
						//newOpp.Name = con.firstName +  ' ' +  con.lastName + ' ' +  newOpp.CloseDate.year() + ' ' + ld.Opportunity_Record_Type__c;
					}					
					newOpp.Name = ONEN_OpportunityMaintenance.oppName(newOpp, con.firstName +  ' ' +  con.lastName, false);
					
					// Check whether the donation record type gets cloned
					//if (Main.OPP_RECTYPES_CLONE.contains(newOpp.RecordTypeID)) {  
						//newOpp.Auto_Clone_When_Closed__c = true;
					//}
					newOpp.LeadSource = ld.LeadSource;
					newOpp.CR_Contact_Id__c = con.Id;  
					newOpp.CR_Contact_Role__c = OppContactRole;
					newOpp.CR_HHRoles__c = true;			 
					newOpp.CampaignId = matchMap.get(ld.id).campaignId;
					//system.debug('Creating: ' + newOpp.name);
				}
	        } else {
				conv.errors = '';
				for (database.error e : lcr.getErrors()) conv.errors += e.getMessage();
			} 
			conversions.add(conv);
		}
			
		// pass the opp maps over to a virtual routine
		customOppProcessing(leadsThatNeedOpps, leadsWithOppUpdates, cMap, lcrs);

		// fix contacts if needed
		if (!contactFixes.isEmpty()) update contactFixes;
		if (!leadsWithOppUpdates.isEmpty()) update leadsWithOppUpdates.values();
	}
	
	global virtual void customOppProcessing (map<id, Opportunity> newOpps, map<id, Opportunity> oppFixes, map<id, contact> cMap, list<Database.leadConvertResult> lcrs) {
		// override this with custom processing steps
	}

	global virtual void customContactProcessing (Database.leadConvertResult[] lcrs, map<id, contact> cMap) {
		// override this with custom processing steps
	}
	
	public List<Database.LeadConvert> prepareConversions (ConvertSpec[] specs) {
		// factored out 8/09 MS for the sake of modularity/overrideability
		
		// moved in here MMS
		Database.LeadConvert[] lcs = new Database.LeadConvert[0];
		
		leadFixes = new lead[0];
		
		// this set will help us avoid duplicate leads
		set<string> nameAndEmailKey = new set<string>();
		
		// status label is needed for conversion
		LeadStatus convertStatus = [Select MasterLabel from LeadStatus where IsConverted=true order by MasterLabel limit 1];	
		//system.debug('ConvertedStatusTest: ' + convertStatus);
		//system.debug('MatchMapTest: ' + matchMap.values());
		// prepare to convert
		for (ConvertSpec cs : specs) {
			
			if (matchMap.containsKey(cs.leadId)) {
				// get the lead from the original matches
				lead ld = matchMap.get(cs.leadId).theLead;
				
				// make sure this is not a duplicate in this set of leads
				string thisKey = (ld.firstName + ld.lastName + ld.email); 
				if (nameAndEmailKey.contains(thisKey)) {
					Conversion conv = new Conversion();
					conv.success = false;
					conv.leadId = cs.leadId;
					conv.errors = 'Lead was not converted because it appeared to be a duplicate.';
					conversions.add(conv);
				} else {
					nameAndEmailKey.add(thisKey);
					// check if this lead should get an opp after conversion
					if (cs.oppId == 'create_new' && ld.Opportunity_Amount__c != null && ld.Opportunity_Amount__c > 0) 
						leadsThatNeedOpps.put(cs.leadId, new Opportunity());
					
					// check if there is an opp to update after conversion
					if (cs.oppId != null && cs.oppId != 'create_new') {
						opportunity[] matchOpps = matchmap.get(cs.leadId).opps;
						if (matchOpps != null) {
							for (opportunity o : matchOpps) {
								if (o.id == cs.oppId) {
									opportunity opp = new Opportunity(
										id = cs.oppId, 
										name = o.name
									);
									if (ld.opportunity_date__c <= system.today()) opp.closedate = ld.opportunity_date__c;
									if (ld.opportunity_amount__c > 0) opp.amount = ld.opportunity_amount__c;
									opp.description = ld.opportunity_description__c;									
									if (OppStageForUpdates != null && o.stagename != 'Closed Won') {
										if (ld.Opportunity_Stage__c != null) {
											opp.stagename = ld.Opportunity_Stage__c;
										} else {
											opp.stagename = OppStageForUpdates;
										}
									}
									leadsWithOppUpdates.put(ld.id, opp);
									break;
								}
							}
						}
					}
					
					// check the address and email
					boolean fixEmail = (ld.email != null && ld.email != getOneEmail(ld.email));
					if (fixEmail) {
						lead leadFix = new Lead(id = ld.id); 				
						if (fixEmail) leadFix.email=getOneEmail(ld.email);
						leadFixes.add(leadFix);
					}
				
					Database.LeadConvert lc = new Database.LeadConvert();
					lc.setLeadId(cs.LeadId);
					if (cs.contactId != null && cs.contactId.length() > 14) lc.setContactId(cs.contactId); 
					if (cs.accountId != null && cs.accountId.length() > 14) lc.setAccountId(cs.accountId); 
					lc.setConvertedStatus(convertStatus.MasterLabel); 
					lc.setDoNotCreateOpportunity(true);
					lcs.add(lc);
				}
				
			} else {
				conv = new Conversion();
				conv.success = false;
				conv.leadId = cs.leadId;
				conv.errors = 'Lead was not converted because it was not in the set of original leads.';
				conversions.add(conv);		
			}
			
		}
		//system.debug('LCS Test: ' + lcs);
		return lcs;
	}
	
	global virtual List<Contact> fixContact(Database.leadConvertResult lcr) {
		
		// makes field changes to a single contact after lead conversion
		// this method only makes changes to the object, it doesn't do the update
		
		ld = matchMap.get(conv.LeadId).theLead;
		boolean fixWorkAddr = (con.MailingStreet==null && con.MailingCity == null && 
						   	   con.MailingState==null && con.MailingPostalCode == null);
		boolean fixHomeAddr = (con.OtherStreet==null && con.OtherCity == null && 
						       con.OtherState==null && con.OtherPostalCode == null);    								   
		contact c = new contact( id = lcr.getContactId());
		
		if (fixWorkAddr) {
			c.MailingStreet = ld.Street; 
			c.MailingCity = ld.City;
			c.MailingState = ld.State;
			c.MailingPostalCode = ld.PostalCode;
			c.MailingCountry = ld.Country;
		}
		
		if (fixHomeAddr) {
			c.OtherStreet = ld.Home_Street__c;
			c.OtherCity = ld.Home_City__c;
			c.OtherState = ld.Home_State__c;
			c.OtherPostalCode = ld.Home_PostalCode__c;
		}
										
		//Dynamic apex to update different types of fields like checkbox, multiselect picklist, address blocks, etc.
		for ( Lead_Converter_Field_Map__c fm : Lead_Converter_Field_Map__c.getAll().values() ) {
			
			// get the lead value
			object leadData = ld.get(fm.name);
			
			// make sure there is a value
			if (leadData != null) {
				
				// for multiselect, add the value to the existing data
				if (fm.field_type__c == 'MultiSelect')
					leadData = AddToMultiselect(string.valueOf(con.get(fm.contact_field__c)), string.valueOf(leadData));
				
				// copy lead data to the conact field - but only copy checkboxes if they are checked
				if (fm.field_type__c != 'Checkbox' || leadData==true) {
					try {
						c.put(fm.contact_field__c, leadData);
					} catch (exception e) {
						system.debug('Could not set contact field ' + fm.contact_field__c + ' to ' + leadData);
					} 
				}
			}
		}
		
		// hook to make any custom fixes
		customContactFix (lcr,c);
				
		contactFixes.add(c);
		return contactFixes;
	}
	
	global virtual void customContactFix (Database.leadConvertResult lcr, Contact c) {
		// override this with custom processing steps
	}
	
	
	public static string getOneEmail(string input) {
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
	
	static testMethod void testAddToMultiSelect() {
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		system.assertEquals(lc.AddToMultiSelect('brown;blue','red;green'), 'brown;blue;red;green');
		system.assertEquals(lc.AddToMultiSelect(null,'red;green'), 'red;green');
		system.assertEquals(lc.AddToMultiSelect('red;green',null), 'red;green');

	}
	
	static testMethod void TestEmptyLeadSet() {
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		system.debug(lc.loadLeadsBySource('Empty_LeadSource'));
		lc.loadOneLead(null);
		system.assert(lc.leads.isEmpty());
		
	}
	
	static testMethod void TestOneLead() {
		
		// need the field map settings if missing
		if (!Lead_Converter_Field_Map__c.getAll().containsKey(GW_Utilities.StrTokenNSPrefix('home_phone__c'))) { 
			Lead_Converter_Field_Map__c lcfm = new Lead_Converter_Field_Map__c();
			lcfm.name = GW_Utilities.StrTokenNSPrefix('home_phone__c');
			lcfm.contact_field__c = 'homephone';
			insert lcfm;
		}
		if (!Lead_Converter_Field_Map__c.getAll().containsKey(GW_Utilities.StrTokenNSPrefix('Do_Not_Mail__c'))) { 
			Lead_Converter_Field_Map__c lcfm = new Lead_Converter_Field_Map__c();
			lcfm.name = GW_Utilities.StrTokenNSPrefix('Do_Not_Mail__c');
			lcfm.contact_field__c = GW_Utilities.StrTokenNSPrefix('Do_Not_Mail__c');
			insert lcfm;
		}
		
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
	
		lead ld = new Lead (
			FirstName='George',
			LastName='Blower_for_tests',
			email='georgeoey@blow.com',
			company=ONEN_Constants.NOT_PROVIDED_LABEL,
			leadsource=bogusLeadSource,
			external_id__c='8675309',
			phone='(206) 555-1212',
			hasoptedoutofemail=true,
			Do_Not_Mail__c=true,
			DoNotCall=true,
			city='Timbuktu',
			opportunity_amount__c=100
		);
		insert ld;
		
		account a1 = new account (
			Name='Rats R Us'
		);
		insert a1;
		
		contact c1 = new contact (
			FirstName = 'George',
			LastName = 'Blauer_for_tests',
			External_Id__c = '8675309',
			AccountId = a1.id
		);
		insert c1;
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		lc.IsATest = true;
		system.debug(lc.loadOneLead(ld.id));
		
		ConvertSpec cs = new ConvertSpec();
		cs.leadId = ld.id;
		cs.contactId = null;
		cs.accountId = null;
		cs.OppId = null;
		 
		conversion conv = lc.convertLead(cs);
		
		system.assert(conv.success);

		contact c = [select id, lastname, mailingcity, othercity, phone, hasoptedoutofemail, Do_Not_Mail__c, DoNotCall from contact where id=:conv.contactId limit 1];
		system.assertEquals(c.lastname, ld.lastname);
		system.assertEquals(c.phone, ld.phone);
		system.assertEquals(c.othercity, null);
		system.assertEquals(c.mailingcity, ld.city);		
		system.assertEquals(true, c.hasoptedoutofemail);
		system.assertEquals(true, c.Do_Not_Mail__c);
		system.assertEquals(true, c.DoNotCall);
		
	}
	
	static testMethod void TestEmailMatch() {
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
	
		lead ld = new Lead (
			FirstName='George',
			LastName='Blower_for_tests',
			email='georgeoey@blow.com',
			company=ONEN_Constants.NOT_PROVIDED_LABEL,
			opportunity_amount__c=100,
			LeadSource=bogusLeadSource
		);
		insert ld;
		
		account a1 = new account (
			Name='Rats R Us'
		);
		insert a1;
		
		contact c1 = new contact (
			FirstName = 'George',
			LastName = 'Blauer_for_tests',
			Email = 'georgeoey@blow.com',
			AccountId = a1.id
		);
		insert c1;
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		lc.IsATest = true;
		system.debug(lc.loadOneLead(ld.id));
		
		ConvertSpec cs = new ConvertSpec();
		cs.leadId = ld.id;
		cs.contactId = null;
		cs.accountId = null;
		cs.OppId = null;
		 
		conversion conv = lc.convertLead(cs);
		contact c = [select id, email from contact where id=:conv.contactId limit 1];
		system.assertEquals(c.email, ld.email);
		
	}
	
	static testMethod void TestLead() {
	// this tests the basic lead conversion fixup
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
	
		lead ld = new Lead (
			FirstName='George',
			LastName='Blower_for_tests',
			email='georgeoey@blow.com',
			company=ONEN_Constants.NOT_PROVIDED_LABEL,
			leadsource=bogusLeadSource,
			phone='(206) 555-1212',
			hasoptedoutofemail=true,
			city='Timbuktu',
			opportunity_amount__c=100
		);
		insert ld;
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		system.debug(lc.loadLeadsBySource(bogusLeadSource));
		LeadMatchup lm = new LeadMatchup(ld);
		system.assert(lm.cons==null);
		
		ConvertSpec cs = new ConvertSpec();
		cs.leadId = ld.id;
		cs.contactId = null;
		cs.accountId = null;
		cs.OppId = null;
		 
		conversion conv = lc.convertLead(cs);
		
		system.assert(conv.success);

		contact c = [select id, lastname, mailingcity, othercity, phone, hasoptedoutofemail from contact where id=:conv.contactId limit 1];
		system.assertEquals(c.lastname, ld.lastname);
		system.assertEquals(true, c.hasoptedoutofemail);
		system.assertEquals(c.phone, ld.phone);
		system.assertEquals(c.othercity, null);
		system.assertEquals(c.mailingcity, ld.city);
	}

	static testMethod void TestLeadWorkAddr() {
		
		account a = new account (
			name='CredCo_for_tests'
		);
		insert a;

		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
		
		lead ld = new Lead (
			FirstName='George',
			LastName='Blower_for_testsXXXXXXX',
			email='Georgeoey@blow.netcom',
			company='CredCo_for_tests',
			leadsource=bogusLeadSource,
			phone='(206) 555-1212',
			city='Timbuktu',
			opportunity_amount__c=100
		);
		insert ld;
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		lc.IsATest = true;
		system.debug(lc.loadOneLead(ld.id));
		
		ConvertSpec cs = new ConvertSpec();
		cs.leadId = ld.id;
		cs.contactId = null;
		cs.accountId = null;
		cs.oppId = null;
		 
		conversion conv = lc.convertLead(cs);
		system.assert(conv.success);

		contact c = [select id, lastname, mailingcity, othercity, phone from contact where id=:conv.contactId limit 1];
		system.assertEquals(c.lastname, ld.lastname);
		system.assertEquals(c.phone, ld.phone);
		system.assertEquals(c.mailingcity, ld.city);
		system.assertEquals(c.othercity, null);
	}

	static testMethod void TestLeadWithOppUpdate() {
		
		// need the field map setting if missing
		if (!Lead_Converter_Field_Map__c.getAll().containsKey('home_phone__c')) { 
			Lead_Converter_Field_Map__c lcfm = new Lead_Converter_Field_Map__c();
			lcfm.name = 'home_phone__c';
			lcfm.contact_field__c = 'homephone';
			insert lcfm;
		}
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
		
		lead ld = new Lead (
			FirstName='George',
			LastName='Blower_for_tests',
			email='georgeoey@blow.com',
			company='TD',
			leadsource=bogusLeadSource,
			home_phone__c='(206) 555-1212',
			home_city__c='Timbuktu',
			opportunity_amount__c=500,
			opportunity_date__c = system.today()
		);
		insert ld;

		account a1 = new account (
			Name='TD'
		);
		insert a1;

		contact c1 = new contact (
			FirstName='J',
			LastName='Blower_for_tests',
			AccountId = a1.id
		);
		insert c1;

		opportunity opp = new Opportunity ( 
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			name = 'George Blower_for_tests 2008 Donation',
			stagename = 'Prospecting',
			CR_Contact_Id__c = c1.id,
			CR_Contact_role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS),
			closedate = system.today().addmonths(1),
			amount=500
		);
		insert opp;	
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		lc.IsATest = true;
		system.debug(lc.loadLeadsBySource(bogusLeadSource));
		
		ConvertSpec cs = new ConvertSpec();
		cs.leadId = ld.id;
		cs.contactId = c1.id;
		cs.accountId = a1.id;
		cs.oppId = opp.id;
		 
		conversion conv = lc.convertLead(cs);

		system.assert(conv.success);
		
		// "new" opp should be the existing one 
		system.assertequals(conv.oppid, opp.id);
		
		contact c = [select id, lastname, mailingcity, othercity, homephone from contact where id=:conv.contactId limit 1];
		system.assertEquals(c.lastname, ld.lastname);
		system.assertEquals(c.homephone, ld.home_phone__c);
		system.assertEquals(c.mailingcity, null);
		system.assertEquals(c.othercity, ld.home_city__c);
		
		opportunity o = [select id, amount, name, stagename, closedate, campaignid from opportunity where id=:conv.oppId limit 1];
		system.assertEquals(o.amount, ld.opportunity_amount__c);
		system.assertEquals(o.name, 'George Blower_for_tests 2008 Donation');
		system.assertEquals(o.stagename, ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE);
		system.assertEquals(o.closedate, system.today());
	}

	static testMethod void TestLeadWithOpp() {
		
		// need the field map setting if missing
		if (!Lead_Converter_Field_Map__c.getAll().containsKey('home_phone__c')) { 
			Lead_Converter_Field_Map__c lcfm = new Lead_Converter_Field_Map__c();
			lcfm.name = 'home_phone__c';
			lcfm.contact_field__c = 'homephone';
			insert lcfm;
		}
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
		
		lead ld = new Lead (
			FirstName='George_TestLeadWithOpp',
			LastName='Blower_for_tests',
			email='georgeoey@blow.com',
			company=ONEN_Constants.NOT_PROVIDED_LABEL,
			leadsource=bogusLeadSource,
			home_phone__c='(206) 555-1212',
			home_city__c='Timbuktu',
			opportunity_amount__c=500,
			opportunity_stage__c='Closed Won'
		);
		insert ld;
	
		system.assertEquals(ld.Opportunity_Record_Type__c, null);
		
		// add a campaign w/ default camp. mbr status settings
		Campaign testCamp1 = new Campaign (
			Name = 'Test Campaign 1',
			IsActive = True
		);
		insert testCamp1;

		// add lead to the campaign
		CampaignMember[] members = new CampaignMember[] {
			new CampaignMember(leadid=ld.id, campaignid=testcamp1.id)
		};
		insert members;
			
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		lc.IsATest = true;
		system.debug(lc.loadLeadsBySource(bogusLeadSource));
		
		ConvertSpec cs = new ConvertSpec();
		cs.leadId = ld.id;
		cs.oppId = 'create_new';
		 
		conversion conv = lc.convertLead(cs);

		system.assert(conv.success);
		system.assert(conv.oppid != null);

		contact c = [select id, lastname, mailingcity, othercity, homephone from contact where id=:conv.contactId limit 1];
		system.assertEquals(c.lastname, ld.lastname);
		system.assertEquals(c.homephone, ld.home_phone__c);
		system.assertEquals(c.mailingcity, null);
		system.assertEquals(c.othercity, ld.home_city__c);
		
		opportunity o = [select id, amount, name, stagename, closedate, campaignid, recordtypeid from opportunity where id=:conv.oppId limit 1];
		system.assertEquals(o.amount, ld.opportunity_amount__c);
		system.assertEquals(o.name, 'George_TestLeadWithOpp Blower_for_tests ' + system.today().year() + ' ' + ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
		system.assertEquals(o.stagename, 'Closed Won');
		system.assertEquals(o.closedate, system.today());
		//system.assertEquals(o.campaignid, testcamp1.id);

		opportunitycontactrole[] ocr = [select contactId, role from opportunitycontactrole where opportunityid=:o.id and isprimary=true];
		system.assert(!ocr.isempty());
		system.assertEquals(ocr[0].role, OppContactRole);
		system.assertEquals(ocr[0].contactId, c.id);
	}

	static testMethod void TestDupeLeads() {
	// this tests that two opp leads with same name make 1 new contact and one error
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
	
		lead ld = new Lead (
			FirstName='George',
			LastName='Blowow_for_tests',
			company='CrudCo',
			leadsource=bogusLeadSource,
			home_phone__c='(206) 555-1212',
			opportunity_amount__c=500
		);
		insert ld;
		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(10);
		lc.IsATest = true;
		system.debug(lc.loadLeadsBySource(bogusLeadSource));
		
		convertSpec[] cs = new convertSpec[0];

		ConvertSpec cs1 = new ConvertSpec();
		cs1.leadId = ld.id;
		cs1.oppId = 'create_new';
		cs.add(cs1);
		 
		lead ld2 = new Lead (
			FirstName='George',
			LastName='Blowow_for_tests',
			company='CrudCo',
			leadsource=bogusLeadSource,
			home_phone__c='(206) 555-1212',
			opportunity_amount__c=100
		);
		insert ld2;
		
		ConvertSpec cs2 = new ConvertSpec();
		cs2.leadId = ld.id;
		cs1.oppId = 'create_new';
		cs.add(cs2);
		
		conversion[] conv = lc.convertLeads(cs);

		// only one should work
		system.assert(conv[0].success || conv[1].success);
		system.assert(!(conv[0].success && conv[1].success));

		contact[] c = [select id from contact where lastname = 'Blowow_for_tests'];
		system.assertEquals(1, c.size());
		account[] a = [select id from account where name = 'CrudCo'];
		system.assertEquals(1, c.size());
	}

	static testMethod void testTwoLeadsToOneContact() {
	
		// NEED A TEST
		
	}
	
	static testMethod void TestLeadMax() {
		
		String NotProvidedLabel = ONEN_Constants.NOT_PROVIDED_LABEL;
		
		//create bogus LeadSource
		String bogusLeadSource = 'bogus_leadsource';
		
		// create a lot of leads - we'll only convert whatever is allowed
		lead[] lds = new Lead[0];
		for (integer i=0; i<20; i++) {
			lds.add(new Lead (
				FirstName='Jack' + string.valueof(i),
				LastName='Black' + string.valueof(i),
				company=(i>40 ? 'Sasquatch' : NotProvidedLabel),
				email='jack' + string.valueof(i) + '@prongs.org',
				leadsource=bogusLeadSource,
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

		ONEN_LeadConversion lc = new ONEN_LeadConversion(20);
		lc.IsATest = true;
		system.debug(lc.loadLeadsBySource(bogusLeadSource));
		
		convertSpec[] cs = new convertSpec[0];

		for (leadMatchup lm : lc.matchMap.values()) {
		ConvertSpec cs1 = new ConvertSpec();
		cs1.accountId = lm.cons==null ? null : lm.cons[0].accountid;
		cs1.leadId = lm.thelead.id;
		cs1.contactId = lm.cons==null ? null : lm.cons[0].id;
		cs1.oppId = 'create_new';
		cs.add(cs1);
		}
		system.debug('Max Test');
		conversion[] conv = lc.convertLeads(cs);
		
		system.assert(!conv.isEmpty());
		system.debug(conv[0].toString());
	}

	
/* AUTOCONVERT DISABLED
	static testMethod void TestLeadAutoConvert() {
	// this tests the automatic lead conversion

		//grab a list of LeadSource values
		Schema.DescribeFieldResult L = Lead.LeadSource.getDescribe();
		List<Schema.PicklistEntry> ls = L.getPicklistValues();
	
		contact c = new Contact (
			FirstName='Joe',
			LastName='Blow',
			email='joehoho@blow.com'
		);
		insert c;

		lead ld = new Lead (
			FirstName='Joe', 
			LastName='Blew',
			email='joehoho@blow.com',
			company=ONEN_Constants.NOT_PROVIDED_LABEL,
			title='changed',
			leadsource=ls[0].getlabel()
		);
		insert ld;
		system.assertEquals([select title from contact where email='joehoho@blow.com' limit 1].title, ld.title);
	}
*/

}