// Written by Dave Manelski, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Dave Manelski
* @date 04/01/2011
* @description batch apex class to convert matched leads and all new contacts, uses ONEN_LeadConversion helper
* class for the conversion but also determines matching criteria for obvious matches and obvious non-matches in the batch execute method, criteria described on that method.
*/
global class GW_BATCH_LeadConversion implements Database.Batchable<SObject>, Schedulable {

    public String query { get; set; }
    public integer batchSize = 20;
    
    // constructors
    public GW_BATCH_LeadConversion(string q) { 
        query = q; 
        lc = new ONEN_LeadConversion(20);
        matchMap = new map<id,leadMatchup>();
    }
    
    // constructors
    public GW_BATCH_LeadConversion() {}

    /*******************************************************************************************************
	* @description standard scheduleable class constructor, must be global. Calls convertAllLeads() method in this class.  
	* the class implements both the batchable interface as well as the scheduleable interface so that we don't need to create an 
	* extra class just for scheduling.  This batch conversion could be setup to run nightly.
	* @param SC standard scheduleable constructor argument
	*/     
    global void execute(SchedulableContext SC) { 
        GW_BATCH_LeadConversion lcBatch = new GW_BATCH_LeadConversion();
        lcBatch.convertAllLeads(); 
    }

    /*******************************************************************************************************
	* @description standard batch start method, must be global
	* @param bc - Database.BatchableContext - standard batch start method argument
	* @return query my chunk of records from the batch query, to process
	*/ 
    global database.Querylocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);      
    }
    
    // class that represents the set of possible contact/account matches for a given lead
    public class LeadMatchup {
        public Lead theLead;
        public boolean multipleMatches = false;
        public Contact con;     // best contact match
        public Account acct;  // best account match
        public Opportunity opp;  // best opp match
        public string campaignId;   // campaign id of the campaign this lead is in
        
        public LeadMatchup(lead ld) {
            theLead = ld;
        }
    }
    
    ONEN_LeadConversion lc;
    
    // list and map for leads, matches, and conversions
    public lead[] leads;
    public map<id, LeadMatchup> matchMap;
    
    //get individual account id
    Id IndividualAccountId = ONEN_DefaultAccount.getIndividualAccountId();
    //individual account name
    String IndividualAccountName = ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;
    //set the org name not provided default label
    String NotProvidedLabel = ONEN_Constants.NOT_PROVIDED_LABEL;

    /*******************************************************************************************************
	* @description standard batch execute method, must be global.  Pushes leads through a matchleads() method to determine
	* obvious matches and obvious non-matches.  Obvious matches are those leads that match on Contact Id, External Id, or Email + First Name. Obvious 
	* non-matches are when we don't even match on last name. A last name match is left alone for the user to review in manual lead conversion.
	* @param bc - Database.BatchableContext - standard batch execute method argument
	* @param results - list of sobjects - standard batch execute method argument
	*/ 
    global void execute(Database.BatchableContext bc, Sobject[] results) {
        
        // run rollups for this batch       
        leads = new List<Lead>();
        for (sObject obj : results) {
            leads.add((lead)obj);
        }
        //system.debug(lc.leads + 'LEADS TO CONVERT');
        
        matchLeads();
        //system.debug(lc.matchmap + 'LEAD MATCHMAP');
        // set up the list of leads to convert
        ONEN_LeadConversion.convertSpec[] cs = new ONEN_LeadConversion.convertSpec[0];
        
        //create a dupes list so we don't merge to the same contact more than once
        List<LeadMatchup> dupes = new list<LeadMatchup>();
        Set<id> cmatches = new Set<id>();
        
        for (Id l : matchMap.keyset()) {    
                        
            LeadMatchup lm = matchMap.get(l);
            //system.debug('Value of LM ' + lm);
            //system.debug('Contact Matches ' + lm.cons);
            
            if (!lm.multipleMatches) {  
                //create a map to test whether or not duplicate contacts are being
                //added to the map, since we can't perform the ContactFix updates
                //to a list of contacts that contains dupes. 
                if ( lm.con == null || !cmatches.contains(lm.con.id)) {
                    ONEN_LeadConversion.ConvertSpec cs1 = new ONEN_LeadConversion.ConvertSpec();
                    cs1.leadId = lm.theLead.id;
                    cs1.contactId = lm.con == null ? null : lm.con.id;
                    cs1.accountId = (lm.con != null) ? lm.con.AccountId : (lm.theLead.Company==null || lm.theLead.company=='' || lm.theLead.company==NotProvidedLabel || lm.theLead.company==IndividualAccountName) ? IndividualAccountId : (lm.acct == null) ? null : lm.acct.id;
                    cs1.oppId = lm.opp == null ? (lm.theLead.Opportunity_Amount__c == null ? null : 'create_new') : lm.opp.id;
                    cs.add(cs1);
                    if (lm.con != null) cmatches.add(lm.con.id);
                } else {
                    dupes.add(lm);
                }
            }

        }
        //system.debug('Conversion Specs ' + cs);
        //system.debug('Dupes Collection ' + dupes);
        if (cs.size() > 0) lc.convertLeads(cs);          
        
        
        // continue looping through leads matching to duplicate contacts and convert them, one at a time if necessary
        // this may hit governor limits if there are many many leads matching to the same contact
        while (dupes.size() > 0) {
            //system.debug('While loop runnning... ');
            leads = new List<Lead>();
            for (LeadMatchup lm : dupes) {
                leads.add(lm.theLead);
            }
            
            matchLeads();
            
            cs = new ONEN_LeadConversion.convertSpec[0];
            
            cmatches = new Set<id>();
            List<LeadMatchup> additionalDupes = new List<LeadMatchup>();
            
            for (LeadMatchup lm : dupes) {
                //create a map to test whether or not duplicate contacts are being
                //added to the map, since we can't perform the ContactFix updates
                //to a list of contacts that contains dupes. 
                if (lm.con == null || !cmatches.contains(lm.con.id)) {
                    ONEN_LeadConversion.ConvertSpec cs1 = new ONEN_LeadConversion.ConvertSpec();
                    cs1.leadId = lm.theLead.id;
                    cs1.contactId = lm.con == null ? null : lm.con.id;
                    cs1.accountId = (lm.con != null) ? lm.con.AccountId : (lm.theLead.Company==null || lm.theLead.company=='' || lm.theLead.company==NotProvidedLabel || lm.theLead.company==IndividualAccountName) ? IndividualAccountId : (lm.acct == null) ? null : lm.acct.id;
                    cs1.oppId = lm.opp == null ? (lm.theLead.Opportunity_Amount__c == null ? null : 'create_new') : lm.opp.id;
                    cs.add(cs1);
                    if (lm.con != null) cmatches.add(lm.con.id);
                } else {
                    additionalDupes.add(lm);
                }
            }
            
            if (cs.size() > 0) lc.convertLeads(cs);              
            
            //continue to loop through dupes until all have been converted
            dupes =  new List<LeadMatchup>();
            dupes.addAll(additionalDupes);
            
        }
 
    }

    /*******************************************************************************************************
	* @description standard batch finish method, must be global, nothing to see here
	* @param bc - Database.BatchableContext - standard batch finish argument
	*/ 
    global void finish(Database.BatchableContext bc) {
    }
    
    // fill the matchMap with all the possible accounts, contacts, and opps for the entire lead list
    // we may want to make this global virtual in the future, but not yet.
    public void matchLeads() {
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
            string oneEmail = ONEN_LeadConversion.getOneEmail(ld.Email); 
            if (oneEmail != null) {
                emails.add(oneEmail);
            }
            if (ld.company != null) companyNames.add(ld.company);
            if (ld.Contact_Id__c != null) conids.add(ld.Contact_Id__c); 
            if (ld.external_Id__c != null) eids.add(ld.external_Id__c); 
            if (ld.Donation_ID__c != null) oppIds.add(ld.Donation_ID__c);   
        }
        
        //set the SOQL limit size to avoid test failures - "Too Many Rows"
        //if (IsATest) {
        //  limitSize = 100;
        //} else {
        //  limitSize = 500;
        //}
        
        // query for all possible matches
        Map<Id, contact> allcons = new Map<Id, contact>([select Id, Name, FirstName, LastName, AccountId, Account.Name, Email, External_Id__c from Contact 
                                        where External_ID__c in :eids or email in :emails or 
                                        Name in :fullnames or id in :conids
                                        order by lastmodifieddate desc  /* limit :limitSize */ ]);
        allcons.putAll([select Id, Name, FirstName, LastName, AccountId, Account.Name, Email, External_Id__c from Contact 
                                        where External_ID__c in :eids or email in :emails or
                                        (LastName in :lastnames and name not in :fullnames) 
                                        or id in :conids
                                        order by firstname /* limit :(limitSize-allcons.size()+1) */ ]);
        account[] allaccts = [select id, name from account where name in :companyNames order by name];
        opportunity[] allopps = [select id, name, donation_ID__c, amount, closedate, stagename from opportunity where donation_ID__c in :oppids];
        opportunitycontactrole[] allocrs = [select opportunityId, opportunity.Name, contactId, Opportunity.Amount, opportunity.closedate, opportunity.stagename
                                                from opportunitycontactrole 
                                                where  
                                                opportunity.isWon = false and 
                                                contactID in :allcons.keyset() and isPrimary=true
                                                order by opportunity.closedate desc /* limit :limitSize */ ];
        

        // for each lead, walk through the list and map the matches
        for (lead ld : leads) {
            LeadMatchup lm = new LeadMatchup(ld);
            ONEN_LeadConversion.LeadMatchup lclm = new ONEN_LeadConversion.LeadMatchup(ld);
            if (!ld.campaignmembers.isEmpty()) lm.campaignId = ld.campaignmembers[0].campaignid; 
            
            string oneEmail = ONEN_LeadConversion.getOneEmail(ld.email);

            for (contact c : allcons.values()) {
                
                //first look for contact id match and just return that one
                if (ld.Contact_Id__c != null && c.id == ld.Contact_Id__c) {
                    lm.con = c;
                    lclm.cons = new contact[]{c};
                    lm.multipleMatches = false;
                    break;
                }               
                //next look for external id match and just return that one
                if (ld.External_Id__c != null && c.External_Id__c == ld.External_Id__c) {
                    lm.con = c;
                    lclm.cons = new contact[]{c};
                    lm.multipleMatches = false;
                    break;
                }
                //next try first name & email
                if ((oneEmail != null && c.email == oneEmail) && 
                    (ld.FirstName != null && c.FirstName == ld.FirstName)) {
                    lm.con = c;
                    lclm.cons = new contact[]{c};
                    lm.multipleMatches = false;
                    break;
                }
                //next try email
                if ((oneEmail != null && c.email == oneEmail) ||
                    (c.lastname == ld.lastname)) {
                    lm.multipleMatches = true; 
                }
            }
            // look for company name matches
            for (account a : allaccts) {
                if (a.name == ld.company) {
                    lm.acct = a;
                }
            }
            
            // look for a matching donation ID
            for (opportunity o : allopps) {
                if (o.donation_ID__c == ld.donation_ID__c) {
                    o.description = 'id';
                    lm.opp = o;
                    lclm.opps = new opportunity[]{o};
                    break;
                }
            }
            
            // now look through opps with roles - unless the lead already matches by ID or unless you found no contacts at all 
            if (lm.opp == null && lm.con != null) {
                for (opportunitycontactrole ocr : allocrs) {
                    // if amount matches, look for this contactid in the contact matches for this lead
                    
                    if (ocr.opportunity.amount == ld.opportunity_amount__c) {
                        if (lm.con.id == ocr.contactid) {
                            opportunity o = new opportunity(
                                id=ocr.opportunityid, 
                                name=ocr.opportunity.name,
                                amount=ocr.opportunity.amount, 
                                closedate=ocr.opportunity.closedate, 
                                stagename=ocr.opportunity.stagename
                            );
                            lm.opp = o;
                            lclm.opps = new opportunity[]{o};
                            break;
                        }
                    }                   
                }
            }
            matchMap.put(ld.Id, lm);
            lc.matchMap.put(ld.id,lclm);        
        }
        
    }
    
    public void convertAllLeads() {
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        string querySOQL;
        querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (string fieldname : leadFieldMap.keyset()) {
            querySOQL += fieldname + ', ';
        }
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE isConverted = false';
        querySOQL += ' ORDER BY createddate ';
        if (Test.isRunningTest()) querySOQL += 'limit 200';     
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch, batchSize);
    }
    
    public void convertAllLeadsByLeadSource(string LeadSource) {
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        string querySOQL;
        querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (string fieldname : leadFieldMap.keyset()) {
            querySOQL += fieldname + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE leadSource=\'' + LeadSource + '\' AND isConverted = false'; 
        querySOQL += ' ORDER BY createddate '; 
        if (Test.isRunningTest()) querySOQL += 'limit 200';     
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch, batchSize);
    }
    
    /******************  TESTS *********************/
    
    public static testMethod void testAllBatch() {
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion();
        batch.convertAllLeads();
    }
    
    public static testMethod void testLeadSourceBatch() {
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion();
        batch.convertAllLeadsByLeadSource('Web');
    }
    
    public static testMethod void threeLeadsToOneContact() {
        
        Contact con = new Contact(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Email = 'fred@flinstone.com'
        );
        insert con;
        
        Lead ld1 = new Lead(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Email = 'fred@flinstone.com',
            Company = ONEN_Constants.NOT_PROVIDED_LABEL
        );
        insert ld1;
     
        Lead ld2 = new Lead(
            FirstName = 'Fred',
            LastName = 'Rubble_for_tests',
            Email = 'fred@flinstone.com',
            Company = 'Rock_Boulder_Industries'
        );
        insert ld2;
        
        Lead ld3 = new Lead(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Email = 'fred@flinstone.com',
            Company = 'Rock_Boulder_Industries'
        );
        insert ld3;
        
        //describe call to get lead fields for dynamic SOQL
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        
        String querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (Schema.SObjectField sf : leadFieldMap.values()) {
            // since we are in a managed package, we need to get the apex name.
            Schema.DescribeFieldResult f = sf.getDescribe();            
            querySOQL += f.getName() + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id IN (\'' + ld1.id + '\',\'' + ld2.id + '\',\'' + ld3.id + '\')';
        querySOQL += ' ORDER BY createddate';   
        //system.debug ('query string: ' + querySOQL);
        
        test.startTest();
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch);
        test.stopTest(); 
        
        List<lead> convertedLeads = [SELECT id FROM lead WHERE (LastName = 'Flinstone_for_tests' or LastName = 'Rubble_for_tests') AND isConverted = true];
        //system.debug('Converted Leads ' + convertedLeads);
        //Wilma should not get converted because she has a last name match only
        system.AssertEquals(3, convertedLeads.size());
        
        //make sure the last name didn't get changed as a result of the conversion
        List<Contact> cons = [SELECT FirstName, LastName, Email FROM Contact WHERE id = :con.id];
        system.AssertEquals('Flinstone_for_tests', cons[0].LastName);
    }
    
    public static testMethod void idMatch() {
        
        Contact con = new Contact(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            External_Id__c = 'XOXOXOXOXO' 
        );
        insert con;
        
        Lead ld1 = new Lead(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Company = ONEN_Constants.NOT_PROVIDED_LABEL,
            External_Id__c = 'XOXOXOXOXO'
        );
        insert ld1;
        
        //describe call to get lead fields for dynamic SOQL
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        
        String querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (Schema.SObjectField sf : leadFieldMap.values()) {
            // since we are in a managed package, we need to get the apex name.
            Schema.DescribeFieldResult f = sf.getDescribe();            
            querySOQL += f.getName() + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id IN (\'' + ld1.id + '\')';
        querySOQL += ' ORDER BY createddate';   
        //system.debug ('query string: ' + querySOQL);
        
        test.startTest();
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch);
        test.stopTest(); 
        
        List<lead> convertedLeads = [SELECT id FROM lead WHERE (LastName = 'Flinstone_for_tests' ) AND isConverted = true];
        //system.debug('Converted Leads ' + convertedLeads);
        //Wilma should not get converted because she has a last name match only
        system.AssertEquals(1, convertedLeads.size());
    }
    
    public static testMethod void noSubstantiveMatch() {
        
        Contact con = new Contact(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Email = 'fred@flinstone.com',
            External_Id__c = 'XOXOXOXOXO' 
        );
        insert con;
        
        //shouldn't match on name alone
        Lead ld1 = new Lead(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Company = ONEN_Constants.NOT_PROVIDED_LABEL
        );
        insert ld1;
        
        //shouldn't match on email alone
        Lead ld2 = new Lead(
            FirstName = 'Barney',
            LastName = 'Rubble_for_tests',
            Email = 'fred@flinstone.com',
            Company = ONEN_Constants.NOT_PROVIDED_LABEL
        );
        insert ld2;
        
        //describe call to get lead fields for dynamic SOQL
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        
        String querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (Schema.SObjectField sf : leadFieldMap.values()) {
            // since we are in a managed package, we need to get the apex name.
            Schema.DescribeFieldResult f = sf.getDescribe();            
            querySOQL += f.getName() + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id IN (\'' + ld1.id + '\',\'' + ld2.id + '\')';
        querySOQL += ' ORDER BY createddate';   
        //system.debug ('query string: ' + querySOQL);
        
        test.startTest();
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch);
        test.stopTest(); 
        
        List<lead> convertedLeads = [SELECT id FROM lead WHERE (LastName = 'Flinstone_for_tests' or LastName = 'Rubble_for_tests') AND isConverted = true];
        //system.debug('Converted Leads ' + convertedLeads);
        //nobody should have gotten converted because we did have adequate matching criteria
        system.AssertEquals(0, convertedLeads.size());
    }
    
    public static testMethod void newConAndOppFromLead() {
        
        //create a new lead with an opportunity amount
        Lead ld1 = new Lead(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Email = 'fred@flinstone.com',
            Opportunity_Amount__c = 100,
            Company = 'Rock_Boulder_Industries'
        );
        insert ld1;
        
        //describe call to get lead fields for dynamic SOQL
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        
        String querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (Schema.SObjectField sf : leadFieldMap.values()) {
            // since we are in a managed package, we need to get the apex name.
            Schema.DescribeFieldResult f = sf.getDescribe();            
            querySOQL += f.getName() + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id IN (\'' + ld1.id + '\')';
        querySOQL += ' ORDER BY createddate';   
        //system.debug ('query string: ' + querySOQL);
        
        test.startTest();
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch);
        test.stopTest(); 
        
        List<lead> convertedLeads = [SELECT id FROM lead WHERE (LastName = 'Flinstone_for_tests' ) AND isConverted = true];
        //system.debug('Converted Leads ' + convertedLeads);
        //Wilma should not get converted because she has a last name match only
        system.AssertEquals(1, convertedLeads.size());
        
        //make sure the last name didn't get changed as a result of the conversion
        List<Contact> cons = [SELECT FirstName, LastName, Email, Account.Name FROM Contact WHERE LastName = 'Flinstone_for_tests'];
        system.AssertEquals('Flinstone_for_tests', cons[0].LastName);
        system.AssertEquals('Fred', cons[0].FirstName);
        system.AssertEquals('fred@flinstone.com', cons[0].Email);
        system.AssertEquals('Rock_Boulder_Industries', cons[0].Account.Name);
        
        //see if the opp we expected got created
        List<OpportunityContactRole> ocrs = [SELECT Opportunity.Amount FROM OpportunityContactRole WHERE ContactId =:cons[0].id];
        system.AssertEquals(100, ocrs[0].Opportunity.Amount);
        
        //make sure the last name didn't get changed as a result of the conversion
        List<Contact> cons1 = [SELECT FirstName, LastName, Email FROM Contact WHERE LastName = 'Flinstone_for_tests'];
        system.AssertEquals('Flinstone_for_tests', cons1[0].LastName);
        system.AssertEquals(1, cons.size());
    }
    
    public static testMethod void leadMatchedToOpp() {
        
        Contact con = new Contact(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            External_Id__c = 'XOXOXOXOXO' 
        );
        insert con;
        
        Opportunity opp = new Opportunity(
            Name = 'Freds Pending Gift',
            RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT),
            CloseDate = system.today()+20,
            Amount = 100,
            StageName = 'Prospecting',
            ContactId__c = con.id,
            CR_Contact_Id__c = con.id,
            CR_Contact_role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
        );
        insert opp;
        
        Lead ld1 = new Lead(
            FirstName = 'Fred',
            LastName = 'Flinstone_for_tests',
            Company = ONEN_Constants.NOT_PROVIDED_LABEL,
            Opportunity_Amount__c = 100,
            Contact_Id__c = con.id
        );
        insert ld1;
        
        //describe call to get lead fields for dynamic SOQL
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        
        String querySOQL = 'SELECT ';
        querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (Schema.SObjectField sf : leadFieldMap.values()) {
            // since we are in a managed package, we need to get the apex name.
            Schema.DescribeFieldResult f = sf.getDescribe();            
            querySOQL += f.getName() + ', ';
        }
        
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id IN (\'' + ld1.id + '\')';
        querySOQL += ' ORDER BY createddate';   
        
        test.startTest();
        GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
        id batchProcessId = database.executeBatch(batch);
        test.stopTest(); 
        
        List<Opportunity> opps = [SELECT isWon FROM Opportunity WHERE ContactId__c = :con.id];
        //check to see that opp got matched and marked as won
        system.AssertEquals(true, opps[0].isWon); 
    }
}