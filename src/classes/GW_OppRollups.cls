public without sharing class GW_OppRollups {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class calculates opportunity totals on accounts, contacts, and households.
*-----------------------------------------------------------------------------------------------*/

    // settings
    boolean triggerRollupEnabled = true; 
    boolean defaultAcctRollupEnabled = false; 
    boolean useFiscalYear = false;
    set<id> recordTypesToExcludeAccts = new set<id>();
    set<id> recordTypesToExcludeCons = new set<id>();
    set<id> mbrRecordTypes = new set<id>(); 
    set<string> oppTypesToExcludeAccts = new set<string>();
    set<string> oppTypesToExcludeCons = new set<string>();  
    
    // set this to limit contact totals to opps with a specific 'bucket' account
    final string defaultAccountId = ONEN_DefaultAccount.getIndividualAccountId();

    // the current year for use in annual rollups
    static integer thisYear;
    
    //multi-currency variables
    static boolean multiCurrency;
    static SObjectField cfOppty;
    static SObjectField cfAccount;
    static SObjectField cfHousehold;
    static SObjectField cfContact;
    //exchange rate map
    static map<string, decimal> exchangeRates = new map<string,decimal>();
    //corporate currency
    static string currCorporate;

    // need to work slightly differently in tests, and allow different settings
    static public boolean isTest = false;
    static OppRollupSettings__c rollupSettingsForTest = 
        new OppRollupSettings__c( 
            Enable_Opp_Rollup_Triggers__c = true,
            Excluded_Contact_Opp_Types__c = 'In Kind',
            Membership_Record_Types__c = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS
        );
            
    private final static string ACCOUNT_ROLLUP_FIELDS = 'TotalOppAmount__c,AverageAmount__c,SmallestAmount__c,LargestAmount__c,FirstCloseDate__c,LastCloseDate__c,'
        + 'NumberOfClosedOpps__c,OppAmountThisYear__c,OppsClosedThisYear__c,OppAmountLastYear__c,OppsClosedLastYear__c,OppsClosed2YearsAgo__c,OppAmount2YearsAgo__c,'
        + 'OppsClosedLastNDays__c,OppAmountLastNDays__c,TotalMembershipOppAmount__c,NumberOfMembershipOpps__c,LastMembershipDate__c,LastMembershipAmount__c,'
        + 'LastMembershipLevel__c,LastMembershipOrigin__c,MembershipJoinDate__c,MembershipEndDate__c,LastOppAmount__c'
        + (isMultiCurrency() ? ',CurrencyIsoCode' : ''); 
    private final static string CON_ROLLUP_FIELDS = 'TotalOppAmount__c,AverageAmount__c,SmallestAmount__c,LargestAmount__c,FirstCloseDate__c,LastCloseDate__c,NumberOfClosedOpps__c,'
        + 'OppAmountThisYear__c,OppsClosedThisYear__c,OppAmountLastYear__c,OppsClosedLastYear__c,OppsClosed2YearsAgo__c,OppAmount2YearsAgo__c,OppsClosedLastNDays__c,'
        + 'OppAmountLastNDays__c,TotalMembershipOppAmount__c,NumberOfMembershipOpps__c,LastMembershipDate__c,LastMembershipAmount__c,LastMembershipLevel__c,LastMembershipOrigin__c,'
        + 'MembershipJoinDate__c,MembershipEndDate__c,LastOppAmount__c,Best_Gift_Year__c,Best_Gift_Year_Total__c'
        + (isMultiCurrency() ? ',CurrencyIsoCode' : '');
    private final static string CON_ROLLUP_FIELDS_FROM_CONROLE = 'Contact.' + CON_ROLLUP_FIELDS.replace(',' , ',Contact.');    // add relationship name to field list so can use in conrole query
    private final static string HH_ROLLUP_FIELDS = 'TotalOppAmount__c,AverageAmount__c,SmallestAmount__c,LargestAmount__c,FirstCloseDate__c,LastCloseDate__c,NumberOfClosedOpps__c,'
        + 'OppAmountThisYear__c,OppsClosedThisYear__c,OppAmountLastYear__c,OppsClosedLastYear__c,OppsClosed2YearsAgo__c,OppAmount2YearsAgo__c,OppsClosedLastNDays__c,'
        + 'OppAmountLastNDays__c,TotalMembershipOppAmount__c,NumberOfMembershipOpps__c,LastMembershipDate__c,LastMembershipAmount__c,LastMembershipLevel__c,LastMembershipOrigin__c,'
        + 'MembershipJoinDate__c,MembershipEndDate__c,LastOppAmount__c,Best_Gift_Year__c,Best_Gift_Year_Total__c'
        + (isMultiCurrency() ? ',CurrencyIsoCode' : '');  
    private final static string HH_ROLLUP_FIELDS_FROM_CON = 'ONEN_Household__r.' + HH_ROLLUP_FIELDS.replace(',' , ',ONEN_Household__r.');
    private final static string HH_ROLLUP_FIELDS_FROM_CONROLE = 'Contact.ONEN_Household__r.' + HH_ROLLUP_FIELDS.replace(',' , ',Contact.ONEN_Household__r.');
    private final static string CON_RECURRING_ROLLUP_FIELDS = 'Recurring_Amount__c,Recurring_Payment_Frequency__c,Recurring_Payment_Period__c';
    private final static string CON_RECURRING_ROLLUP_FIELDS_FROM_RPP = 'Contact__r.' + CON_RECURRING_ROLLUP_FIELDS.replace(',' , ',Contact__r.'); //add relationship name to use in SOQL of RPPs
    private static map<string,string> ConFieldtypeMap;
    private static map<string,string> AcctFieldtypeMap;
    private static map<string,string> HHFieldtypeMap;
    

    // constructor
    public GW_OppRollups() {

        // load settings
        OppRollupSettings__c rollupSettings = 
            isTest ? rollupSettingsForTest : OppRollupSettings__c.getInstance();

        if (rollupSettings != null) {
            if (rollupSettings.Excluded_Contact_Opp_Rectypes__c != null) {
                set<string> rtNamesToExclude = new set<string>(rollupSettings.Excluded_Contact_Opp_Rectypes__c.split(';'));
                recordTypesToExcludeCons = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);
            }
            if (rollupSettings.Excluded_Account_Opp_Rectypes__c != null) {
                set<string> rtNamesToExclude = new set<string>(rollupSettings.Excluded_Account_Opp_Rectypes__c.split(';'));
                recordTypesToExcludeAccts = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);
            }
            if (rollupSettings.Excluded_Contact_Opp_Types__c != null) {
                oppTypesToExcludeCons = new set<string>(rollupSettings.Excluded_Contact_Opp_Types__c.split(';'));
            }
            if (rollupSettings.Excluded_Account_Opp_Types__c != null) {
                oppTypesToExcludeAccts = new set<string>(rollupSettings.Excluded_Account_Opp_Types__c.split(';'));
            }
            if (rollupSettings.Membership_Record_Types__c != null) {
                set<string> mbrRecordTypeNames = new set<string>(rollupSettings.Membership_Record_Types__c.split(';'));
                mbrRecordTypes = GW_RecTypes.GetRecordTypeIdSet('Opportunity', mbrRecordTypeNames);
            }
            if (rollupSettings.Enable_Opp_Rollup_Triggers__c == false)
                triggerRollupEnabled = false;
            if (rollupSettings.Roll_Up_Opps_for_Default_Account__c == true)
                defaultAcctRollupEnabled = true;
            useFiscalYear = !rollupSettings.assume_fiscal_year_starts_january__c; 
            
        }

        thisYear = system.today().year();
        // the "current" year might actually be named for last year
        // first check if we can short-circuit this based on the setting
        if (useFiscalYear) { 
            
            organization o = [select fiscalYearStartMonth from organization limit 1];
            if (o.FiscalYearStartMonth > system.today().month())
                thisYear--;
                
        }
    }           

    public void rollupAccount( id aid ) {
    // roll up a single account's opps
        
        string soql = 'select id,' + ACCOUNT_ROLLUP_FIELDS + ' FROM Account WHERE Id = :aid';
        account[] accts = Database.query(soql);
        map<id, account> amap = new map<id, account>(accts);    
        
        if (!amap.isEmpty()) 
            rollupAccounts( amap );
    }

    @future
    public static void rollupAccountsFuture( set<id> acctIds ) {
    // roll up a single account's opps
        
        if (acctIds != null && !acctIds.isEmpty()) { 
            string soql = 'select Id,' + ACCOUNT_ROLLUP_FIELDS + ' FROM Account WHERE Id IN :acctIds';
            account[] accts = Database.query(soql);
            map<id, account> amap = new map<id, account>(accts);    
            
            GW_OppRollups rg = new GW_OppRollups();
            rg.rollupAccounts( amap );
        }
    }

    public void rollupAccounts( list<account> accts ) {
    // roll up opps for a set of accounts

        if (accts != null && !accts.isEmpty()) {
            rollupAccounts( new map<id, account>(accts) );
        }
    }

    public void rollupAccounts( map<id, account> amap ) {
    // roll up opps for a map of accounts
    // only accounts that have changed will get updated 

        //system.debug (LoggingLevel.WARN,'amap: ' + amap);
		
		//arg used by multi currency for rollup field currencies
        map<Id,Opportunity> opptyCurrencies;
		
        set<id> allAccts = amap.keyset();
        map<id, Account> accountsToUpdate = new map<id, Account>();

        string[] rollupFields = ACCOUNT_ROLLUP_FIELDS.split(',');
        if ( acctFieldtypeMap==null) acctFieldtypeMap = doFieldDescribe('Account');
        for (id aid : allAccts) {
            Account newAcct = new Account (id=aid);
            putNoOppDefaults(rollupFields,newAcct,acctFieldtypeMap);
            accountsToUpdate.put(aid,newAcct);
            if(isMultiCurrency())
                accountsToUpdate.get(aid).put(cfAccount,amap.get(aid).get(cfAccount));
        }

        // exclude the individual account unless the option to roll it up is checked
        if (allAccts.contains(defaultAccountId) && !defaultAcctRollupEnabled)
            allAccts.remove(defaultAccountId);

        // copy all the rollups from each result row into the account objects
        integer startYear = thisYear - 2;
        
        string soqlQuery = '';
        soqlQuery += 'SELECT accountId, Fiscal_Year(CloseDate) CalendarYr,'; 
        soqlQuery += 'SUM(Amount) TotalOppAmount, AVG(Amount) AverageAmount, MIN(Amount) SmallestAmount,';
        soqlQuery += 'MAX(Amount) LargestAmount, MIN(CloseDate) FirstCloseDate, MAX(CloseDate) LastCloseDate,';
        soqlQuery += 'COUNT_DISTINCT(Id) NumberOfClosedOpps, MAX(CombinedRollupFieldset__c) RollupFieldset ';
        soqlQuery += 'FROM Opportunity ';
        soqlQuery += 'WHERE isWon=true ';
        soqlQuery += 'AND (Amount != 0 AND Amount != null) ';
        soqlQuery += 'AND RecordTypeId NOT IN : recordTypesToExcludeAccts ';
        soqlQuery += 'AND Type NOT IN : oppTypesToExcludeAccts ';
        soqlQuery += 'AND accountId IN : allAccts ';
    	soqlQuery += 'GROUP BY ROLLUP (accountId, Fiscal_Year(closeDate)) ';
    	soqlQuery += 'HAVING ( Fiscal_Year(closeDate) = null OR Fiscal_Year(closeDate) >= : startYear ) ';
        soqlQuery += 'AND accountId != null';

		if (!useFiscalYear) 
			soqlQuery = soqlQuery.replace('Fiscal_Year','Calendar_Year');
        
        list<sobject> objectList = Database.query(soqlQuery);
        // invokes code to get the currency of associated opportunities
        opptyCurrencies = (isMultiCurrency() ? rcfFindCurrency(objectList) : null);
                
        for (sobject r : objectList ) {
            //system.debug(Logginglevel.WARN, 'ROLLUP ROW: ' + r);

            // get the account id for this result row
            id aid = (id)(r.get('accountId'));
    
            // copy all the rollups from this result row into the account object    
            updateRollupFromResult((sobject)(accountsToUpdate.get(aid)), r, opptyCurrencies);
        }

        // also do rollups for last N days
        for (sobject r : 
            [SELECT accountId, 
                SUM(Amount) TotalOppAmount, COUNT_DISTINCT(Id) NumberOfClosedOpps
                FROM Opportunity 
                WHERE isWon=true 
                AND (Amount != 0 AND Amount != null)  
                AND RecordTypeId NOT IN : recordTypesToExcludeAccts
                AND Type NOT IN : oppTypesToExcludeAccts
                AND accountId IN : allAccts
                AND closeDate >= LAST_N_DAYS:365
                GROUP BY accountId
                HAVING accountId != null ] ) {
            //system.debug(Logginglevel.WARN, 'ROLLUP ROW: ' + r);
            
            // get the ids
            id aid = (id)(r.get('accountId'));
                
            // process the result row, copying it into the contact record(s)
            updateRollupFromResultLastNDays((sobject)(accountsToUpdate.get(aid)), r);
        }

        if (!mbrRecordTypes.isEmpty()) {
            // also roll up memberships
            // uncomment if you are doing annual membership totals
            
            soqlQuery = 'SELECT accountId,';
            //soqlQuery +=  'Fiscal_Year(CloseDate) CalendarYr,';
            soqlQuery += 'SUM(Amount) TotalOppAmount,'; 
            //soqlQuery += 'MAX(Amount) LargestAmount,'; 
            //soqlQuery += 'AVG(Amount) AverageAmount, MIN(Amount) SmallestAmount,';
            soqlQuery += 'MAX(CloseDate) LastCloseDate,';
            soqlQuery += 'MIN(membership_start_date__c) FirstStartDate, MAX(membership_end_date__c) LastEndDate,'; 
            soqlQuery += 'COUNT_DISTINCT(Id) NumberOfClosedOpps, MAX(CombinedRollupFieldset__c) RollupFieldset ';
            soqlQuery += 'FROM Opportunity ';
            soqlQuery += 'WHERE isWon=true ';
            //soqlQuery += 'AND (Amount > 0 OR Amount < 0) ';
            soqlQuery += 'AND RecordTypeId IN : mbrRecordTypes ';
            soqlQuery += 'AND Type NOT IN : oppTypesToExcludeAccts ';
            soqlQuery += 'AND accountId IN : allAccts ';
            soqlQuery += 'GROUP BY ROLLUP (accountId, Fiscal_Year(closeDate)) ';
            soqlQuery += 'HAVING ';
            //soqlQuery += '( Fiscal_Year(closeDate) = null OR Fiscal_Year(closeDate) >= : startYear ) AND';
            soqlQuery += 'accountId != null';

			if (!useFiscalYear) 
				soqlQuery = soqlQuery.replace('Fiscal_Year','Calendar_Year');
            
            objectList.clear();
        	objectList = Database.query(soqlQuery);
                    
            // invokes code to get the currency of GWBase__CombinedRollupFieldset__c oppty
            opptyCurrencies = (isMultiCurrency() ? rcfFindCurrency(objectList) : null);
            
            for (sobject r : objectList ) {
                //system.debug('ROLLUP ROW: ' + r);
    
                // get the account id for this result row
                id aid = (id)(r.get('accountId'));
        
                // copy all the rollups from this result row into the account object    
                updateRollupFromResultMembership((sobject)(accountsToUpdate.get(aid)), r, opptyCurrencies);
            }
        }

        // remove any records that have not changed
        for (id aid : allAccts) {
            account a1 = amap.get(aid);
            account a2 = accountsToUpdate.get(aid);
            // if (a1==a2) accountsToUpdate.remove(aid);        // this doesn't work ,do field-by-field comparison instead
            boolean nochange = true;
            for (string field : rollupFields) {
//              system.debug (LoggingLevel.WARN , 'checking acct field diff for : ' + field + ' :' + a1.get(field) + 'vs. ' + a2.get(field));
                if (a1.get(field)!=a2.get(field)) {
                    nochange = false;
//                  system.debug (LoggingLevel.WARN , 'acct field diff found: ' + a1.get(field) + 'vs. ' + a2.get(field));
                    break;
                }
                
            }
            if (nochange) accountsToUpdate.remove(aid);
        }
        
        // update all the accounts from this batch 
        update accountsToUpdate.values();
    }

    public void rollupContact( id cid ) {
        // roll up opps for one contact
        string soql = 'select Id,' + CON_ROLLUP_FIELDS + ' FROM Contact WHERE Id = :cid';
        contact[] cc = Database.query(soql);
    
        map<id, contact> cmap = new map<id, contact>(cc);   
        
        if (!cmap.isEmpty()) 
            rollupContacts( cmap );
    }

    public void rollupHousehold( id hhid ) {
        // roll up opps for one household
        string soql = 'select Id,' + HH_ROLLUP_FIELDS + ' FROM ONEN_Household__c WHERE Id = :hhid';
        ONEN_Household__c[] hhs = Database.query(soql);     
        map<id, ONEN_Household__c> hhmap = new map<id, ONEN_Household__c>(hhs); 
        
        if (!hhmap.isEmpty()) 
            rollupHouseholds( hhmap );
    }
    
    public void rollupHouseholds( list<onen_household__c> hhs ) {
    // roll up opps for a set of accounts

        if (hhs != null && !hhs.isEmpty()) {
            rollupHouseholds( new map<id, onen_household__c>(hhs) );
        }
    }   

    public void rollupHouseholds( map<id, onen_household__c> hhmap ) {
    // roll up opps for households
        
        //system.debug (LoggingLevel.WARN,'hhmap: ' + hhmap);
		
		//arg used by multi currency for rollup field currencies
        map<Id,Opportunity> opptyCurrencies;
		
        set<id> hhids = hhmap.keyset();
        map<id, ONEN_Household__c> householdsToUpdate = new map<id, ONEN_Household__c>();

        string[] rollupFields = HH_ROLLUP_FIELDS.split(',');
        if ( HHFieldtypeMap==null) HHFieldtypeMap = doFieldDescribe('ONEN_Household__c');
        for (id hhid : hhids) {
            ONEN_Household__c newHH = new ONEN_Household__c (id=hhid);
            putNoOppDefaults(rollupFields,newHH,HHFieldtypeMap);
            householdsToUpdate.put(hhid,newHH);
            if(isMultiCurrency())
                householdsToUpdate.get(hhid).put(cfHousehold,hhmap.get(hhid).get(cfHousehold));
        }
        
        string soqlQuery = '';
        soqlQuery += 'SELECT contact.ONEN_household__c hhid,';
        soqlQuery += 'Fiscal_Year(Opportunity.CloseDate) CalendarYr, SUM(Opportunity.Amount) TotalOppAmount,';
        soqlQuery += 'AVG(Opportunity.Amount) AverageAmount, MIN(Opportunity.Amount) SmallestAmount,';
        soqlQuery += 'MAX(Opportunity.Amount) LargestAmount, MIN(Opportunity.CloseDate) FirstCloseDate,';
        soqlQuery += 'MAX(Opportunity.CloseDate) LastCloseDate, COUNT_DISTINCT(Opportunity.Id) NumberOfClosedOpps,';
        soqlQuery += 'MAX(Opportunity.CombinedRollupFieldset__c) RollupFieldset ';
        soqlQuery += 'FROM OpportunityContactRole ';
        soqlQuery += 'WHERE isPrimary=true AND opportunity.isWon=true ';
        soqlQuery += 'AND (Opportunity.Amount != 0 AND Opportunity.Amount != null) ';
        soqlQuery += 'AND Opportunity.RecordTypeId NOT IN : recordTypesToExcludeCons ';
        soqlQuery += 'AND Opportunity.Type NOT IN : oppTypesToExcludeCons ';
        soqlQuery += 'AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null) ';
        soqlQuery += 'AND contact.ONEN_household__c IN : hhIds ';
        soqlQuery += 'GROUP BY ROLLUP(contact.ONEN_household__c, Fiscal_Year(opportunity.closeDate)) ';
        soqlQuery += 'HAVING ';
        // soqlQuery += '(Fiscal_Year(opportunity.closeDate) = null ';
        // soqlQuery += 'OR Fiscal_Year(opportunity.closeDate) >= : startYear ) AND '; 
        soqlQuery += 'contact.ONEN_household__c != null';

		if (!useFiscalYear) 
			soqlQuery = soqlQuery.replace('Fiscal_Year','Calendar_Year');
        
        list<sobject> objectList = Database.query(soqlQuery);
        
        // invokes code to get the currency of associated opportunities
        opptyCurrencies = (isMultiCurrency() ? rcfFindCurrency(objectList) : null);

        // copy all the rollups from each result row into the household objects
        integer startYear = thisYear - 2;
        for (sobject r : objectList ) {
            //system.debug(Logginglevel.WARN, 'ROLLUP ROW: ' + r);

            // get the household id for this result row
            id hhid = (id)(r.get('hhid'));
            // process the result row, copying it into the contact record(s)
            // MS: we only want to fully calc the row if it is from the last few years - older years are only for calcing Best Year for contacts
            integer yr = (integer)r.get('CalendarYr');
            if (hhid != null) { 
                // household row
                if ( yr >= startYear || yr==null) {
                    updateRollupFromResult((sobject)(householdsToUpdate.get(hhid)), r, opptyCurrencies);
                }
                // after doing regular processing, calc Best Contact Year stuff
                // the rows are in year order, so just look start w/ the first yr, and increase as needed as we go
                decimal yrAmt = (decimal)r.get('TotalOppAmount');
                ONEN_Household__c hh = householdsToUpdate.get(hhid);
                if ( (yrAmt > hh.Best_Gift_Year_Total__c || hh.Best_Gift_Year_Total__c==null ) && yr!=null) {
                    hh.Best_Gift_Year_Total__c = yrAmt;
                    hh.Best_Gift_Year__c = yr;
                }
//              system.debug(Logginglevel.WARN, 'con after best yr calc: ' + con);
            }
        }

        // also do rollups for last N days
        for (sobject r : 
            [SELECT contact.ONEN_household__c hhid,  
                SUM(Opportunity.Amount) TotalOppAmount, COUNT_DISTINCT(Opportunity.Id) NumberOfClosedOpps
                FROM OpportunityContactRole 
                WHERE isPrimary=true AND opportunity.isWon=true 
                AND (Opportunity.Amount != 0 AND Opportunity.Amount != null)
                AND Opportunity.RecordTypeId NOT IN : recordTypesToExcludeCons
                AND Opportunity.Type NOT IN : oppTypesToExcludeCons
                AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null)  
                AND contact.ONEN_household__c IN : hhIds
                AND opportunity.closeDate >= LAST_N_DAYS:365
                GROUP BY contact.ONEN_household__c
                HAVING contact.ONEN_household__c != null ] ) {
            //system.debug(Logginglevel.WARN, 'ROLLUP ROW: ' + r);
            
            // get the household id for this result row
            id hhid = (id)(r.get('hhid'));
                
            // process the result row, copying it into the household record(s)
            updateRollupFromResultLastNDays((sobject)(householdsToUpdate.get(hhid)), r);
        }

        if (!mbrRecordTypes.isEmpty()) {
            // also roll up memberships
            // uncomment if you are doing annual membership totals
            
            soqlQuery = 'SELECT contact.ONEN_household__c hhid,';
            soqlQuery += 'SUM(Opportunity.Amount) TotalOppAmount,'; 
            soqlQuery += 'MAX(Opportunity.CloseDate) LastCloseDate,';
            //soqlQuery += 'AVG(Opportunity.Amount) AverageAmount, MIN(Opportunity.Amount) SmallestAmount,';
            //soqlQuery += 'MAX(Opportunity.Amount) LargestAmount,';
            soqlQuery += 'MIN(Opportunity.Membership_Start_Date__c) FirstStartDate,'; 
            soqlQuery += 'MAX(Opportunity.Membership_End_Date__c) LastEndDate,'; 
            soqlQuery += 'COUNT_DISTINCT(Opportunity.Id) NumberOfClosedOpps,';
            soqlQuery += 'MAX(Opportunity.CombinedRollupFieldset__c) RollupFieldset ';
            soqlQuery += 'FROM OpportunityContactRole ';
            soqlQuery += 'WHERE isPrimary=true AND opportunity.isWon=true '; 
            //soqlQuery += ' AND (Opportunity.Amount > 0 OR Opportunity.Amount < 0) '; 
            soqlQuery += 'AND Opportunity.RecordTypeId IN : mbrRecordTypes ';
            soqlQuery += 'AND Opportunity.Type NOT IN : oppTypesToExcludeCons ';
            soqlQuery += 'AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null) ';  
            soqlQuery += 'AND contact.ONEN_household__c IN : hhIds ';
            soqlQuery += 'GROUP BY contact.ONEN_household__c ';
            //soqlQuery += ', Fiscal_Year(opportunity.closeDate) ';
            soqlQuery += 'HAVING '; 
            //soqlQuery += '(Fiscal_Year(opportunity.closeDate) = null '; 
            //soqlQuery += 'OR Fiscal_Year(opportunity.closeDate) >= : startYear ) AND '; 
            soqlQuery += 'contact.ONEN_household__c != null';
            
			if (!useFiscalYear) 
				soqlQuery = soqlQuery.replace('Fiscal_Year','Calendar_Year');

            objectList.clear();
        	objectList = Database.query(soqlQuery);
                
            // invokes code to get the currency of associated opportunities
        	opptyCurrencies = (isMultiCurrency() ? rcfFindCurrency(objectList) : null);
            
            for (sobject r : objectList ) {
                //system.debug('ROLLUP ROW: ' + r);
    
                // get the household id for this result row
                id hhid = (id)(r.get('hhid'));
                
                // process the result row, copying it into the contact record(s)
                updateRollupFromResultMembership((sobject)(householdsToUpdate.get(hhid)), r, opptyCurrencies);
                     
            }
        }

        // remove any records that have not changed
        for (id hhid : hhids) {
            ONEN_Household__c hh1 = hhmap.get(hhid);
            ONEN_Household__c hh2 = householdsToUpdate.get(hhid);
            boolean nochange = true;
            for (string field : rollupFields) {
//              system.debug (LoggingLevel.WARN , 'checking acct field diff for : ' + field + ' :' + hh1.get(field) + 'vs. ' + hh2.get(field));
                if (hh1.get(field)!=hh2.get(field)) {
                    nochange = false;
//                  system.debug (LoggingLevel.WARN , 'househokd field diff found: ' + hh1.get(field) + 'vs. ' + hh2.get(field));
                    break;
                }
                
            }
            if (nochange) householdsToUpdate.remove(hhid);
        }
        
        // update all the accounts from this batch 
        update householdsToUpdate.values();
        
    }
    
    @future
    public static void rollupHouseholdsFuture( set<id> hhIds ) {    
        if (hhIds != null && !hhIds.isEmpty()) {

            // get household contacts
            string soql = 'select Id,' + HH_ROLLUP_FIELDS + ' FROM ONEN_Household__c WHERE id in :hhIds';
            ONEN_Household__c[] hh = Database.query(soql);
            map<id, ONEN_Household__c> hhmap = new map<id, ONEN_Household__c> (hh); 
            
            // roll up totals
            GW_OppRollups rg = new GW_OppRollups();
            rg.rollupHouseholds( hhmap );
        }
    }
    
    @future
    public static void rollupContactsFuture( set<id> conIds ) { 
        if (conIds != null && !conIds.isEmpty()) {

            // get household contacts
            string soql = 'select Id,' + CON_ROLLUP_FIELDS + ' FROM Contact WHERE id in :conIds';
            Contact[] cc = Database.query(soql);
            map<id, Contact> cmap = new map<id, Contact> (cc);  
            
            // roll up totals
            GW_OppRollups rg = new GW_OppRollups();
            rg.rollupContacts( cmap );
        }
    }

    public void rollupContacts( list<contact> cons ) {
    // roll up opps for a set of contacts

        if (cons != null && !cons.isEmpty()) {
            rollupContacts( new map<id, contact>(cons) );
        }
    }   
    
    public void rollupContacts( map<id, contact> cmap ) {
    // roll up opps for a list of contacts
		
		//arg used by multi currency for rollup field currencies
        map<Id,Opportunity> opptyCurrencies;
		
        set<id> conIds = cmap.keySet();

        // copy the contacts to a map of zeroed out versions
        map<id, contact> contactsToUpdate = new map<id, contact>();

        string[] conRollupFields = CON_ROLLUP_FIELDS.split(',');
        if (conFieldtypeMap==null) conFieldtypeMap = doFieldDescribe('Contact');

        for (id cid : conIds) {
            Contact newCon = new Contact(id=cid);
            putNoOppDefaults(conRollupFields,newCon,conFieldtypeMap);
            contactsToUpdate.put(cid,newCon);
            if(isMultiCurrency())
                contactsToUpdate.get(cid).put(cfContact,cmap.get(cid).get(cfContact));
        }
        
//      system.debug (Logginglevel.WARN, 'cmap: ' + cmap);
        
        // copy all the rollups from each result row into the contact objects
        integer startYear = thisYear - 2;
        
        string soqlQuery = '';
        
        soqlQuery += 'SELECT contactId,'; 
        soqlQuery += 'Fiscal_Year(Opportunity.CloseDate) CalendarYr, SUM(Opportunity.Amount) TotalOppAmount,';
        soqlQuery += 'AVG(Opportunity.Amount) AverageAmount, MIN(Opportunity.Amount) SmallestAmount,';
        soqlQuery += 'MAX(Opportunity.Amount) LargestAmount, MIN(Opportunity.CloseDate) FirstCloseDate,';
        soqlQuery += 'MAX(Opportunity.CloseDate) LastCloseDate, COUNT_DISTINCT(Opportunity.Id) NumberOfClosedOpps,';
        soqlQuery += 'MAX(Opportunity.CombinedRollupFieldset__c) RollupFieldset ';
        soqlQuery += 'FROM OpportunityContactRole '; 
        soqlQuery += 'WHERE isPrimary=true AND opportunity.isWon=true ';
        soqlQuery += 'AND (Opportunity.Amount != 0 AND Opportunity.Amount != null) '; 
        soqlQuery += 'AND Opportunity.RecordTypeId NOT IN : recordTypesToExcludeCons ';
        soqlQuery += 'AND Opportunity.Type NOT IN : oppTypesToExcludeCons ';
        soqlQuery += 'AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null) ';  
        soqlQuery += 'AND contactId IN : conIds ';
        soqlQuery += 'GROUP BY ROLLUP(contactId, Fiscal_Year(opportunity.closeDate))';
        
		if (!useFiscalYear) 
			soqlQuery = soqlQuery.replace('Fiscal_Year','Calendar_Year');

        list<sobject> objectList = Database.query(soqlQuery);
        // invokes code to get the currency of associated opportunities
        opptyCurrencies = (isMultiCurrency() ? rcfFindCurrency(objectList) : null);
        
        for (sobject r : objectList ) {
            
//          system.debug(Logginglevel.WARN, 'ROLLUP ROW: ' + r);

            // get the ids
            id cid = (id)(r.get('contactId'));
                
            // process the result row, copying it into the contact record(s)
            // MS: we only want to fully calc the row if it is from the last few years - older years are only for calcing Best Year for contacts
            integer yr = (integer)r.get('CalendarYr');
            if (cid != null) { 
                // contact row
                if ( yr >= startYear || yr==null) {
                    updateRollupFromResult((sobject)(contactsToUpdate.get(cid)), r, opptyCurrencies);
                }
                // after doing regular processing, calc Best Contact Year stuff
                // the rows are in year order, so just look start w/ the first yr, and increase as needed as we go
                decimal yrAmt = (decimal)r.get('TotalOppAmount');
                Contact con = contactsToUpdate.get(cid);
                if ( (yrAmt > con.Best_Gift_Year_Total__c || con.Best_Gift_Year_Total__c==null ) && yr!=null) {
                    con.Best_Gift_Year_Total__c = yrAmt;
                    con.Best_Gift_Year__c = yr;
                }
//              system.debug(Logginglevel.WARN, 'con after best yr calc: ' + con);
            }
        }
            
        // also do rollups for last N days
        for (sobject r : 
            [SELECT contactId, 
                SUM(Opportunity.Amount) TotalOppAmount, COUNT_DISTINCT(Opportunity.Id) NumberOfClosedOpps
                FROM OpportunityContactRole 
                WHERE isPrimary=true AND opportunity.isWon=true 
                AND (Opportunity.Amount != 0 AND Opportunity.Amount != null)
                AND Opportunity.RecordTypeId NOT IN : recordTypesToExcludeCons
                AND Opportunity.Type NOT IN : oppTypesToExcludeCons
                AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null)  
                AND contactid IN : conIds
                AND opportunity.closeDate >= LAST_N_DAYS:365
                GROUP BY contactId] ) {

            //system.debug(Logginglevel.WARN, 'ROLLUP ROW: ' + r);
            
            // get the ids
            id cid = (id)(r.get('contactId'));
                
            // process the result row, copying it into the contact record(s)
            if (cid != null) { 
                // contact row  
                updateRollupFromResultLastNDays((sobject)(contactsToUpdate.get(cid)), r);
            }
        }

        if (!mbrRecordTypes.isEmpty()) {
            // also do rollups for membership
            // if you need annual rollups for membership, uncomment the commented bits
            
            soqlQuery = 'SELECT contactId,';
            //soqlQuery += 'Fiscal_Year(Opportunity.CloseDate) CalendarYr,';
            soqlQuery += 'SUM(Opportunity.Amount) TotalOppAmount,'; 
            soqlQuery += 'MAX(Opportunity.CloseDate) LastCloseDate,'; 
            //soqlQuery += 'AVG(Opportunity.Amount) AverageAmount, MIN(Opportunity.Amount) SmallestAmount,';
            //soqlQuery += 'MAX(Opportunity.Amount) LargestAmount,'; 
            soqlQuery += 'MIN(Opportunity.Membership_Start_Date__c) FirstStartDate,'; 
            soqlQuery += 'MAX(Opportunity.Membership_End_Date__c) LastEndDate,'; 
            soqlQuery += 'COUNT_DISTINCT(Opportunity.Id) NumberOfClosedOpps,';
            soqlQuery += 'MAX(Opportunity.CombinedRollupFieldset__c) RollupFieldset ';
            soqlQuery += 'FROM OpportunityContactRole ';
            soqlQuery += 'WHERE isPrimary=true AND opportunity.isWon=true ';
            //soqlQuery += ' AND (Opportunity.Amount > 0 OR Opportunity.Amount < 0)';
            soqlQuery += 'AND Opportunity.RecordTypeId IN : mbrRecordTypes ';
            soqlQuery += 'AND Opportunity.Type NOT IN : oppTypesToExcludeCons ';
            soqlQuery += 'AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null) ';
            soqlQuery += 'AND contactid IN : conIds ';
            soqlQuery += 'GROUP BY ROLLUP(contactId)';
            //soqlQuery += ', Fiscal_Year(opportunity.closeDate)'; 
            
			if (!useFiscalYear) 
				soqlQuery = soqlQuery.replace('Fiscal_Year','Calendar_Year');

            objectList.clear();
        	objectList = Database.query(soqlQuery);
                
            // invokes code to get the currency of associated opportunities
        	opptyCurrencies = (isMultiCurrency() ? rcfFindCurrency(objectList) : null);
        	
            for (sobject r : objectList ) {
                        
                // get the ids
                id cid = (id)(r.get('contactId'));
                    
                // process the result row, copying it into the contact record(s)
                if (cid != null) { 
                    // contact row  
                    updateRollupFromResultMembership((sobject)(contactsToUpdate.get(cid)), r, opptyCurrencies);
                    // consWithoutMbrOpps.remove(cid);  // this con DOES have opps (mbr opps might be diff rectypes from gift opps)
                }
            }
        }

        // remove (skip updating) any records that have not changed
        for (id cid : conIds) {
            contact c1 = cmap.get(cid);
            contact c2 = contactsToUpdate.get(cid);
            
//          system.debug (Logginglevel.WARN, 'c1:' + c1);
//          system.debug (Logginglevel.WARN, 'c2:' + c2);
//          system.debug (Logginglevel.WARN, 'does c1 equal c2??:' + (c1==c2));
            
            // so instead loop through the fields and see if we find one that's different. 
            boolean nochange = true;
            for (string field : conRollupFields) {
//              system.debug (LoggingLevel.WARN , 'checking con field diff for : ' + field + ' :' + c1.get(field) + 'vs. ' + c2.get(field));
                if (c1.get(field)!=c2.get(field)) {
                    nochange = false;
//                  system.debug (LoggingLevel.WARN , 'con field diff found: ' + c1.get(field) + 'vs. ' + c2.get(field));
                    break;
                }
            }
            if (nochange) contactsToUpdate.remove(cid);
        }

        // update all the contacts from this batch 
        if (!contactsToUpdate.isEmpty()) update contactsToUpdate.values();                          
    }


    private map<string,string> doFieldDescribe (string objName) {
    
        // for contact, account, or HH, make a map of each field in our rollup fieldlists
        // of fieldname to string representing field type
        // this will be used to assign default values
    
        map<string,string> fieldTypeMap = new map<string,string> (); 
        string fields;
        Map<String, Schema.SObjectField> M;
        
        if (objName == 'Contact') {
            fields = CON_ROLLUP_FIELDS + ',' + CON_RECURRING_ROLLUP_FIELDS;
            M = Schema.SObjectType.Contact.fields.getMap();
        } else if (objName == 'Account') {
            fields = ACCOUNT_ROLLUP_FIELDS;
            M = Schema.SObjectType.Account.fields.getMap();
        } else if (objName == 'ONEN_Household__c') {
            fields = HH_ROLLUP_FIELDS;
            M = Schema.SObjectType.ONEN_Household__c.fields.getMap();
        }
        string[] fieldList = fields.split(',');
        
        for (string fieldName : fieldList) {
            Schema.SObjectField fld = M.get(fieldName);
            Schema.DescribeFieldResult R = fld.getDescribe();
            Schema.DisplayType t= R.getType();
            string typeStr = t.name();
            fieldTypeMap.put (fieldName,typeStr);
        }
        
        return fieldTypeMap;
        
    }
    
    private void putNoOppDefaults (string[] fieldlist, sObject obj, Map<string,string> fieldtypemap) {
        for (string fieldName : fieldlist) {
            string fieldType = fieldtypemap.get(fieldName);
            if (fieldType == 'Currency' || fieldType == 'Double' || fieldType == 'Integer') {
                obj.put(fieldname , 0);
            } else {
                obj.put(fieldname , null);
            }                   
        }
    }

	
    public void rollupForOppTrigger( map<id, opportunity> newOpps, map<id, opportunity> oldOpps ) {
    // find contacts and accounts affected and then roll them up

        //system.debug (LoggingLevel.WARN , 'newopps map: ' + newOpps);
        if (triggerRollupEnabled) {

            set<id> modifiedContactOpps = new set<id>();
            set<id> acctsToReroll = new set<id>(); 

            if (newOpps == null) {
    
                // it is a delete
                for (id oid : oldOpps.keySet()) {
                    opportunity o = oldOpps.get(oid);
                    if (o.isWon /* && (o.Amount > 0 || o.Amount < 0) */ ) {
                        
                        if ((o.accountid == defaultAccountId || o.accountid == null) &&
                            (mbrRecordTypes.contains(o.recordTypeId) ||
                                !recordTypesToExcludeCons.contains(o.recordTypeId)) &&
                            (!oppTypesToExcludeCons.contains(o.type))) {
                        
                            modifiedContactOpps.add(o.id);
                        }
                        if (o.accountId != null &&
                            (mbrRecordTypes.contains(o.recordTypeId) ||
                                !recordTypesToExcludeAccts.contains(o.recordTypeId)) &&
                            (!oppTypesToExcludeAccts.contains(o.type))) {
                                
                            acctsToReroll.add(o.accountId);
                        }
                    }
                }
            } else if (oldOpps == null) {
                // for insert, find the closed opps that qualify
                for (id oid : (newOpps.keySet())) {
                    opportunity o = newOpps.get(oid);
                    if (o.isWon /* && (o.Amount > 0 || o.Amount < 0) */ ) {    // don't think we need this clause here, since could be $0 memberships - $0 gift opps will be omitted further on 
                        
                        if ((o.accountid == defaultAccountId || o.accountid == null) &&
                            (mbrRecordTypes.contains(o.recordTypeId) ||
                                !recordTypesToExcludeCons.contains(o.recordTypeId)) &&
                            (!oppTypesToExcludeCons.contains(o.type))) {
                         
                            modifiedContactOpps.add(o.id);
                        }
                        if (o.accountId != null &&
                            (mbrRecordTypes.contains(o.recordTypeId) ||
                                !recordTypesToExcludeAccts.contains(o.recordTypeId)) &&
                            (!oppTypesToExcludeAccts.contains(o.type))) {

                            acctsToReroll.add(o.accountId);
                        }
                    }
                }
                
            } else {
                // for update, find the opps that are changed in any important way
                for (id oid : (newOpps.keySet())) {
                    
                    // compare old and new
                    opportunity o = newOpps.get(oid);
                    opportunity oldOpp = oldOpps.get(oid);

                    // look for opps that have changed in any important way
                    if (o.isWon != oldOpp.isWon || (o.isWon && 
                        ((o.Amount != oldOpp.Amount) ||
                        (o.recordTypeId != oldOpp.recordTypeId) || 
                        (o.type != oldOpp.type) ||
                        (o.closeDate != oldOpp.closeDate) ||
                        (o.Membership_Start_Date__c != oldOpp.Membership_Start_Date__c) ||
                        (o.Membership_End_Date__c != oldOpp.Membership_End_Date__c) ||
                        (o.accountId != oldOpp.accountId)))) {
                            
//                      system.debug (LoggingLevel.WARN, 'opp changed! ' + o);   
    
                        if (o.accountid == defaultAccountId || o.accountid == null)
                            modifiedContactOpps.add(o.id);
                            
                        if (o.accountId != null)
                            acctsToReroll.add(o.accountId);
                    }       
                }           
            }       
            
            // use the contact roles to find the contacts and households
            if (!modifiedContactOpps.isEmpty()) {
                map<id, contact> cmap = new map<id, contact>();
                map<id, onen_household__c> hhmap = new map<id, onen_household__c>();
                
                string soql = 'SELECT ContactId,' + CON_ROLLUP_FIELDS_FROM_CONROLE + ',' + HH_ROLLUP_FIELDS_FROM_CONROLE 
                            + ' FROM OpportunityContactRole WHERE Opportunity.Id IN :modifiedContactOpps AND isPrimary = true ALL ROWS';
//              system.debug (LoggingLevel.WARN , 'soql: ' + soql);
                OpportunityContactRole[] conroles = Database.query(soql);
                system.debug (LoggingLevel.WARN , 'conroles returned: ' + conroles);
                for (OpportunityContactRole r : conroles) {
//                  system.debug (LoggingLevel.WARN , 'contact of conrole: ' + r.contact);
                    cmap.put(r.contactId, r.contact);
                    //only add to the h map if the contact has a HH
                    if (r.Contact.ONEN_Household__c != null) {
                        hhmap.put(r.contact.onen_household__c, r.contact.onen_household__r);
                    }
                }
                    
                if (!cmap.isEmpty()) {
                    // for a single contact with fewer than 200 opps, roll up immediately - otherwise future
                    decimal oppCount = cmap.values()[0].NumberOfClosedOpps__c;
                    if (cmap.size() == 1 && (oppCount == null || oppCount < 200)) {
//                      system.debug(Logginglevel.WARN, 'Rolling up single contact now...');
                        rollupContacts( cmap );
                    } else if ((Limits.getLimitFutureCalls() - Limits.getFutureCalls()) > 5) {
//                      system.debug(Logginglevel.WARN, 'Rolling up as @future..');
                        rollupContactsFuture(cmap.keySet());
                    } else {
//                      system.debug(Logginglevel.WARN, 'Did not roll up because there were too few future calls available.');
                    }
                }
                
                if (!hhmap.isEmpty()) {
                    // for a single contact with fewer than 200 opps, roll up immediately - otherwise future
                    decimal oppCount = hhmap.values()[0].NumberOfClosedOpps__c;
                    if (hhmap.size() == 1 && (oppCount == null || oppCount < 200)) {
//                      system.debug(Logginglevel.WARN, 'Rolling up single contact now...');
                        rollupHouseholds( hhmap );
                    } else if ((Limits.getLimitFutureCalls() - Limits.getFutureCalls()) > 5) {
//                      system.debug(Logginglevel.WARN, 'Rolling up as @future..');
                        rollupHouseholdsFuture(hhmap.keySet());
                    } else {
//                      system.debug(Logginglevel.WARN, 'Did not roll up because there were too few future calls available.');
                    }
                }
            }

            // roll them up
            if (!acctsToReroll.isEmpty()) {
                
                boolean rollupNow = false;
                map<id, account> amap ;
                if (acctsToReroll.size() == 1) {
                    string soql = 'select id,' + ACCOUNT_ROLLUP_FIELDS + ' FROM Account WHERE Id IN :acctsToReroll';
                    account[] accts = Database.query(soql);
                    amap = new map<id, account>(accts);
                    decimal oppCount = amap.values()[0].NumberOfClosedOpps__c;
                    rollupNow = (oppCount == null || oppCount < 200);
                }
                        
                // for a single account with fewer than 200 opps, roll up immediately - otherwise future
                if (rollupNow)
                    rollupAccounts( amap );
                else if ((Limits.getLimitFutureCalls() - Limits.getFutureCalls()) > 5)
                    rollupAccountsFuture( acctsToReroll );
//              else
//                  system.debug(Logginglevel.WARN, 'Did not roll up because there were too few future calls available.');              
            }
        }   
    }
    
    public void rollupRecurring( list<contact> cons ) {
    // roll up opps for a set of contacts

        if (cons != null && !cons.isEmpty()) {
            rollupRecurring( new map<id, contact>(cons) );
        }
    }
    
    public void rollupRecurring( map<id, contact> cmap ) {
    // roll up recurring payment profile info for a list of contacts
		
        set<id> conIds = cmap.keySet();

        // copy the contacts to a map of zeroed out versions
        map<id, contact> contactsToUpdate = new map<id, contact>();

        string[] conRecurringRollupFields = CON_RECURRING_ROLLUP_FIELDS.split(',');
        if (conFieldtypeMap==null) conFieldtypeMap = doFieldDescribe('Contact');

        for (id cid : conIds) {
            Contact newCon = new Contact(id=cid);
            putNoOppDefaults(conRecurringRollupFields,newCon,conFieldtypeMap);
            contactsToUpdate.put(cid,newCon);
        }
        
//      system.debug (Logginglevel.WARN, 'cmap: ' + cmap);
        
        for (Recurring_Payment_Profile__c rpp : [SELECT Contact__c,Payment_Period__c,Frequency__c,Amount__c FROM
        										Recurring_Payment_Profile__c WHERE (End_Date__c > :system.today() OR End_Date__c = null)
        										AND Contact__c IN :conIds] ) {

            //set the fields on the contact record
            contactsToUpdate.get(rpp.Contact__c).Recurring_Amount__c = rpp.Amount__c;
            contactsToUpdate.get(rpp.Contact__c).Recurring_Payment_Frequency__c = rpp.Frequency__c;
            contactsToUpdate.get(rpp.Contact__c).Recurring_Payment_Period__c = rpp.Payment_Period__c;
        }
            
        // remove (skip updating) any records that have not changed
        for (id cid : conIds) {
            contact c1 = cmap.get(cid);
            contact c2 = contactsToUpdate.get(cid);
            
            // so instead loop through the fields and see if we find one that's different. 
            boolean nochange = true;
            for (string field : conRecurringRollupFields) {
//              system.debug (LoggingLevel.WARN , 'checking con field diff for : ' + field + ' :' + c1.get(field) + 'vs. ' + c2.get(field));
                if (c1.get(field)!=c2.get(field)) {
                    nochange = false;
//                  system.debug (LoggingLevel.WARN , 'con field diff found: ' + c1.get(field) + 'vs. ' + c2.get(field));
                    break;
                }
            }
            if (nochange) contactsToUpdate.remove(cid);
        }

        // update all the contacts from this batch 
        if (!contactsToUpdate.isEmpty()) update contactsToUpdate.values();                          
    }
    
    public void rollupForRecurringTrigger( map<id, Recurring_Payment_Profile__c> newProfiles, map<id, Recurring_Payment_Profile__c> oldProfiles ) {
    	
		set<id> modifiedContactRPs = new set<id>();
    	
    	if (newProfiles == null) {
            // it is a delete
            for (id rpid : oldProfiles.keySet()) {
				if (oldProfiles.get(rpid).Contact__c != null) {
					modifiedContactRPs.add(rpid);
				}
            }
        } else {
        	// it is an insert or update
            for (id rpid : newProfiles.keySet()) {
				if (newProfiles.get(rpid).Contact__c != null) {
					modifiedContactRPs.add(rpid);
				}
            }
        }  
        
        if (!modifiedContactRPs.isEmpty()) {
        	
        	map<id, contact> cmap = new map<id, contact>();
        	
        	string soql = 'SELECT Contact__c,' + CON_RECURRING_ROLLUP_FIELDS_FROM_RPP + ' FROM Recurring_Payment_Profile__c '
        				+ 'WHERE id IN :modifiedContactRPs ALL ROWS';			
        	Recurring_Payment_Profile__c[] rpps = Database.query(soql);
        	for (Recurring_Payment_Profile__c rpp : rpps) {
        		cmap.put(rpp.Contact__c,rpp.Contact__r);
        	}
        	
        	if (!cmap.isEmpty()) {
	        	rollupRecurring( cmap );
	        }	
        }   
        
    }

    public void rollupAll() {
        rollupAllAccounts();
        rollupAllContacts();
        rollupAllHouseholds();
    }   

    public void rollupAllAccounts() {

        // we can handle up to 10000 query rows total, which is about 3000 acct opps in a batch
        // this calculation very conservatively reduces batch size to avoid hitting the limit
        // use a low batch size if there is no household max to calculate by (first time)
        integer batchSize = 10;
        list<account> topAccount = [select NumberOfClosedOpps__c from account 
            where NumberOfClosedOpps__c != null 
            order by NumberOfClosedOpps__c desc limit 1];
        if (!topAccount.isEmpty()) {
            decimal highestCount = topAccount[0].NumberOfClosedOpps__c;
            batchSize = (highestCount <= 15) ? 200 :
                ((3000 / highestCount).intValue() + 1);
        }
        
        // need to preprend the namespace prefix GWBase__ to all Account fields in the batch query to workaround a SF
        // managed package bug  

        // start the batch to roll up all accounts
        GW_BATCH_OppRollup batch = new GW_BATCH_OppRollup( 'SELECT id, ' + GW_Utilities.StrAllNSPrefix(ACCOUNT_ROLLUP_FIELDS) + ' FROM account'
            + (isTest ? ' WHERE name like \'%test%\' LIMIT 200' : '') ); 
        id batchProcessId = database.executeBatch(batch, batchSize);        
    }
    
    public void rollupAllHouseholds() {

        // we can handle up to 10000 query rows total, which is about 3000 acct opps in a batch
        // this calculation very conservatively reduces batch size to avoid hitting the limit
        // use a low batch size if there is no household max to calculate by (first time)
        integer batchSize = 10;
        list<onen_household__c> topHousehold = [select NumberOfClosedOpps__c from ONEN_Household__c 
            where NumberOfClosedOpps__c != null 
            order by NumberOfClosedOpps__c desc limit 1];
        if (!topHousehold.isEmpty()) {
            decimal highestCount = topHousehold[0].NumberOfClosedOpps__c;
            batchSize = (highestCount <= 15) ? 200 :
                ((3000 / highestCount).intValue() + 1);
        }
        
        // need to preprend the namespace prefix GWBase__ to all Account fields in the batch query to workaround a SF
        // managed package bug  

        // start the batch to roll up all accounts
        GW_BATCH_OppRollup batch = new GW_BATCH_OppRollup( 'SELECT id, ' + GW_Utilities.StrAllNSPrefix(HH_ROLLUP_FIELDS) + ' FROM onen_household__c'
            + (isTest ? ' WHERE name like \'%test%\' LIMIT 200' : '') );
        id batchProcessId = database.executeBatch(batch, batchSize);        
    }   
        
    public void rollupAllContacts() {

        // we can handle up to 10000 query rows total, which is about 2000 contact opps in a batch
        // this calculation very conservatively reduces batch size to avoid hitting the limit
        // use a low batch size if there is no household max to calculate by (first time)
        integer batchSize = 10;
        list<contact> topContact = [select NumberOfClosedOpps__c from contact
            where NumberOfClosedOpps__c != null 
            order by NumberOfClosedOpps__c desc limit 1];
        if (!topContact.isEmpty()) {
            decimal highestCount = topContact[0].NumberOfClosedOpps__c;
            batchSize = (highestCount <= 10) ? 200 :
                ((2000 / highestCount).intValue() + 1);
        }
        
        // need to preprend the namespace prefix GWBase__ to all HH fields in the batch query to workaround a SF
        // managed package bug

        GW_BATCH_OppRollup batch = new GW_BATCH_OppRollup( 'SELECT id,' + GW_Utilities.StrAllNSPrefix(CON_ROLLUP_FIELDS) + GW_Utilities.StrAllNSPrefix(CON_RECURRING_ROLLUP_FIELDS) + ' FROM Contact'
            + (isTest ? ' WHERE Name like \'%doppleganger%\' LIMIT 200' : '') );
        id batchProcessId = database.executeBatch(batch, batchSize);        
    }

    public static void updateRollupFromResult(sobject obj, sobject r, map<id, Opportunity> opptyCurrencies) {
    // used for single and batch rollups, this maps query results to the right fields

        // get the fiscal year, total amount, and opp count for this result row     
        integer fy = (integer)(r.get('CalendarYr'));
        decimal amt = ( r.get('TotalOppAmount') == null ) ? 0 : (decimal)(r.get('TotalOppAmount'));
        integer cnt = (integer)(r.get('NumberOfClosedOpps'));               
        
        // split the special field to get the last opp id and amount
        string[] rcf = ((string)(r.get('RollupFieldset'))).split(';\\|;',-4);
        decimal lastAmt = (rcf.size() > 1 && rcf[1] != '') ? decimal.valueOf(rcf[1]) : null;
        
        // calculate amounts into correct currency if needed
        if(isMultiCurrency()){
            amt = ConvertFromCorporate((string)obj.get('CurrencyIsoCode'),amt);
            if(lastAmt != null && rcf.size() > 4 && rcf[4] != '')
                lastAmt = ConvertCurrency((string)opptyCurrencies.get((Id)rcf[4]).get('CurrencyISOCode'),(string)obj.get('CurrencyIsoCode'),lastAmt);           
        }
        
        // check if this is an annual total or account total
        if (fy != null) {

            // put the fiscal year total in the right fields
            if (fy == thisYear) {
                obj.put('OppAmountThisYear__c', amt); 
                obj.put('OppsClosedThisYear__c', cnt); 
            } else if (fy == (thisYear - 1)) {
                obj.put('OppAmountLastYear__c', amt); 
                obj.put('OppsClosedLastYear__c', cnt); 
            } else if (fy == (thisYear - 2) ) {
                obj.put('OppAmount2YearsAgo__c', amt); 
                obj.put('OppsClosed2YearsAgo__c', cnt); 
            } 
                
        } else {

            // fill in summary totals
            obj.put('TotalOppAmount__c', amt);
            obj.put('NumberOfClosedOpps__c', cnt);              
            obj.put('LastOppAmount__c', lastAmt);               
            obj.put('FirstCloseDate__c', (date)(r.get('FirstCloseDate')));
            obj.put('LastCloseDate__c', (date)(r.get('LastCloseDate'))); 
            
            // calculate amounts into correct currency if needed
            if(isMultiCurrency()) {         
            	obj.put('AverageAmount__c', ConvertFromCorporate((string)obj.get('CurrencyIsoCode'),(decimal)r.get('AverageAmount'))); 
            	obj.put('SmallestAmount__c', ConvertFromCorporate((string)obj.get('CurrencyIsoCode'),(decimal)r.get('SmallestAmount'))); 
            	obj.put('LargestAmount__c', ConvertFromCorporate((string)obj.get('CurrencyIsoCode'),(decimal)r.get('LargestAmount'))); 
            } else {
            	obj.put('SmallestAmount__c', (decimal)(r.get('SmallestAmount'))); 
	        	obj.put('LargestAmount__c', (decimal)(r.get('LargestAmount'))); 
	        	obj.put('AverageAmount__c', (decimal)(r.get('AverageAmount'))); 
            }
                
        }
    }

    public static void updateRollupFromResultLastNDays(sobject obj, sobject r) {
    // used for single and batch rollups, this maps query results to the right fields
        
        // get the fiscal year, total amount, and opp count for this result row     
        decimal amt = ( r.get('TotalOppAmount') == null ) ? 0 : (decimal)(r.get('TotalOppAmount'));
        integer cnt = (integer)(r.get('NumberOfClosedOpps'));
        
        // calculate amounts into correct currency if needed
        if(isMultiCurrency())
           amt = ConvertFromCorporate((string)obj.get('CurrencyIsoCode'),amt);              
        
        // fill in totals
        obj.put('OppAmountLastNDays__c', amt);              
        obj.put('OppsClosedLastNDays__c', cnt);
    }

    public static void updateRollupFromResultMembership(sobject obj, sobject r, map<id, Opportunity> opptyCurrencies) {
    // used for single and batch rollups, this maps query results to the right fields
        
        // get the fiscal year, total amount, and opp count for this result row     
        //integer fy = (integer)(r.get('CalendarYr'));
        decimal amt = ( r.get('TotalOppAmount') == null ) ? 0 : (decimal)(r.get('TotalOppAmount'));
        integer cnt = (integer)(r.get('NumberOfClosedOpps'));               

        // split the special field to get the last opp id and amount
        string[] rcf = ((string)(r.get('RollupFieldset'))).split(';\\|;',-4);
        decimal lastAmt = (rcf.size() > 1 && rcf[1] != '') ? decimal.valueOf(rcf[1]) : null;
        string lastMemberLevel = (rcf.size() > 2) ? rcf[2] : null;
        if (lastMemberLevel=='') lastMemberLevel = null;    // chg to null if empty so that won't cause unnecessary write  
        string lastMemberOrigin = (rcf.size() > 3) ? rcf[3] : null;
        if (lastMemberOrigin =='') lastMemberOrigin = null; // chg to null if empty so that won't cause unnecessary write 
        
        // calculate amounts into correct currency if needed
        if(isMultiCurrency()){
           amt = ConvertFromCorporate((string)obj.get('CurrencyIsoCode'),amt);
           if(lastAmt != null && rcf.size() > 4 && rcf[4] != '')
               lastAmt = ConvertCurrency((string)opptyCurrencies.get((Id)rcf[4]).get('CurrencyISOCode'),(string)obj.get('CurrencyIsoCode'),lastAmt);           
        } 
        
        // check if this is an annual total or account total
/* ADD FIELDS AND UNCOMMENT IF YOU NEED ANNUAL MEMBERSHIP TOTAL BREAKOUT
        if (fy != null) {

            // put the fiscal year total in the right fields
            if (fy == thisYear) {
                obj.put('MembershipOppAmountThisYear__c', amt); 
                obj.put('MembershipOppsClosedThisYear__c', cnt); 
            } else if (fy == (thisYear - 1)) {
                obj.put('MembershipOppAmountLastYear__c', amt); 
                obj.put('MembershipOppsClosedLastYear__c', cnt); 
            } else if (fy == (thisYear - 2) ) {
                obj.put('MembershipOppAmount2YearsAgo__c', amt); 
                obj.put('MembershipOppsClosed2YearsAgo__c', cnt); 
            } 
        } else {
*/              
            // fill in summary totals
            obj.put('TotalMembershipOppAmount__c', amt);
            obj.put('NumberOfMembershipOpps__c', cnt);              
            obj.put('LastMembershipDate__c', (date)(r.get('LastCloseDate')));               
            obj.put('LastMembershipAmount__c', lastAmt);                
            obj.put('LastMembershipLevel__c', lastMemberLevel);                 
            obj.put('LastMembershipOrigin__c', lastMemberOrigin);               
            obj.put('MembershipJoinDate__c', (date)(r.get('FirstStartDate'))); 
            obj.put('MembershipEndDate__c', (date)(r.get('LastEndDate')));      
            
//          system.debug (Logginglevel.WARN, 'object after field property changes: ' + obj);        
//      }
    }
	
	/*********** Multi-Currency Support Methods ***********/

    //returns a boolean if we are in a multi-currency org or not.
    //on first execution sets up static variables etc
    public static boolean isMultiCurrency(){
        
        if (multiCurrency==null){
            //create currency field handles for later dynamic dml
            cfOppty = Schema.sObjectType.Opportunity.fields.getMap().get('CurrencyIsoCode');
            cfAccount = Schema.sObjectType.Account.fields.getMap().get('CurrencyIsoCode');
            cfHousehold = Schema.sObjectType.ONEN_household__c.fields.getMap().get('CurrencyIsoCode');
            cfContact = Schema.sObjectType.Contact.fields.getMap().get('CurrencyIsoCode');

            String queryExchangeRates = 'select IsoCode,ConversionRate,IsCorporate from CurrencyType';
            SObjectType soCurrencyType = Schema.getGlobalDescribe().get('CurrencyType'); 

            //are we in a multi-currency org?
            if (cfOppty != null && cfAccount != null && cfHousehold != null && cfContact != null && soCurrencyType != null){
                multiCurrency = true;
 
                map<string,SObjectField> ctFields = soCurrencyType.getDescribe().fields.getMap();
                SObjectField ctIsoCode = ctFields.get('IsoCode');
                SObjectField ctConversionRate = ctFields.get('ConversionRate');
                SObjectField ctCorporate = ctFields.get('IsCorporate');

                //iterate over all the currencies in the org (inc. inactive ones as they may have been used previously)
                //this allows us to put them in a map and use the ISO code as key and also set the corporate
                for(sObject ct: Database.query(queryExchangeRates)){
                    exchangeRates.put((string)ct.get(ctIsoCode),(decimal)ct.get(ctConversionRate));
                    if((boolean)ct.get(ctCorporate))currCorporate=(string)ct.get(ctIsoCode);
                }
            }
            else
                multiCurrency = false; 
        }
        
        return multiCurrency;
        }

    //do a conversion from amount in corporate currency to the currency specified by the ISO code
    public static decimal ConvertFromCorporate(String ISO,Decimal amt){
        if(currCorporate == ISO || currCorporate == null) // no need to convert
            return amt;
        else //return value to 2DP
            return (amt * exchangeRates.get(ISO)).setScale(2) ;
    }

    public static decimal ConvertCurrency(String fromISO, String toISO, Decimal amt){
        if(fromISO == toISO) // no need to convert
            return amt;
        else //return value to 2DP
            return ((amt / exchangeRates.get(fromISO)) * exchangeRates.get(toISO)).setScale(2) ;
    }
 
    //takes the Ids of opptys in the npo02__CombinedRollupFieldset__c field, and looks up the currency of that record
    //only used in multi currency orgs
    //returns a map of those Ids and the associated oppty
    public map<Id,Opportunity> rcfFindCurrency(list<sobject> objectList){
        //new set to hold the opptys we need to query for
        set<Id> opptysForCurrency = new set<Id>();

        //iterate over objects provided to us
        for (sobject r : objectList){
            //pull Id from rollup field and add to set
            string[] rcf = ((string)(r.get('RollupFieldset'))).split(';\\|;',-4);
            if(rcf.size() > 1 && rcf[1] != '')
                opptysForCurrency.add((Id)rcf[4]);
        }
        
        if (!objectlist.isEmpty()){
            //query for oppty and currencycode for all Ids in set.
            string soqlStatement = 'SELECT Id,CurrencyIsoCode FROM Opportunity WHERE Id in :opptysForCurrency';
            map<Id,Opportunity> opptyCurrencies = new map<Id,Opportunity>((list<Opportunity>)Database.query(soqlStatement));
            return opptyCurrencies;
        }
        else
            return null;
        
    }
	
    /************ TESTS ***************/
    
    static testMethod void testGivingRollup () {
        
        Date datClose = System.Today();
            
        // create & insert contact(s)
        Contact[] TestCons = new contact[]{ new contact(firstname='Daddy', lastname='Longlegs') };
        insert TestCons;

        // create new opps
        Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);

        // insert the opp(s)
        isTest = true;
        Test.StartTest();
        insert newOpps;
        
        //now test that a contact has received the proper member stats from the trigger
        id FirstConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT id, account.TotalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, onen_household__c, onen_household__r.TotalOppAmount__c, TotalOppAmount__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 100 , UpdatedCon.TotalOppAmount__c );
        //we don't actually have a HH by default now, so this should be null
        System.AssertEquals ( null , UpdatedCon.onen_household__r.TotalOppAmount__c );      
        System.AssertEquals ( 100 , UpdatedCon.OppAmountThisYear__c);
        System.AssertEquals ( 0 , UpdatedCon.OppAmountLastYear__c);

        // now roll up manually
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupContact(testcons[0].id);

        //make sure the values are still right
        UpdatedCon = [SELECT id, account.TotalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, onen_household__c, onen_household__r.TotalOppAmount__c, TotalOppAmount__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 100 , UpdatedCon.TotalOppAmount__c );
        System.AssertEquals ( null , UpdatedCon.onen_household__r.TotalOppAmount__c );       
        System.AssertEquals ( 100 , UpdatedCon.OppAmountThisYear__c);
        System.AssertEquals ( 0 , UpdatedCon.OppAmountLastYear__c);
        
        // also try the future call, which only gets used if the trigger fails
        GW_OppRollups.rollupHouseholdsFuture( new set<id> { updatedCon.onen_household__c } );
        Test.StopTest();
        
        //make sure the values are still right
        UpdatedCon = [SELECT id, account.TotalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, onen_household__c, onen_household__r.TotalOppAmount__c, TotalOppAmount__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 100 , UpdatedCon.TotalOppAmount__c );
        System.AssertEquals ( null , UpdatedCon.onen_household__r.TotalOppAmount__c );       
        System.AssertEquals ( 100 , UpdatedCon.OppAmountThisYear__c);
        System.AssertEquals ( 0 , UpdatedCon.OppAmountLastYear__c);

        // delete the donations - totals should clear
        delete newOpps;

        //make sure the values are still right
        UpdatedCon = [SELECT id, account.TotalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, onen_household__c, onen_household__r.TotalOppAmount__c, TotalOppAmount__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 0 , UpdatedCon.TotalOppAmount__c );
        System.AssertEquals ( null , UpdatedCon.onen_household__r.TotalOppAmount__c );     
        System.AssertEquals ( 0 , UpdatedCon.OppAmountThisYear__c);
        System.AssertEquals ( 0 , UpdatedCon.OppAmountLastYear__c);
    }
    
    static testMethod void testMemberRollup () {
        
        Date datClose = System.Today();
        string mbrrectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
            
        // create & insert contact(s)
        Contact[] TestCons = new contact[]{ new contact(firstname='Daddy', lastname='Longlegs') };
        insert TestCons;

        // create new opps, first a membership
        Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            datClose, 100 , mbrrectype ,null);
        newOpps[0].Membership_Start_Date__c = datClose;
        newOpps[0].Membership_End_Date__c = datClose.addYears(1);
        newOpps[0].Member_Level__c = 'Regular';
        newOpps[0].Membership_Origin__c = 'Renewal';

        // and then a non-membership
        Opportunity[] gift = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
            datClose, 50 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);

//      system.debug(newOpps);
        
        Opportunity[] allOpps = new Opportunity[0];
        allOpps.addAll(newOpps);
        allOpps.addAll(gift);
        
        // insert the opp(s)
        isTest = true;
        Test.StartTest();
        insert allOpps;
        Test.StopTest();
        
        //now test that a contact has received the proper member stats from the trigger
        id FirstConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT id, TotalMembershipOppAmount__c,LastMembershipOrigin__c, Membership_Status__c, LastMembershipLevel__c, MembershipEndDate__c,
            LastMembershipAmount__c, LastMembershipDate__c, TotalOppAmount__c
            from contact where id =: firstconid];
        if (ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS != ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) {
            System.AssertEquals ( 100 , updatedcon.TotalMembershipOppAmount__c );
            System.AssertEquals ( 100 , updatedcon.LastMembershipAmount__c );   
                    System.AssertEquals ( 'Renewal' , updatedcon.LastMembershipOrigin__c );     
            System.AssertEquals ( 'Current' , updatedcon.Membership_Status__c );        
            System.AssertEquals ( 'Regular' , updatedcon.LastMembershipLevel__c );      
            System.AssertEquals ( datClose.addYears(1) , updatedcon.MembershipEndDate__c );     
            System.AssertEquals ( system.today() , updatedcon.LastMembershipDate__c );      
        } else {
            System.AssertEquals ( 150 , updatedcon.TotalMembershipOppAmount__c );
            System.AssertEquals ( 50 , updatedcon.LastMembershipAmount__c );
        }
        System.AssertEquals ( 150 , updatedcon.TotalOppAmount__c );         
        
        // now delete the member opps, make sure those stats go to zero
        delete newOpps;
        UpdatedCon = [SELECT id, TotalMembershipOppAmount__c,LastMembershipOrigin__c, Membership_Status__c, LastMembershipLevel__c, MembershipEndDate__c,
            LastMembershipAmount__c, LastMembershipDate__c, TotalOppAmount__c
            from contact where id =: firstconid];
        if (ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS != ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) {
            System.AssertEquals ( 0 , updatedcon.TotalMembershipOppAmount__c );     
            System.AssertEquals ( 0 , updatedcon.LastMembershipAmount__c ); 
        } else {
            System.AssertEquals ( 50 , updatedcon.TotalMembershipOppAmount__c );        
            System.AssertEquals ( 50 , updatedcon.LastMembershipAmount__c );    
        }   
        System.AssertEquals ( 50 , updatedcon.TotalOppAmount__c );      
        System.AssertEquals ( null , updatedcon.LastMembershipOrigin__c );      
        /*
        System.AssertEquals ( null , updatedcon.Membership_Status__c );     
        System.AssertEquals ( null , updatedcon.LastMembershipLevel__c );       
        System.AssertEquals ( null , updatedcon.MembershipEndDate__c );     
        System.AssertEquals ( null , updatedcon.LastMembershipDate__c );        
        */
        
        
    }
    
    static testMethod void testRecurringRollup () {
        
        Date datClose = System.Today();
            
        // create & insert contact(s)
        Contact[] TestCons = new contact[]{ new contact(firstname='Daddy', lastname='Longlegs') };
        insert TestCons;

        // create new opps
        Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);
		
		Recurring_Payment_Profile__c rpp = new Recurring_Payment_Profile__c(
			Amount__c = 10,
			Contact__c = TestCons[0].id,
			Start_Date__c = system.today()-180,
			Frequency__c = 1,
			Payment_Period__C = 'Month'
			);
		
        // insert the opp(s)
        isTest = true;
        Test.StartTest();
        insert rpp;
        
        //now test that a contact has received the recurring info from the trigger
        id FirstConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT id, Recurring_Amount__c,Recurring_Payment_Frequency__c,Recurring_Payment_Period__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 10 , UpdatedCon.Recurring_Amount__c );     
        System.AssertEquals ( 1 , UpdatedCon.Recurring_Payment_Frequency__c);
        System.AssertEquals ( 'Month' , UpdatedCon.Recurring_Payment_Period__c);
		
        // now roll up manually
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupContacts(testcons);

        //make sure the values are still right
        UpdatedCon = [SELECT id, Recurring_Amount__c,Recurring_Payment_Frequency__c,Recurring_Payment_Period__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 10 , UpdatedCon.Recurring_Amount__c );     
        System.AssertEquals ( 1 , UpdatedCon.Recurring_Payment_Frequency__c);
        System.AssertEquals ( 'Month' , UpdatedCon.Recurring_Payment_Period__c);

        // delete the recurring payment profile - totals should clear
        delete rpp;

        //make sure the values are still right
        UpdatedCon = [SELECT id, Recurring_Amount__c,Recurring_Payment_Frequency__c,Recurring_Payment_Period__c FROM Contact WHERE Id = :FirstConId];

        System.AssertEquals ( 0 , UpdatedCon.Recurring_Amount__c );     
        System.AssertEquals ( 0 , UpdatedCon.Recurring_Payment_Frequency__c);
        System.AssertEquals ( null , UpdatedCon.Recurring_Payment_Period__c);
        
        Test.StopTest();
        
    }
    
    static testMethod void testGivingRollupAcct () {

        Date datClose = System.Today();

        // create account
        account testacct = new account(name='testacct');
        insert testacct;
        opportunity newOpp =
             new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
                                name = 'testopp', accountid = testacct.id, 
                                stagename=ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, closedate=datClose, amount=33333);
        
        // insert the opp(s)
        Test.StartTest();
        isTest = true;
        insert newOpp;

        // test whether the trigger worked      
        account updatedAcct = [select id, totalOppAmount__c from account where id =: testacct.id];      
        System.AssertEquals ( 33333 , updatedAcct.TotalOppAmount__c );      

        // now roll up manually
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupAccount(testacct.id);

        updatedAcct = [select id, totalOppAmount__c from account where id =: testacct.id];
        System.AssertEquals ( 33333 , updatedAcct.TotalOppAmount__c );      

        // also try the future call, which only gets used if the trigger fails
        GW_OppRollups.rollupAccountsFuture( new set<id> { testacct.id } );

        Test.StopTest();

        updatedAcct = [select id, totalOppAmount__c from account where id =: testacct.id];
        System.AssertEquals ( 33333 , updatedAcct.TotalOppAmount__c );
        
        // now delete the opp, and make sure the amount goes back to 0
        delete newOpp;
        updatedAcct = [select id, totalOppAmount__c from account where id =: testacct.id];
        System.AssertEquals ( 0 , updatedAcct.TotalOppAmount__c );
                
    
    }   

    static testMethod void testGivingRollupAcctMembership () {

        Date datClose = System.Today();
        string mbrrectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;

        // include membership for account rollup
        rollupSettingsForTest.Excluded_Account_Opp_Rectypes__c = null;

        // create account
        account testacct = new account(name='testacct');
        insert testacct;
        opportunity newOpp =
             new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', mbrrectype), 
                                name = 'testopp', accountid = testacct.id,
                                Membership_Start_Date__c = datClose, Membership_End_Date__c = datClose.addMonths(12), 
                                member_level__c = 'Gold', membership_origin__c = 'New',
                                stagename=ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, closedate=datClose, amount=33333);
        
        // insert the opp(s)
        Test.StartTest();
        isTest = true;
        insert newOpp;

        // test whether the trigger worked      
        account updatedAcct = [select id, totalMembershipOppAmount__c, LastMembershipDate__c, MembershipEndDate__c, MembershipJoinDate__c,
            LastMembershipAmount__c, LastMembershipLevel__c, LastMembershipOrigin__c, totalOppAmount__c
            from account where id =: testacct.id];      
        System.AssertEquals ( datClose , updatedAcct.MembershipJoinDate__c );       
        System.AssertEquals ( datClose.addMonths(12) , updatedAcct.MembershipEndDate__c );      
        System.AssertEquals ( 33333 , updatedAcct.TotalMembershipOppAmount__c );        
        System.AssertEquals ( system.today() , updatedAcct.LastMembershipDate__c );     
        System.AssertEquals ( 33333 , updatedAcct.LastMembershipAmount__c );        
        System.AssertEquals ( 'Gold' , updatedAcct.LastMembershipLevel__c );        
        System.AssertEquals ( 'New' , updatedAcct.LastMembershipOrigin__c );        
        System.AssertEquals ( 33333 , updatedAcct.totalOppAmount__c );      
 
        // now roll up manually
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupAccount(testacct.id);

        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose , updatedAcct.MembershipJoinDate__c );       
        System.AssertEquals ( datClose.addMonths(12) , updatedAcct.MembershipEndDate__c );      
        System.AssertEquals ( 33333 , updatedAcct.TotalMembershipOppAmount__c );        

        // also try the future call, which only gets used if the trigger fails
        GW_OppRollups.rollupAccountsFuture( new set<id> { testacct.id } );

        Test.StopTest();

        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose , updatedAcct.MembershipJoinDate__c );       
        System.AssertEquals ( datClose.addMonths(12) , updatedAcct.MembershipEndDate__c );      
        System.AssertEquals ( 33333 , updatedAcct.TotalMembershipOppAmount__c );        
    
        // now chg member dates, and make sure trigger updates dates on acct
        newOpp.Membership_Start_Date__c = datClose.addDays(1);
        newOpp.Membership_End_Date__c = datClose.addMonths(12).addDays(1);
//      system.debug (LoggingLevel.WARN,'updating opp w/ new member dates...');
        update newOpp;
        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose.addDays(1) , updatedAcct.MembershipJoinDate__c );        
        System.AssertEquals ( datClose.addMonths(12).addDays(1) , updatedAcct.MembershipEndDate__c );   
        
        //add a 2nd opp w/ null amount, chk it doesn't blow any gaskets
        opportunity opp2 =
             new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', mbrrectype), 
                                name = 'testopp2', accountid = testacct.id,
                                Membership_Start_Date__c = datClose.addYears(-2), Membership_End_Date__c = datClose.addYears(-1), 
                                stagename=ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, closedate=datClose);
        insert opp2;
        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose.addYears(-2) , updatedAcct.MembershipJoinDate__c );      
        System.AssertEquals ( datClose.addMonths(12).addDays(1) , updatedAcct.MembershipEndDate__c );       
    }   

    static testMethod void testGivingRollupAcctMembershipWithMembershipExcludedBySettings () {

        Date datClose = System.Today();
        string mbrrectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;

        // exclude membership from account rollup
        rollupSettingsForTest.Excluded_Account_Opp_Rectypes__c = mbrrectype;

        // create account
        account testacct = new account(name='testacct');
        insert testacct;
        opportunity newOpp =
             new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', mbrrectype), 
                                name = 'testopp', accountid = testacct.id,
                                Membership_Start_Date__c = datClose, Membership_End_Date__c = datClose.addMonths(12), 
                                member_level__c = 'Gold', membership_origin__c = 'New',
                                stagename=ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, closedate=datClose, amount=33333);
        
        // insert the opp(s)
        Test.StartTest();
        isTest = true;
        insert newOpp;

        // test whether the trigger worked      
        account updatedAcct = [select id, totalMembershipOppAmount__c, LastMembershipDate__c, MembershipEndDate__c, MembershipJoinDate__c,
            LastMembershipAmount__c, LastMembershipLevel__c, LastMembershipOrigin__c, totalOppAmount__c
            from account where id =: testacct.id];      
        System.AssertEquals ( datClose , updatedAcct.MembershipJoinDate__c );       
        System.AssertEquals ( datClose.addMonths(12) , updatedAcct.MembershipEndDate__c );      
        System.AssertEquals ( 33333 , updatedAcct.TotalMembershipOppAmount__c );        
        System.AssertEquals ( system.today() , updatedAcct.LastMembershipDate__c );     
        System.AssertEquals ( 33333 , updatedAcct.LastMembershipAmount__c );        
        System.AssertEquals ( 'Gold' , updatedAcct.LastMembershipLevel__c );        
        System.AssertEquals ( 'New' , updatedAcct.LastMembershipOrigin__c );        
        System.AssertEquals ( 0 , updatedAcct.totalOppAmount__c );      
 
        // now roll up manually
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupAccount(testacct.id);

        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose , updatedAcct.MembershipJoinDate__c );       
        System.AssertEquals ( datClose.addMonths(12) , updatedAcct.MembershipEndDate__c );      
        System.AssertEquals ( 33333 , updatedAcct.TotalMembershipOppAmount__c );        

        // also try the future call, which only gets used if the trigger fails
        GW_OppRollups.rollupAccountsFuture( new set<id> { testacct.id } );

        Test.StopTest();

        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose , updatedAcct.MembershipJoinDate__c );       
        System.AssertEquals ( datClose.addMonths(12) , updatedAcct.MembershipEndDate__c );      
        System.AssertEquals ( 33333 , updatedAcct.TotalMembershipOppAmount__c );        
    
        // now chg member dates, and make sure trigger updates dates on acct
        newOpp.Membership_Start_Date__c = datClose.addDays(1);
        newOpp.Membership_End_Date__c = datClose.addMonths(12).addDays(1);
//      system.debug (LoggingLevel.WARN,'updating opp w/ new member dates...');
        update newOpp;
        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose.addDays(1) , updatedAcct.MembershipJoinDate__c );        
        System.AssertEquals ( datClose.addMonths(12).addDays(1) , updatedAcct.MembershipEndDate__c );   
        
        //add a 2nd opp w/ null amount, chk it doesn't blow any gaskets
        opportunity opp2 =
             new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', mbrrectype), 
                                name = 'testopp2', accountid = testacct.id,
                                Membership_Start_Date__c = datClose.addYears(-2), Membership_End_Date__c = datClose.addYears(-1), 
                                stagename=ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, closedate=datClose);
        insert opp2;
        updatedAcct = [select id, TotalMembershipOppAmount__c, MembershipEndDate__c, MembershipJoinDate__c from account where id =: testacct.id];
        System.AssertEquals ( datClose.addYears(-2) , updatedAcct.MembershipJoinDate__c );      
        System.AssertEquals ( datClose.addMonths(12).addDays(1) , updatedAcct.MembershipEndDate__c );       
    }   

    static testMethod void testGivingRollupBatch () {
        
        Date datClose = System.Today();
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( 100 ) ;
        insert TestCons;

        // create new opps
        Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose, 1000 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);

        account testacct = new account(name='testacct');
        insert testacct;

        // test the batch rollup method
        isTest = true; 
        Test.StartTest();
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupAll();
        Test.StopTest();
    }   
    
    static testMethod void OneContactCreateThreeOpps() {
        integer howMany = 1;
        Date datToday = System.Today();
        //Date dat1YearAgo = Date.newInstance( datToday.year()-1,1,1);
        Date dat1YearAgo = datToday.addYears(-1);
        Date dat2YearAgo = datToday.addYears(-2);
        Date dat4YearAgo = datToday.addYears(-4);
        Date dat5YearAgo = datToday.addYears(-5);
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
        insert TestCons;
        
        test.starttest();
        isTest = true;
//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 1...');
        
        List<Opportunity> oppsToCreate = new List<Opportunity>();
        
        // create a new gift for this yr
        Opportunity[] testGift1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datToday, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift1);

//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 2...');
        
        //create a 2nd gift for last yr
        Opportunity[] testGift2 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, dat1YearAgo, 60, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift2);
        
        // now create a gift from 2 yrs ago
        Opportunity[] testGift3 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, dat2YearAgo, 10 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift3);
        
        insert oppstoCreate;
        
        //now test that the contact has received the proper stats from the trigger
        id ThisConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmount2YearsAgo__c, OppAmountLastYear__c, Best_Gift_Year__c, Best_Gift_Year_Total__c FROM Contact WHERE Id = :ThisConId];
        
        System.AssertEquals ( 170 , UpdatedCon.totalOppAmount__c );
        System.AssertEquals ( 100 , UpdatedCon.OppAmountThisYear__c );
        System.AssertEquals ( 60 , UpdatedCon.OppAmountLastYear__c );
        // adjust for fiscal year
        System.AssertEquals ( datToday.year() - ((thisYear == system.today().year()) ? 0 : 1), UpdatedCon.Best_Gift_Year__c );
        System.AssertEquals ( 100 , UpdatedCon.Best_Gift_Year_Total__c );
        System.AssertEquals ( 10 , UpdatedCon.OppAmount2YearsAgo__c );
        
        test.stopTest();
    }
    
    static testMethod void OneContactUpdateTwoOpps() {
        integer howMany = 1;
        Date datToday = System.Today();
        //Date dat1YearAgo = Date.newInstance( datToday.year()-1,1,1);
        Date dat1YearAgo = datToday.addYears(-1);
        Date dat2YearAgo = datToday.addYears(-2);
        Date dat4YearAgo = datToday.addYears(-4);
        Date dat5YearAgo = datToday.addYears(-5);
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
        insert TestCons;
        
        isTest = true;
//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 1...');
        
        // create a new gift for this yr
        Opportunity[] testGift1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datToday, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        insert testGift1 ;

//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 2...');
        
        //create a 2nd gift for last yr
        Opportunity[] testGift2 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, dat1YearAgo, 60, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        insert testGift2;
        
        test.startTest();
        
        // now chg the amts for both opps (cheapskate!)
        testGift1[0].Amount = 50;
        //ONEN_OpportunityInstallments.haveCheckedPayments = false;
        update TestGift1;

//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> changing gift 2...');
        
        testGift2[0].Amount=25;
        //ONEN_OpportunityInstallments.haveCheckedPayments = false;
        update TestGift2;
        
        //now test that the contact has updated stats from the trigger
        id ThisConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT Id, totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c  FROM Contact WHERE Id = :ThisConId];
        
        System.AssertEquals ( 75 , UpdatedCon.totalOppAmount__c );
        System.AssertEquals ( 50 , UpdatedCon.OppAmountThisYear__c );       
        System.AssertEquals ( 25 , UpdatedCon.OppAmountLastYear__c );
        
        test.stopTest();
    }
    
    static testMethod void addingNonWonGift() {
        integer howMany = 1;
        Date datToday = System.Today();
        //Date dat1YearAgo = Date.newInstance( datToday.year()-1,1,1);
        Date dat1YearAgo = datToday.addYears(-1);
        Date dat2YearAgo = datToday.addYears(-2);
        Date dat4YearAgo = datToday.addYears(-4);
        Date dat5YearAgo = datToday.addYears(-5);
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
        insert TestCons;
        
        isTest = true;
//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 1...');
        
        List<Opportunity> oppsToCreate = new List<Opportunity>();
        
        // create a new gift for this yr
        Opportunity[] testGift1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datToday, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift1);

//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 2...');
        
        //create a 2nd gift for last yr
        Opportunity[] testGift2 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, dat1YearAgo, 60, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift2);
        
        insert oppsToCreate;
        
        test.startTest();
        
        // TBD add non-won gift
//      system.debug ( 'TEST>>>>> inserting gift 6...');
        Opportunity[] testGift6 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Prospecting', dat4YearAgo, 35 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        insert testGift6;
        
        //now test that the contact has received the proper stats from the trigger
        id ThisConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, Best_Gift_Year__c, Best_Gift_Year_Total__c FROM Contact WHERE Id = :ThisConId];
        
        System.AssertEquals ( 160 , UpdatedCon.totalOppAmount__c );
        System.AssertEquals ( 100 , UpdatedCon.OppAmountThisYear__c );
        System.AssertEquals ( 60 , UpdatedCon.OppAmountLastYear__c );
        // adjust for fiscal year
        System.AssertEquals ( datToday.year() - ((thisYear == system.today().year()) ? 0 : 1), UpdatedCon.Best_Gift_Year__c );
        System.AssertEquals ( 100 , UpdatedCon.Best_Gift_Year_Total__c );
        
        test.stopTest();
    }
    
    static testMethod void deleteWonGift() {
        integer howMany = 1;
        Date datToday = System.Today();
        //Date dat1YearAgo = Date.newInstance( datToday.year()-1,1,1);
        Date dat1YearAgo = datToday.addYears(-1);
        Date dat2YearAgo = datToday.addYears(-2);
        Date dat4YearAgo = datToday.addYears(-4);
        Date dat5YearAgo = datToday.addYears(-5);
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
        insert TestCons;
        
        isTest = true;
//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 1...');
        
        List<Opportunity> oppsToCreate = new List<Opportunity>();
        
        // create a new gift for this yr
        Opportunity[] testGift1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datToday, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift1);

//      system.debug ( LoggingLevel.WARN, 'TEST>>>>> inserting gift 2...');
        
        //create a 2nd gift for last yr
        Opportunity[] testGift2 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, dat1YearAgo, 60, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift2);
        
        // now create a gift from 2 yrs ago
        Opportunity[] testGift3 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, dat2YearAgo, 10 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        oppsToCreate.addAll(testGift3);
        
        insert oppstoCreate;
        
        test.startTest();
        
        // now delete the 1st gift (now at $50), totals should decrease
//      system.debug ( 'TEST>>>>> deleting gift 1...'); 
        delete testGift1;
        id ThisConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c, Best_Gift_Year__c, Best_Gift_Year_Total__c  FROM Contact WHERE Id = :ThisConId];
        
        System.AssertEquals ( 70 , UpdatedCon.totalOppAmount__c );
        System.AssertEquals ( 0 , UpdatedCon.OppAmountThisYear__c );        
        System.AssertEquals ( 60 , UpdatedCon.OppAmountLastYear__c );
        System.AssertEquals ( 10 , UpdatedCon.OppAmount2YearsAgo__c );      
        System.AssertEquals ( 60 , UpdatedCon.Best_Gift_Year_Total__c );
        
        test.stopTest();
    }
    
    static testMethod void OneContactOneInkind() {
        
        integer howMany = 1;
        Date datToday = System.Today();
        
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
        insert TestCons;
        
//      system.debug ( 'TEST>>>>> inserting gift 1...');
        
        // create a new gift for this yr
        Opportunity[] testGift1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datToday, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,'In Kind');
        isTest = true;
        insert testGift1 ;
        
        id ThisConId = TestCons[0].id;
        contact UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c FROM Contact WHERE Id = :ThisConId];
    
        System.Assert( !(UpdatedCon.totalOppAmount__c>0) );
        
        testGift1[0].Type = 'Cash';
        update testGift1;
        
        UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c FROM Contact WHERE Id = :ThisConId];
        System.AssertEquals ( 100 , UpdatedCon.totalOppAmount__c );
        
    
    }

    static testMethod void testGivingRollupBulk () {
    
        // for a single contact w/ no previous mbrships, add a new membership
        // and test mbr stats are created
        integer howMany = 50;
        Date datClose = System.Today();
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
        insert TestCons;
        
        // create new opps
        Opportunity[] newOpps1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);
        Opportunity[] newOpps2 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose.addYears(-1), 50 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS,null);

        // insert the opp(s)
        Test.StartTest();
        isTest = true;
        insert newOpps1;
        insert newOpps2;

        Test.StopTest();
        
        id FirstConId = TestCons[10].id;
        Contact UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c FROM Contact WHERE Id = :FirstConId];
        
        System.AssertEquals ( 150 , UpdatedCon.totalOppAmount__c );
        System.AssertEquals ( 100 , UpdatedCon.OppAmountThisYear__c );      
        System.AssertEquals ( 50 , UpdatedCon.OppAmountLastYear__c );
        System.AssertEquals ( 0 , UpdatedCon.OppAmount2YearsAgo__c );
        
    }


    static testMethod void testGivingRollupTooManyOpps () {
    
        // for a single contact w/ no previous mbrships, add a new membership
        // and test mbr stats are created
    
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( 1 ) ;
        insert TestCons;
        
        // create new opps
        Opportunity[] newOpps1 = new Opportunity[0];
        for (integer n = 0; n < 200; n++) {
            newOpps1.add( new opportunity(RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
                cr_contact_id__c = TestCons[0].id, name = 'test opp ' + n, 
                stagename = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, closedate = system.today().adddays(-n), amount = 100));
        }
        
        // insert the opp(s)
        Test.StartTest();
        isTest = true;
        insert newOpps1;
        Test.StopTest();
        
        id FirstConId = TestCons[0].id;
        Contact UpdatedCon = [SELECT Id,  totalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c FROM Contact WHERE Id = :FirstConId];
        
        System.AssertEquals ( 20000 , UpdatedCon.totalOppAmount__c );
        
    } 
    
    static testMethod void testHouseholdStats () {
        
        Date datClose = System.Today();
        
        //now must create the HH first since automated HH'ing is no more as of 11/2011
        ONEN_Household__c hh = new ONEN_Household__c(Name='Foo_Household');
        insert hh;
            
        // create & insert contact(s)
        Contact Con1 = new contact(
            firstname='Daddy', 
            lastname='Longlegs',
            ONEN_Household__c = hh.id,
            SecondContactFirstName__c = 'MommyTEST',
            SecondContactLastName__c = 'Longlegs'
        );
        insert Con1;
        Contact[] TestCons = new Contact[] {Con1}; 
        
        // create new opps
        Opportunity[] newOpps1 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);
        Opportunity[] newOpps2 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose.addYears(-2), 200 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);
        Opportunity[] newOpps3 = ONEN_UnitTestData.OppsForContactList ( TestCons, null, ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, datClose.addYears(-3), 75 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);

        Opportunity[] testOpps = new Opportunity[0];
        testOpps.addAll (newOpps1);
        testOpps.addAll (newOpps2);
        testOpps.addAll (newOpps3);

        // insert the opp(s)
        isTest = true;
        Test.StartTest();
        insert testOpps;
        Test.StopTest();
        
        Contact c = [SELECT Id,Total_Household_Gifts__c,OppAmountThisYearHH__c,OppAmountLastYearHH__c,LastCloseDateHH__c,ONEN_Household__r.Best_Gift_Year__c,
            ONEN_Household__r.Best_Gift_Year_Total__c  
            FROM Contact WHERE LastName='Longlegs' AND FirstName='MommyTEST' LIMIT 1];
        System.assertEquals (375,c.Total_Household_Gifts__c);
        System.assertEquals (100,c.OppAmountThisYearHH__c);
        System.assertEquals (0,c.OppAmountLastYearHH__c);
        System.assertEquals (datClose,c.LastCloseDateHH__c );
        System.assertEquals (375,c.Total_Household_Gifts__c);
        
        // adjust for fiscal year
        System.assertEquals (datClose.addYears(-2).year() - ((thisYear == system.today().year()) ? 0 : 1),c.ONEN_Household__r.Best_Gift_Year__c);
        System.assertEquals (200,c.ONEN_Household__r.Best_Gift_Year_Total__c);
        
        
    }   
    
}