Global virtual class ONEN_OpportunityMaintenance {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General global License, Version 3. http://www.gnu.org/licenses/

	global ONEN_OpportunityMaintenance(Id oppId) {
		if (oppId!=null) {
			opportunityId = oppId;	
		}
	}
	
	global Id opportunityId;
	
	global void setCurrentOpportunityId(Id oppId) {
		opportunityId = oppId;
		
	}
	
	global Opportunity thisOpp;
	
	global Opportunity newOpp;
	
	//list of opps for the primary donor
	global List<Opportunity> openOpportunitiesForDonor = new List<Opportunity>();
	
	//contact to hold donor data
	global Contact donorForMatchingGift;
	
	//role for the donor
	global OpportunityContactRole donorRoleOnMatchedGift = new OpportunityContactRole();
	global Id donorIdOnMatchedGift;
	
	//new matching gift
	global Opportunity matchingGift;
	
	global String matchingGiftName(Date closeDate) {
		//grab Account Name
		Account thisAccount = [Select Name from Account where Id = :matchingGift.AccountId limit 1];
		return thisAccount.Name + ' ' + closeDate.year() +' Matching Gift for ' + donorForMatchingGift.ONEN_Household__r.Name;
	}

	//values used in naming function below	
	global Id primaryContactId;
	global Id primaryAccountId;
	global Id recordTypeId;
	global Date closeDate = system.Today();
	
	global Contact primaryContact = new Contact();
	global Account primaryAccount = new Account();
	
	
	//get the primary contact from the id
	//if the client of the NewOppWizard wants to add additional contact fields on the page, they need to override this soql.
	global virtual Contact getPrimaryContact() {		
		Contact[] contacts = [select HouseholdName__c, FirstName, LastName, Anonymous__c from Contact where Id=:primaryContactId];
		if (contacts.size() == 0) {
			primaryContact = null; 
		} else {
			primaryContact = contacts[0];
		}
		
		return primaryContact;
	}
	//get the primary account from the id
	//if the client of the NewOppWizard wants to add additional Account fields on the page, they need to override this soql.
	global virtual Account getPrimaryAccount() {
		if(primaryAccountId!=null) {
			Account[] accs = [select Name from Account where Id=:primaryAccountId];
			if (accs.size() == 0) {
				return null;
			}
			primaryAccount = accs[0];
			if(primaryAccount.Name == ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME) {
				isIndividualAccount = true;
			} else {
				isIndividualAccount = false;	
			}
			return primaryAccount;
		} else{
			return null;
		}
	}
	//flag if the current account is eh individual account
	global Boolean isIndividualAccount = false;
	
	//get open opps based on the primary contact
	// chgd 6/09 MMS to use 2 SOQLs rather than subquery since seemed to be tripping SF bug 
	//if the client of the NewOppWizard wants to change the list, they need to override this soql.
	global virtual List<Opportunity> getContactOpenOpps() {
		if(primaryContactId!=null) {
			set<id> conroleIDs = new set<id>();
			OpportunityContactRole[] conroles = [Select OpportunityId from OpportunityContactRole WHERE ContactId=:primaryContactId];
			for (OpportunityContactRole conrole : conroles) {
				conroleIDs.add(conrole.OpportunityId);
			}
			// openOpportunitiesForDonor = [select Id, Name, CloseDate, Amount,CampaignId,RecordTypeId,StageName,Total_Unpaid__c,Next_Payment_Due_Date__c FROM Opportunity WHERE Total_Unpaid__c>0 AND Id IN (Select OpportunityId from OpportunityContactRole WHERE ContactId=:primaryContactId ) Order by CloseDate];
			openOpportunitiesForDonor = [select Id, Name, CloseDate, Amount,CampaignId,RecordTypeId,StageName,Total_Unpaid__c,Next_Payment_Due_Date__c FROM Opportunity WHERE Total_Unpaid__c>0 AND Id IN :conroleIDs Order by CloseDate];
		} else {
			openOpportunitiesForDonor.clear();
		}
		return openOpportunitiesForDonor;
	}
	//get open opps based on the primary org
	//if the client of the NewOppWizard wants to change the list, they need to override this soql.
	global virtual List<Opportunity> getAccountOpenOpps() {
		if(primaryAccountId!=null&&!isIndividualAccount) {
			openOpportunitiesForDonor = [select Id, Name, CloseDate, Amount,CampaignId,RecordTypeId,StageName,Total_Unpaid__c,Next_Payment_Due_Date__c FROM Opportunity WHERE Total_Unpaid__c>0 AND AccountId=:primaryAccountId Order by CloseDate];
		} else {
			openOpportunitiesForDonor.clear();
		}
		return openOpportunitiesForDonor;
	}
	
	global Id cloneThisOpp(Integer Offset, String OffsetUnit) {

		//clone opp
		newOpp = thisOpp.clone(false);

		//set primary account
		primaryAccountId = newOpp.AccountId;
		primaryAccount =getPrimaryAccount();
		
		//clear campaign
		newOpp.CampaignId = null;
		
		//MS: check if this is a membership, and if so then also increment member dates
		// and set as Renewal	
    	OppRollupSettings__c ors = OppRollupSettings__c.getInstance();
    	if (ors != null && ors.Membership_Record_Types__c != null) {
			set<string> mbrRecordTypeNames = new set<string>(ors.Membership_Record_Types__c.split(';'));
			set<id> mbrRTids = GW_RecTypes.GetRecordTypeIdSet('Opportunity', mbrRecordTypeNames);    		   	
		
			if ( OffsetUnit=='Year' && mbrRTids.contains(newOpp.RecordTypeId) ) {
				// redefine the opp vars to include member fields
				thisOpp = [select CloseDate,Account.Name,Amount,AccountId,StageName,RecordTypeId,Fund__c,
							Membership_Start_Date__c, Membership_End_Date__c, Member_Level__c, Membership_Origin__c 
							from Opportunity where Id =:thisOpp.Id];
				newOpp = thisOpp.clone(false);
				// now increment the member fields
				if ( newOpp.Membership_Start_Date__c != null ) {
					newOpp.Membership_Start_Date__c = newOpp.Membership_Start_Date__c.addYears(Offset);
					newOpp.Membership_End_Date__c = newOpp.Membership_End_Date__c.addYears(Offset);
					newOpp.Membership_Origin__c = 'Renewal';
				}
			}
    	}
		
		String NewOppName;
		String NewOppPrefix;
		String NewOppSuffix;
		Date NewCloseDate;
		Id primaryContactRoleContactId;
		String primaryContactRoleRole = '';
		
		Id DefaultAccountId = ONEN_DefaultAccount.GetIndividualAccountId();
		//System.debug('primaryContactRole.Role = ' + primaryContactRole.Role);

		
		//MP: Assume this is cloning for one year out
		Integer NewYear;
		Integer NewMonth; 
		String newCloseDateName;
		//set the new dates and names for the new opp based on offset and offsetunit
				
		boolean monthlyGift = false;
		if (OffsetUnit=='Year') {			
			newOpp.CloseDate = thisOpp.CloseDate.addYears(Offset);
		} else if (OffsetUnit=='Month') {
			//set the date and date name for a month offsetunit	
			monthlyGift = true;		
			newOpp.CloseDate = thisOpp.CloseDate.addMonths(Offset);
		}
		

		if(newOpp.AccountId==null||newOpp.AccountId==DefaultAccountId) {
			//swa 2008-11-26: household name field renamed to support xobject formulas
			OpportunityContactRole[] primaryContactRole = [select ContactId, Contact.FirstName, Contact.LastName, Contact.HouseholdName__c, Role, IsPrimary from OpportunityContactRole where OpportunityId = :thisOpp.id and IsPrimary=true];

			if ( primaryContactRole.size() > 0 ) {
				//swa 2008-11-26: household name field renamed to support xobject formulas
				primaryContactId = primaryContactRole[0].ContactId;
				primaryContact = getPrimaryContact();
				primaryContactRoleContactId = primaryContactRole[0].ContactId;
				primaryContactRoleRole = primaryContactRole[0].Role;
			}
            newOpp.Name = oppName(newOpp, primaryContact.HouseholdName__c, monthlyGift);
        }
		
		//MP: assign correct stage NOTE: do we assume prospecting?
		newOpp.StageName=ONEN_Constants.OPP_DEFAULT_STAGE;
		
		//MP: Set contact id & role to invoke trigger NOTE: find and put name of said triggers here in comments
		newOpp.CR_Contact_Id__c=primaryContactRoleContactId;
		newOpp.CR_Contact_Role__c=primaryContactRoleRole;						
		//system.debug('Teh opp to be created: ' + newOpp);
		Id newOppId;
		//try {
			//create new opp
			insert newOpp;
			newOppId=newOpp.id;
		//} catch (System.DmlException e) {		
		//	for (Integer k = 0; k < e.getNumDml(); k++) {
		//	 System.debug(e.getDmlMessage(k)); 
		//	}
		//}		
		
		//System.debug('newOpp = ' + newOpp.id); 
		return newOppId;
	}
	
	//generate a name for the new opp
	global string oppName(String oppApplicant) {
		String OppNamePrefix;
		if (oppApplicant=='Contact') {
			OppNamePrefix = primaryContact.HouseholdName__c;
		} else {		
			OppNamePrefix = primaryAccount.Name;				
		}		
		return oppName(newOpp, OppNamePrefix, false);
	}	
	
    // generate a name for the opp - the opp record must include data for 
    // accountid and account.name, or ContactId__c and primary_contact__r.householdName__c 
    global static string oppName(opportunity opp, string payer, boolean monthlyGift) {
		
       	// get the opp name format setting
    	OppRollupSettings__c ors = OppRollupSettings__c.getInstance();
    	string name = (monthlyGift && ors != null && ors.opp_name_format_monthly__c != null) ?
    		ors.opp_name_format_monthly__c : (ors != null && ors.opp_name_format__c != null) ?
    		ors.opp_name_format__c : (monthlyGift ? '[payer] [mm]/[yyyy] [rectype]' : '[payer] [yyyy] [recurring] [rectype]');

		// depending on the opp data, set the payer to the account name, household name, or contact name
		name = name.replace('[payer]', payer);

		// fill record type name
		name = name.replace('[rectype]', (opp.RecordTypeId == null) ? '' :
			GW_RecTypes.GetRecordTypeName('Opportunity', opp.RecordTypeId));

		// fill opp amount, including cents only if there are any
		string amt = (opp.amount == null) ? '' : '$' + opp.amount.format();
		if (amt.length() > 1 && (amt.lastIndexOf('.') == amt.length() - 2)) amt += '0';
		name = name.replace('[amount]', amt); 

		// fill other fields
		name = name.replace('[stage]', (opp.stagename == null) ? '' : opp.stagename );
		name = name.replace('[mm]', (opp.closedate == null) ? '' : string.valueOf(opp.closeDate.month()));
		name = name.replace('[dd]', (opp.closedate == null) ? '' : string.valueOf(opp.closeDate.day()));
		name = name.replace('[yyyy]', (opp.closedate == null) ? '' : string.valueOf(opp.closeDate.year()));
		name = name.replace('[type]', (opp.type == null) ? '' : opp.type );
		name = name.replace('[recurring]', (opp.Recurring_Payment_Profile__c == null) ? '' : 'Recurring');
				
		name = name.replaceAll('  ', ' ');
        return name.trim();    
    }
    
    
    // automatically name opps that don't have a name.  called from the Opportunity trigger.
	global static void OpportunityAutoName(list<Opportunity> listOpps) {
	    list<Opportunity> oppsToName = new list<Opportunity>();
	    set<id> conIds = new set<id>();
	    set<id> acctIds = new set<id>();
	
	    for (Opportunity o : listOpps) {			
		    if (o.StageName == null) o.stageName = ONEN_Constants.OPP_DEFAULT_STAGE;
		    if (o.CloseDate == null) o.closedate = system.today();
	    	if (o.name == null) {
	    		if (o.CR_Contact_Id__c != null) conIds.add(o.CR_Contact_Id__c);
	    		if (o.accountId != null && o.accountId != ONEN_DefaultAccount.getIndividualAccountId()) 
	    			acctIds.add(o.accountid);
	    		oppsToName.add(o);
	    	}
	    } 
	    
	    if (!oppsToName.isEmpty()) {
	    	map<id, Contact> conMap = new map<id, Contact>([select id, HouseholdName__c, name, Anonymous__c 
	    		from Contact where Id in : conIds]);
	    	map<id, Account> acctMap = new map<id, Account>([select id, Name from Account where Id in : acctIds]);
	   	
	    	for (Opportunity o : oppsToName) {
			    boolean isOrgOpp = (o.accountId != null && o.accountId != ONEN_DefaultAccount.GetIndividualAccountId());
			    Contact c = (o.CR_Contact_Id__c == null) ? null : conMap.get(o.CR_Contact_Id__c); 
				string payer =  
					(isOrgOpp) ? acctMap.get(o.accountId).name : 
					(c == null) ? '[Unknown]' :
					(c.householdname__c != null) ? c.HouseholdName__c :  
					c.name;
	
				// get the name
			    o.Name = ONEN_OpportunityMaintenance.oppName(o, payer, false);
		    }
		}
	}    
    
//////////////////////////////////////////////////////////////////////////////////////////
// TEST CODE
//////////////////////////////////////////////////////////////////////////////////////////
    
	static testMethod void TestOppAutoNaming() {	
		delete [select Id from OppRollupSettings__c];				 
		OppRollupSettings__c ors = OppRollupSettings__c.getInstance();
		System.Assert(ors == null);
		ors = new OppRollupSettings__c();
		ors.opp_name_format__c = '[rectype] [payer] [yyyy]';
		insert ors;
				 
		Contact con = new Contact (
			FirstName='Joe',
			LastName='Johanssen_for_tests'			
		);
		insert con;   
		
		ID rectypeIdOpp =  GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		System.Assert(rectypeIdOpp != null); 
		
		Opportunity opp = new Opportunity(
			RecordTypeId = rectypeIdOpp,
			amount = 100,
			CR_Contact_Id__c = con.id,
			CloseDate = date.valueof('2011-01-01')
		);
		insert opp;
		
		opp = [select Id, Name from Opportunity where Id = :opp.id];
		System.AssertEquals('Gift Joe Johanssen_for_tests 2011', opp.Name);
		
		Account acc = new Account(Name='Acme Cartoon Parts');
		insert acc;
		
		Opportunity opp2 = new Opportunity(
			RecordTypeId = rectypeIdOpp,
			amount = 100,
			AccountId = acc.Id,
			CloseDate = date.valueof('2011-01-01')
		);
		insert opp2;
		
		opp2 = [select Id, Name from Opportunity where Id = :opp2.id];
		System.AssertEquals('Gift Acme Cartoon Parts 2011', opp2.Name);
	}
		
}