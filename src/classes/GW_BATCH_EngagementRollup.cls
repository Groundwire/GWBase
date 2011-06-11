// Written by Matthew Scholtz, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 01/01/2010
* @description NULL_DESCRIPTION
*/
global virtual class GW_BATCH_EngagementRollup implements Database.Batchable<Sobject>, Schedulable {

    public String Query;
    public boolean isTest; 
    boolean filterTestConsOnly = false;
    
    public map<integer,string> lvlNameMap = new map<integer,string>();
    map<integer,string> lvlNameSettingMap = new map<integer,string> {
        1=>GW_Utilities.StrTokenNSPrefix('Level_1_Name__c') , 
        2=>GW_Utilities.StrTokenNSPrefix('Level_2_Name__c') , 
        3=>GW_Utilities.StrTokenNSPrefix('Level_3_Name__c') , 
        4=>GW_Utilities.StrTokenNSPrefix('Level_4_Name__c') , 
        5=>GW_Utilities.StrTokenNSPrefix('Level_5_Name__c') , 
        6=>GW_Utilities.StrTokenNSPrefix('Level_6_Name__c') , 
        7=>GW_Utilities.StrTokenNSPrefix('Level_7_Name__c') , 
        8=>GW_Utilities.StrTokenNSPrefix('Level_8_Name__c')}; 
    integer[] lvlsNoNeedResp = new integer[0];
    map<string,EngagementContactFieldSettings__c> fieldSettingsMap = new map<string,EngagementContactFieldSettings__c>(); 
    map<string,EngagementFrequencySettings__c> freqSettingsMap = new map<string,EngagementFrequencySettings__c>(); 
    public integer monthsRecent;
    public integer monthsMedium;
    private date cutoffDateRecent;
    private date cutoffDateMedium; 
    private integer NewMbrLvl;
    private integer RetMbrLvl;
    
    /*******************************************************************************************************
	* @description This constructor is needed to allow this class to be schedulable.
	*/
    global GW_BATCH_EngagementRollup() { }
    
    
    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	*/
    global GW_BATCH_EngagementRollup (boolean isTestArg) {
        isTest = isTestArg;
        GW_OppRollups.isTest = isTestArg;
        getSettingParams();
        constructQuery();
    }
    
    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	*/    
    global void execute(SchedulableContext SC) {
        
        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
        integer batchSize = 50;  // default
        if (settings.Batch_Size__c > 0) {
            batchSize = settings.Batch_Size__c.intvalue(); 
        }
         
        GW_BATCH_EngagementRollup ladderBatch = new GW_BATCH_EngagementRollup(false);
        id batchinstanceid = database.executeBatch (ladderBatch, batchSize);  
    }

    protected void getSettingParams() {

        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
        monthsRecent = settings.Timeframe_Recent__c.intvalue();
        monthsMedium = settings.Timeframe_Medium__c.intvalue();
        fieldSettingsMap = EngagementContactFieldSettings__c.getAll();
        freqSettingsMap = EngagementFrequencySettings__c.getAll();
        if (settings.New_Member_Level__c!=null) NewMbrLvl = settings.New_Member_Level__c.intvalue();
        if (settings.Renewing_Member_Level__c!=null) RetMbrLvl = settings.Renewing_Member_Level__c.intvalue();
        for (integer i=1 ; i<=lvlNameSettingMap.keyset().size() ; i++) {
            string fname = lvlNameSettingMap.get(i);
            object lname = settings.get(fname);
            string lnamestr = (string)lname;
            if (lnamestr!=null) {
                lvlNameMap.put(i,lnamestr);
            }
        }
        if (settings.Levels_Don_t_Require_Responded__c!=null) {
            string[] lvlsNoResp = settings.Levels_Don_t_Require_Responded__c.split(';');
            for(string lvlNoResp:lvlsNoResp) {
                lvlsNoNeedResp.add(integer.valueOf(lvlNoResp));
            }
        }
        if (settings.Testing_Mode__c && !isTest) {
            filterTestConsOnly = True;
        }

    }
    
    
    protected void constructQuery() {
        string querySOQL = 'SELECT Id,Name,Engagement_Level__c,Engagement_Level_Numeric__c,Engagement_Peak__c,Engagement_Peak_Numeric__c,';
        querySOQL +=        'Engagement_Level_Override__c,Engagement_Level_Override_Numeric__c,Engagement_Override_End_Date__c,Last_Leadership_Action_Date__c,First_Action_Date_Curr_Level__c,';
        querySOQL +=        'OppAmountLastNDays__c,Best_Gift_Year__c,Best_Gift_Year_Total__c,OppAmountLastNDaysHH__c,LastCloseDate__c,LastCloseDateHH__c,OppsClosedLastNDays__c,';
        querySOQL +=        'ONEN_Household__r.OppsClosedLastNDays__c,ONEN_Household__r.Best_Gift_Year__c,ONEN_Household__r.Best_Gift_Year_Total__c,';
        querySOQL +=        'MembershipJoinDate__c,MembershipEndDate__c,LastMembershipLevel__c,LastMembershipOrigin__c,LastMembershipDate__c,LastMembershipAmount__c,';

        // add our namespace prefix to fields we own.
        querySOQL = GW_Utilities.StrAllNSPrefix(querySOQL);
        
        // include any checkbox fields from settings in the query
        if (fieldSettingsMap.size()>0) {
            for (EngagementContactFieldSettings__c s : fieldSettingsMap.values() ) {
                querySOQL += s.Fieldname__c + ','; 
            }
        }
        querySOQL = querySOQL.substring(0,querySOQL.length()-1);   //lop off trailing comma
        
        querySOQL += ' FROM Contact';
        if (isTest) {
            querySOQL += ' WHERE LastName=\'Doppleganger\'';
        } else if (filterTestConsOnly) {
            querySOQL += ' WHERE Title=\'testeng\'';
        }
        //system.debug (Logginglevel.WARN,'query string: ' + querySOQL);
        Query = querySOQL;      
    }

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param BC NULL_PARAMETER
	* @return NULL_RETURN
	*/    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(Query);
    }

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param BC NULL_PARAMETER
	* @param SBatch NULL_PARAMETER
	* @return NULL_RETURN
	*/
    global void execute(Database.BatchableContext BC, List<Sobject> SBatch){
        system.debug (Logginglevel.WARN,'running execute!');
        Map<id,Contact> conMap = new Map<id,Contact>();
        Map<id,ConWrapper> conWrapMap = new Map<id,ConWrapper>();
        set<id> conIDs = new set<id>();
        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
        Contact[] consToUpd = new Contact[0]; 
        
        cutoffDateRecent = system.today().addMonths(monthsRecent * -1);
        cutoffDateMedium = system.today().addMonths(monthsMedium * -1);
        
        // cast sobjects to Contacts, and add to wrappers & maps        
        for (sobject s: SBatch) {
            Contact con = (Contact)s;
            conIDs.add(con.Id);
            ConWrapper cw = new ConWrapper(con.Id);
            cw.con = con.clone(true,true);
            conWrapMap.put (con.Id,cw);
            conMap.put (con.Id,con);
            
            /*  //deprecated
            ONEN_EngagementHistory conHist = new ONEN_EngagementHistory(con.Id);
            conHist.con = con;
            conHist.conCheckboxFields = conCheckboxFields;
            conHist.conCheckboxLevelMap = conCheckboxLevelMap;
            histMap.put(con.Id,conHist);
            */
        }
        
        //system.debug (Logginglevel.WARN,'conwrapper map before calcs: ' + conWrapMap);

        // fetch campaign mbrships in recent time period and get max level
        //  (require either that the campaign start date be within the time frame, or that the FirstRespondedDate of the CM is, and is also within Campaign start/end dates)
        // note can't GROUP BY a formula field as of may 2010, so need to group by the text field and manually switch it to numeric
        for (sobject r : 
            [SELECT ContactId, Campaign.Leadership_Level__c campLvl, 
                MAX (Campaign.Engagement_Level_Numeric__c) MaxLevel, COUNT_DISTINCT(Id) countCMs, MAX (Effective_Action_Date__c) LastDate, 
                MIN (Effective_Action_Date__c) FirstDate ,
                GROUPING(ContactId) subtCon, GROUPING(Campaign.Leadership_Level__c) subtLvl 
                FROM CampaignMember 
                WHERE ContactId IN :conIDs
                AND Campaign.Leadership_Level__c!=Null
                AND (HasResponded=True OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp)
                AND Effective_Action_Date__c >= :cutoffDateRecent 
                GROUP BY CUBE (ContactId, Campaign.Leadership_Level__c )
                ORDER BY GROUPING(Campaign.Leadership_Level__c) desc , GROUPING(ContactId) 
              ] ) {
                    //system.debug (LoggingLevel.WARN,'agg obj:' + r);
                    ConWrapper cw;
                    if (r.get('subtCon')==0) {
                        Id conid = (id)r.get('ContactId');
                        cw = conWrapMap.get(conid);
                    }
                    if (r.get('subtCon')==0 && r.get('subtLvl')==1 ) {
                        // if this is a contact summary row
                        // temporarily assign this level to the contact (may be raised in later steps)
                        Double lvldbl = (double)r.get('MaxLevel');
                        Integer lvl = lvldbl.intvalue();
                        cw.CurrLvl = lvl;
                        cw.PeakLvl = lvl;
                        cw.LastActionDate = (date)r.get('LastDate');
                    } else if (r.get('subtCon')==0 && r.get('subtLvl')==0 ) {
                        // this is a detail row (which should come after all of the con summary rows)
                        if ( (double)r.get('MaxLevel')==cw.CurrLvl ) {
                            cw.FirstActionDateInLvl = (date)r.get('FirstDate');
                        }
                    }
        }
        
        // also get the peak lvl (all dates)
        for (sobject r : 
            [SELECT ContactId, 
                MAX (Campaign.Engagement_Level_Numeric__c) MaxLevel, COUNT_DISTINCT(Id) countCMs, MAX (Effective_Action_Date__c) LastDate
                FROM CampaignMember 
                WHERE ContactId IN :conIDs
                AND Campaign.Leadership_Level__c!=Null
                AND (HasResponded=True OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp)
                // AND Effective_Action_Date__c >= :cutoffDateRecent 
                GROUP BY ContactId
              ] ) {
                    // and temporarily assign this level to the contact (may be raised in later steps)
                    Id conid = (id)r.get('ContactId');
                    Double lvldbl = (double)r.get('MaxLevel');
                    Integer lvl = lvldbl.intvalue();
                    ConWrapper cw = conWrapMap.get(conid);
                    cw.PeakLvl = lvl;
                    if (cw.LastActionDate==null) cw.LastActionDate = (date)r.get('LastDate');
        }
        
        // now check frequency rules that require fields (separate SOQL for each one!)
        for (EngagementFrequencySettings__c fqset : freqSettingsMap.values() ) {
            if (fqset.Fieldname_1__c != null) {
                string qstr = 'SELECT ContactId,Calendar_Year(Effective_Action_Date__c) yr,COUNT_DISTINCT(Id) CountCMs, ';
                qstr +=         ' GROUPING(ContactId) subtCon  ';
                qstr +=         ' FROM CampaignMember WHERE ContactId IN :conIDs AND Campaign.Leadership_Level__c!=Null ';
                qstr +=         ' AND (HasResponded=True OR Campaign.Engagement_Level_Numeric__c IN :lvlsNoNeedResp) ';
                qstr +=         ' AND Effective_Action_Date__c >= :cutoffDateRecent ';
                // add our namespace prefix to fields we own.
                qstr = GW_Utilities.StrAllNSPrefix(qstr);
                // fields coming from settings we can't assume should be namespace prefixed.
                qstr +=         ' AND Campaign.' + fqset.Fieldname_1__c + '= \'' + fqset.Field_Value_1__c + '\' ';
                qstr +=         GW_Utilities.StrAllNSPrefix(' GROUP BY ROLLUP ( ContactId, Calendar_Year(Effective_Action_Date__c) )');
                //system.debug (Logginglevel.WARN,'querystring: ' + qstr);
                sobject[] results = Database.query(qstr);
                for (sobject row : results) {
                    double count = (double)row.get('CountCMs');
                    if (row.get('subtCon')==0 && row.get('yr')==null && count >= fqset.Number_Of_Actions_Required__c) {
                        // if this is con row, and we meet the frequency criteria, assign lvl to con as appropriate
                        Id conid = (id)row.get('ContactId');
                        ConWrapper cw = conWrapMap.get(conid);
                        Contact con = cw.con;
                        if (fqset.Level_To_Assign__c > cw.CurrLvl) {
                            cw.CurrLvl = fqset.Level_To_Assign__c.intvalue();
                            // don't worry about dates, should have been assigned in first step above
                        }
                        if (fqset.Level_To_Assign__c > cw.PeakLvl) {
                            cw.PeakLvl = fqset.Level_To_Assign__c.intvalue();
                        }
                    } else if (row.get('yr')!=null && row.get('subtCon')==0 && count >= fqset.Number_Of_Actions_Required__c) {
                        // if this is a detail row (per con and per yr) then see if constitutes a higher peak
                        Id conid = (id)row.get('ContactId');
                        ConWrapper cw = conWrapMap.get(conid);
                        if (fqset.Level_To_Assign__c > cw.PeakLvl) {
                            cw.PeakLvl = fqset.Level_To_Assign__c.intvalue();
                        }
                    }
                }
            }
        }
    
        // now loop back through our contacts and apply contact-centric level rules
        for (ConWrapper cw : conWrapMap.values() ) {
            Contact con = cw.con;       
        
            // consider con fields
            for (EngagementContactFieldSettings__c fSet : fieldSettingsMap.values()) {
                 boolean qual = false;
                 string fname = fSet.Fieldname__c;
                 object val = con.get(fname);
                 if (fSet.Field_Type__c=='checkbox') {
                     boolean checked = Boolean.valueOf(val);
                     if (checked) qual = true;
                 } else if (fSet.Field_Type__c=='text' && fSet.Field_Value__c != null) {
                    // note this applies to any text equivalent field types: picklist, email, address, etc
                    string valStr = (string)val;
                    if (fSet.Field_Value__c == '*' && valStr!=null && valStr!='') {
                        qual = true;
                    } else if (fSet.Field_Value__c != '*' && fSet.Field_Value__c==valStr) {
                        qual = true;
                    }
                 }
                 
                if (qual==true) {
                    integer fieldlvl = fSet.Level_Value__c.intvalue();
                    if (fieldlvl > cw.CurrLvl) {
                        cw.CurrLvl = fieldlvl;
                        cw.FirstActionDateInLvl = null;     // blank out first action date, since no date for a field lvl
                    }
                    if (fieldlvl > cw.PeakLvl) {
                        cw.PeakLvl = fieldlvl;
                    }                   
                }   
                 
            }
            
            // chk override
            if (con.Engagement_Level_Override_Numeric__c > cw.CurrLvl) {
                cw.CurrLvl = con.Engagement_Level_Override_Numeric__c.intvalue();
                cw.FirstActionDateInLvl = null;
            }
            if (con.Engagement_Level_Override_Numeric__c > cw.PeakLvl) {
                cw.PeakLvl = con.Engagement_Level_Override_Numeric__c.intvalue();
            }
        
            // if including opps, calc levels based on donor rollup fields (assumes rollups are up to date)
            // donor calcs should be last so they can see if HH (spouse) donors had levels from anything else besides donations
            if (settings.Include_Opps__c) {
                // first get settings for donor level tiers
                decimal[] donorBreakpoints = new decimal[0];
                map<decimal,double> donorLvlMap = new map<decimal,double>();  
                List<Engagement_Donor_Level_Settings__c> donorLvlDefs = Engagement_Donor_Level_Settings__c.getall().values();
                if (donorLvlDefs.size() > 0) {
                    for (Engagement_Donor_Level_Settings__c s : donorLvlDefs ) {
                        donorBreakpoints.add (s.Lower_Limit__c);
                        donorLvlMap.put (s.Lower_Limit__c,s.Level__c);
                    }
                    donorBreakpoints.sort();
                    //system.debug(Logginglevel.WARN, 'donorBreakpoints: ' + donorBreakpoints);
                    
                    // now use opp rollup fields to figure the donor-derived level
                    decimal recentGiftTtl = con.OppAmountLastNDays__c; 
                    decimal recentGiftTtlHH = con.OppAmountLastNDaysHH__c;
                    double lvlRecent; 
                    double lvlPeak;
                    for (integer i=0;i<donorBreakpoints.size();i++) {
                        system.debug(Logginglevel.WARN, 'i=: ' + i);
                        decimal brkpt = donorBreakpoints[i];
                        integer lvl = donorLvlMap.get(brkpt).intvalue();
                        // award the level if either this contact made it on "personal" gifts (where they were primary contact)...
                        if (recentGiftTtl >= brkpt && lvl > cw.CurrLvl) {
                            cw.CurrLvl = lvl;
                            cw.LastActionDate = con.LastCloseDate__c;
                            if (con.OppsClosedLastNDays__c==1) {
                                cw.FirstActionDateInLvl = con.LastCloseDate__c;     // if only 1 gift, last is also the first
                            } else {
                                // TBD we could add this con to a list, and then query for the actual first date??
                                cw.FirstActionDateInLvl = cutoffDateRecent;  // b/c level is awarded for entire year, not one gift
                            }
                        //  ...or for HH gifts, but only if they have at some point been awarded a level on their own, for any other reason
                        //      the reasoning being that that makes it more likely the gift is really from the family/couple and not just the primary con 
                        } else if  (recentGiftTtlHH > brkpt && (cw.CurrLvl > 0 || cw.PeakLvl > 0) && lvl > cw.CurrLvl )  {
                            cw.CurrLvl = lvl;
                            cw.LastActionDate = con.LastCloseDateHH__c;
                            if (con.ONEN_Household__r.OppsClosedLastNDays__c==1) {
                                cw.FirstActionDateInLvl = con.LastCloseDateHH__c;
                            } else {
                                cw.FirstActionDateInLvl = cutoffDateRecent;
                            }
                        // assign lastaction date even if we don't give the level, as long as they already had a date (i.e. level not due to override or chkbox)
                        //  and this date is more recent
                        } else if (con.Best_Gift_Year_Total__c > 0 && con.LastCloseDate__c > cw.LastActionDate && cw.LastActionDate!=null) {
                            cw.LastActionDate = con.LastCloseDate__c;
                        }
                        // for peak level, look at best year calcs
                        //  as above, we're willing to take it from the HH if this contact has credits from anything else ever
                        if ( lvl > cw.PeakLvl && 
                            ( con.Best_Gift_Year_Total__c >= brkpt || (con.ONEN_Household__r.Best_Gift_Year_Total__c >= brkpt && (cw.CurrLvl > 0 || cw.PeakLvl > 0)) ) 
                        ) {
                            cw.PeakLvl = lvl;
                        }
                    }
                }
            }
            
            // now figure membership
            if (settings.Include_Membership__c && (con.MembershipEndDate__c!=null || con.HouseholdMembershipEndDate__c!=null) && RetMbrLvl!=null && NewMbrLvl!=null) {
                integer mbrlvl;
                if (con.LastMembershipOrigin__c=='Renewal' || con.LastMembershipDate__c > con.MembershipJoinDate__c) {
                    mbrlvl = RetMbrLvl;
                } else {
                    mbrlvl = NewMbrLvl;
                }
                if (con.LastMembershipDate__c >= cutoffDateRecent && mbrlvl > cw.CurrLvl) cw.CurrLvl = mbrlvl;
                if (mbrlvl > cw.PeakLvl) cw.PeakLvl = mbrlvl;  
            }   
            
            //system.debug (Logginglevel.WARN,'conwrapper map after calcs: ' + conWrapMap);
        
            // write chgs to contacts, but only if something actually changed
            string lvlStr = lvlNameMap.get(cw.CurrLvl);
            string peakStr = lvlNameMap.get(cw.PeakLvl);
            if (cw.CurrLvl != con.Engagement_Level_Numeric__c || cw.PeakLvl != con.Engagement_Peak_Numeric__c || lvlStr!=con.Engagement_Level__c || 
                peakStr!=con.Engagement_Peak__c || cw.LastActionDate!=con.Last_Leadership_Action_Date__c || cw.FirstActionDateInLvl!=con.First_Action_Date_Curr_Level__c) 
                {
                    con.Engagement_Level_Numeric__c = cw.CurrLvl;
                    con.Engagement_Peak_Numeric__c = cw.PeakLvl;
                    con.Engagement_Level__c = lvlStr; 
                    con.Engagement_Peak__c = peakStr;
                    con.Last_Leadership_Action_Date__c = cw.lastActionDate;
                    con.First_Action_Date_Curr_Level__c = cw.FirstActionDateInLvl;
                    
                    consToUpd.add(con);
                }
        }
        
        //system.debug (Logginglevel.WARN,'consToUpd:' + consToUpd);
        if (consToUpd.size() > 0) {
            update consToUpd;
        }
        
    }

    /*******************************************************************************************************
	* @description NULL_DESCRIPTION
	* @param BC NULL_PARAMETER
	*/      
    global void finish(Database.BatchableContext BC){
        
    }

    
    // *** WRAPPER CLASS **************************************************************
    
    
    public virtual class conWrapper {
        private id conId;
        public Contact con;
        
        public integer CurrLvl=0;
        public integer PeakLvl=0;
        public date LastActionDate;
        public date FirstActionDateInLvl;

        //constructor 
        public conWrapper (id argId) {
            conId = argId;  
        }   

    }

    // called from the Contact before trigger
    public static void ContactEngagementLvlOverride() {    
        // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
        // can't do this w/ workflow due to limitations in date arithmetic
        
        Contact[] cons = new Contact[0];
        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
        integer months = 12;  // overall default if none other specified
        if (settings!=null) months = (settings.Override_Default_Duration__c==null) ? months : settings.Override_Default_Duration__c.intvalue();
        
        date defDate;
        
        for (SObject obj : trigger.new) {
            Contact con = (Contact)obj;
            if (con.Engagement_Level_Override__c!=null) {
                Contact oldCon;
                boolean dateChgd = false;
                boolean lvlChgd = false;
                if (trigger.isUpdate) {
                    oldCon = (Contact)trigger.oldMap.get(con.Id);
                    dateChgd = (con.Engagement_Override_End_Date__c!=oldCon.Engagement_Override_End_Date__c ? true : false );
                    lvlChgd = (con.Engagement_Level_Override__c!=oldCon.Engagement_Level_Override__c ? true : false );
                }
                if ( (trigger.isInsert && con.Engagement_Override_End_Date__c==null) || (trigger.isUpdate && lvlChgd && !dateChgd) ) {
                    cons.add(con);
                }           
            }         
        }
        
        if (cons.size() > 0) {
            // optimization: do date math after first loop
            defDate = system.today().addMonths(months);
            for (Contact con:cons) {
                con.Engagement_Override_End_Date__c = defDate;
            }
        }
    }
    

    // *** TESTS **********************************************************************
    
    // test constants
    static integer SMALLGIFTLVL,MAJORGIFTLVL,MONTHS_RECENT,MONTHS_MEDIUM,NEWMBRLVL,RENMBRLVL,OVERDEFDUR;
    static decimal MAJGIFTAMT;
    static string INCOPPTYPES,MBROPPTYPES;
    static boolean INCOPPS,INCMBR;
    
    
    static void setSettingsForTests(string txtfield1, string txtfield1FV, double txtfield1lvl) {
        
        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
        if (settings == null) settings = new EngagementTrackerSettings__c();

        settings.Include_Opps__c = true; 
        settings.Include_Opp_Rectypes__c = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS + ';' + ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
        settings.Timeframe_Recent__c = 12;
        settings.Timeframe_Medium__c = 12;
        settings.Include_Membership__c = True;
        settings.Membership_Record_Types__c =  ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
        settings.New_Member_Level__c = 3;
        settings.Renewing_Member_Level__c = 4;
        settings.Override_Default_Duration__c = 12;
        settings.Batch_Size__c = 25;
        settings.Level_1_Name__c = '1 - lvl one';
        settings.Level_2_Name__c = '2 - lvl two';
        settings.Level_3_Name__c = '3 - lvl three';
        settings.Level_4_Name__c = '4 - lvl four';
        settings.Level_5_Name__c = '5 - lvl five';
        settings.Level_6_Name__c = '6 - lvl six';
        upsert settings;

        
        // clear out list settings
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('EngagementContactFieldSettings__c');
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('EngagementFrequencySettings__c');
        ONEN_UnitTestData.DeleteListCustomSettingRecs ('Engagement_Donor_Level_Settings__c');
        
        // now add list settings back in
            // first fields

        EngagementContactFieldSettings__c fset = new EngagementContactFieldSettings__c (
            Name = 'foo',
            Fieldname__c = txtfield1,
            Field_Type__c = 'Text',
            Field_Value__c = txtfield1FV,
            Level_Value__c = txtfield1lvl
        );
        EngagementContactFieldSettings__c fset2 = new EngagementContactFieldSettings__c (
            Name = 'bar',
            Fieldname__c = 'Email',
            Field_Type__c = 'Text',
            Field_Value__c = '*',
            Level_Value__c = 1
        );
        insert new EngagementContactFieldSettings__c[] {fset,fset2};
        
        // next frequency rules
        EngagementFrequencySettings__c fqset = new EngagementFrequencySettings__c (
            Name = 'foo',
            Level_Required__c = 2,
            Level_To_Assign__c = 3,
            Number_of_Actions_Required__c = 3,
            Fieldname_1__c = GW_Utilities.StrTokenNSPrefix('Campaign_Sub_Type__c'),
            Field_Value_1__c = 'Online Action'
        );
        insert fqset;
        
        // next donor tiers
        Engagement_Donor_Level_Settings__c dset1 = new Engagement_Donor_Level_Settings__c (
            Name = 'foo',
            Lower_Limit__c = 1,
            Level__c = 2
        );
        Engagement_Donor_Level_Settings__c dset2 = new Engagement_Donor_Level_Settings__c (
            Name = 'foo2',
            Lower_Limit__c = 100,
            Level__c = 3
        );
        Engagement_Donor_Level_Settings__c dset3 = new Engagement_Donor_Level_Settings__c (
            Name = 'foo3',
            Lower_Limit__c = 1000,
            Level__c = 4
        );
        Engagement_Donor_Level_Settings__c[] dsets = new Engagement_Donor_Level_Settings__c[] {dset1,dset2,dset3};
        insert dsets;
        
        INCOPPS = settings.Include_Opps__c;
        INCMBR = settings.Include_Membership__c;
        NEWMBRLVL = settings.New_Member_Level__c.intvalue();
        RENMBRLVL = settings.Renewing_Member_Level__c.intvalue();
        
    }


    static map<integer,string> getLvlNameMapForTests() {
        // this stuff basically repeated from the class - need this looked up for the test as well
        map<integer,string> lvlNameMapTest = new map<integer,string>();
        map<integer,string> lvlNameSettingMap = new map<integer,string>{
            1=>GW_Utilities.StrTokenNSPrefix('Level_1_Name__c') , 
            2=>GW_Utilities.StrTokenNSPrefix('Level_2_Name__c') , 
            3=>GW_Utilities.StrTokenNSPrefix('Level_3_Name__c') , 
            4=>GW_Utilities.StrTokenNSPrefix('Level_4_Name__c') , 
            5=>GW_Utilities.StrTokenNSPrefix('Level_5_Name__c') , 
            6=>GW_Utilities.StrTokenNSPrefix('Level_6_Name__c') , 
            7=>GW_Utilities.StrTokenNSPrefix('Level_7_Name__c') , 
            8=>GW_Utilities.StrTokenNSPrefix('Level_8_Name__c')};
        
        /* TBD
        for (integer i=1 ; i<=lvlNameSettingMap.keyset().size() ; i++) {
            string fname = lvlNameSettingMap.get(i);
            object lname = settings.get(fname);
            string lnamestr = (string)lname;
            if (lnamestr!=null) {
                lvlNameMap.put(i,lnamestr);
            }
        } */
        
        return lvlNameMapTest;
    }
    
    
    public static testMethod void testLevelAssignment() {

        // note: in addition to this batch process, this test relies on the ONEN_Contact_EngagementLvlOverride trigger
        string txtfield1 = GW_Utilities.StrTokenNSPrefix('BoardMember__c');
        double txtfield1lvl = 6;
        string txtfield1FV = 'Current';
        setSettingsForTests(txtfield1, txtfield1FV, txtfield1lvl);
        
        integer howMany = 23;
        Date datClose = System.Today();
        string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
        string MbrRectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
        EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
        integer monthsRecent = settings.Timeframe_Recent__c.intvalue();
        integer monthsMedium = settings.Timeframe_Medium__c.intvalue();
        date startDateRecent = datClose.addMonths((monthsRecent*-1)+1);
        date startDateMedium = datClose.addMonths((monthsMedium*-1)+1);
        date startDateOld = datClose.addMonths((monthsMedium*-1)-12);
        date giftYearStartDate = datClose.addMonths((monthsRecent*-1));
        
        map<integer,string> lvlNameMapTest = new map<integer,string>();
        
        List<Engagement_Donor_Level_Settings__c> donorLvlDefs = Engagement_Donor_Level_Settings__c.getall().values();
        decimal[] donorBreakpoints = new decimal[0];
        map<decimal,double> donorLvlMap = new map<decimal,double>();          
        for (Engagement_Donor_Level_Settings__c s : donorLvlDefs ) {
            donorBreakpoints.add (s.Lower_Limit__c);
            donorLvlMap.put (s.Lower_Limit__c,s.Level__c);
        }
        donorBreakpoints.sort();
        integer DONORLVL1 = donorLvlMap.get(donorBreakpoints[0]).intvalue(); 
        integer DONORLVL2 = donorLvlMap.get(donorBreakpoints[1]).intvalue(); 
                    
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts(howMany);
        TestCons[5].BoardMember__c = 'Current';  // temp
        TestCons[10].Engagement_Level_Numeric__c = 3;  
        TestCons[10].Engagement_Peak_Numeric__c = 3;  
        // TestCons[10].Engagement_Level_Mod_Date__c = system.today().addMonths(-2);
        TestCons[19].FirstName = '16Spouse';
        TestCons[20].FirstName = '17Spouse';
        TestCons[21].Email = 'test@test.com';   // this should give lvl 1
        
        insert TestCons;

        // put 4 cons in 2 HH's, have to query to get HH
        Contact[] SpouseCons = [SELECT Id,FirstName,ONEN_Household__c,HouseholdName__c,ONEN_Household__r.Member_Count__c FROM Contact 
            /*WHERE FirstName LIKE '%Spouse' AND LastName = 'Doppleganger' ORDER BY FirstName*/
            WHERE Id IN :new Id[]{TestCons[16].Id,TestCons[17].Id,TestCons[19].Id,TestCons[20].Id} ORDER BY FirstName];
        // add HH contacts manually - for now, don't use automatic HH second-contact creator since don't want to require new HH code
        system.debug (Logginglevel.WARN,'spouseCon:' + SpouseCons[0]);
        system.AssertEquals('16Spouse' , SpouseCons[0].FirstName);
        system.AssertEquals('Number17' , SpouseCons[3].FirstName);
        SpouseCons[0].ONEN_Household__c = SpouseCons[2].ONEN_Household__c;
        SpouseCons[1].ONEN_Household__c = SpouseCons[3].ONEN_Household__c;
        update new Contact[] {SpouseCons[0],SpouseCons[1]};
                
        // create a few activist campaigns
        Campaign camp1 = new Campaign (
            Name = 'Camp 1 This Yr Lvl 3',
            StartDate = startDateRecent,
            isActive = true,
            Leadership_Level__c = '3 - testLevel'
        );
        Campaign camp2 = new Campaign (
            Name = 'Camp 2 Last Yr Lvl 4',
            StartDate = startDateMedium,
            isActive = true,
            Leadership_Level__c = '4 - testLevelAlso'
        );
        Campaign camp3 = new Campaign (
            Name = 'Camp 3 This Yr Lvl 2',
            StartDate = startDateRecent,
            isActive = true,
            Leadership_Level__c = '2 - testLevelLower'
        );
        Campaign oldCamp = new Campaign (
            Name = 'Camp 4 Historical Lvl 3',
            StartDate = startDateOld,
            isActive = true,
            Leadership_Level__c = '5 - organizerlevel'
        );
        // this is an intentionally ridiculously long campaign, but testing that it will use the date
        // on the CM since within date range of camp.
        Campaign longCamp = new Campaign (
            Name = 'long lvl 4',
            StartDate = startDateMedium.addMonths(-2),
            EndDate = system.today().addMonths(1),
            isActive = true,
            Leadership_Level__c = '4 - testLevelAlso'
        );
        
        
        // add a bunch of campaigns of a particular type, for testing frequency rule
        integer i=1;
        Campaign[] onlineCamps = new Campaign[0];
        do {
            Campaign camp = new Campaign (
                Name = 'Online Campaign #' + i,
                StartDate = startDateRecent,
                isActive = true,
                Leadership_Level__c = '2 - testLevelLower',
                Type = 'Action',
                Campaign_Sub_Type__c = 'Online Action'
            );
            onlineCamps.add(camp);
            i++;
        } while (i<=3);
        
        Campaign[] camps = new Campaign[]{camp1,camp2,camp3,oldCamp,longCamp};
        camps.addAll(onlineCamps); 
        insert camps;

        CampaignMember cm0 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[0].Id,
            Status = 'Responded'
        );      
        CampaignMember cm02 = new CampaignMember (
            CampaignId = oldCamp.Id,
            ContactId = TestCons[0].Id,
            Status = 'Responded'
        );      
        CampaignMember cm1 = new CampaignMember (
            CampaignId = camp2.Id,
            ContactId = TestCons[1].Id,
            Status = 'Responded'
        );      
        CampaignMember cm2 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[2].Id,
            Status = 'Responded'
        );      
        CampaignMember cm22 = new CampaignMember (
            CampaignId = camp2.Id,
            ContactId = TestCons[2].Id,
            Status = 'Responded'
        );      
        CampaignMember cm3 = new CampaignMember (
            CampaignId = oldCamp.Id,
            ContactId = TestCons[3].Id,
            Status = 'Responded'
        );      
        CampaignMember cm4 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[4].Id,
            Status = 'Responded'
        );      
        CampaignMember cm42 = new CampaignMember (
            CampaignId = camp2.Id,
            ContactId = TestCons[4].Id,
            Status = 'Responded'
        );      
        CampaignMember cm43 = new CampaignMember (
            CampaignId = camp3.Id,
            ContactId = TestCons[4].Id,
            Status = 'Responded'
        );      
        CampaignMember cm5 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[5].Id,
            Status = 'Responded'
        );      
        CampaignMember cm8 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[8].Id,
            Status = 'Responded'
        );      
        CampaignMember cm9 = new CampaignMember (
            CampaignId = camp3.Id,
            ContactId = TestCons[9].Id,
            Status = 'Responded'
        );      
        CampaignMember cm11 = new CampaignMember (
            CampaignId = longCamp.Id,
            ContactId = TestCons[11].Id,
            Status = 'Responded'
        );      
        CampaignMember cm112 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[11].Id,
            Status = 'Responded'
        );      
        CampaignMember cm14 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[14].Id,
            Status = 'Responded'
        );      
        CampaignMember cm15 = new CampaignMember (
            CampaignId = camp1.Id,
            ContactId = TestCons[15].Id,
            Status = 'Responded'
        );      
        CampaignMember cm19 = new CampaignMember (
            CampaignId = camp3.Id,
            ContactId = TestCons[20].Id,
            Status = 'Responded'
        );
        CampaignMember[] onlineCMs = new CampaignMember[0]; 
        for (Campaign c : onlineCamps) {
            CampaignMember cm = new CampaignMember (
                CampaignId = c.Id,
                ContactId = TestCons[18].Id,
                Status = 'Responded'
            );
            onlineCMs.add (cm);      
        }      

        CampaignMember[] cms = new CampaignMember[]{cm0,cm02,cm1,cm2,cm22,cm3,cm4,cm42,cm43,cm5,cm8,cm9,cm11,cm112,cm14,cm15,cm19};
        cms.AddAll(onlineCMs); 
        insert cms;
        system.debug ('cms inserted: ' + cms);

        // create new opps
        double smallAmt = donorBreakpoints[1] - 5; // assumes at least $5 of separation, good assumption I hope!
        double majAmt = donorBreakpoints[2] - 5;   // also assumes at least 3 lvls
        Contact[] ConsForSmallOpps = new Contact[]{TestCons[6],TestCons[7],TestCons[8],TestCons[9],TestCons[10],TestCons[16]};
        Opportunity[] recentSmallOpps = ONEN_UnitTestData.OppsForContactList (ConsForSmallOpps,null,'Closed Won',startDateRecent,smallAmt,GiftRectype,null);
        Contact[] ConsForMajOpps = new Contact[]{TestCons[7],TestCons[17]};
        Opportunity[] recentMajOpps = ONEN_UnitTestData.OppsForContactList (ConsForMajOpps,null,'Closed Won',startDateRecent,majAmt,GiftRectype,null);
        Contact[] ConsOldMajOpps = new Contact[]{TestCons[8]};
        Opportunity[] oldMajOpps = ONEN_UnitTestData.OppsForContactList (ConsOldMajOpps,null,'Closed Won',startDateOld,majAmt,GiftRectype,null);
        Contact[] ConsMediumSmallOpps = new Contact[]{TestCons[9]};
        Opportunity[] medSmallOpps = ONEN_UnitTestData.OppsForContactList (ConsMediumSmallOpps,null,'Closed Won',startDateMedium,smallAmt,GiftRectype,null);
        Contact[] ConsMbrshipThisYear = new Contact[]{TestCons[12],TestCons[13]};
        Opportunity[] mbrshipsThisYr = ONEN_UnitTestData.OppsForContactList (ConsMbrshipThisYear,null,'Closed Won',startDateRecent,smallAmt,MbrRectype,null);
        Contact[] ConsMbrshipLastYear = new Contact[]{TestCons[13]};
        Opportunity[] mbrshipsLastYr = ONEN_UnitTestData.OppsForContactList (ConsMbrshipLastYear,null,'Closed Won',startDateRecent.addYears(-1),smallAmt,MbrRectype,null);
        //now set membership fields
        Opportunity[] mbrOpps = new Opportunity[0];
        mbrOpps.addAll(mbrshipsThisYr);
        mbrOpps.addAll(mbrshipsLastYr);
        for (Opportunity opp : mbrOpps) {
            opp.Membership_Start_Date__c = opp.CloseDate;
            opp.Membership_End_Date__c = opp.CloseDate.AddYears(1);
        }
        Opportunity[] allOpps = new Opportunity[0];
        allOpps.addAll(recentSmallOpps);
        allOpps.addAll(recentMajOpps);
        allOpps.addAll(oldMajOpps);
        allOpps.addAll(medSmallOpps);
        allOpps.addAll(mbrOpps);
        insert allOpps;
        
        
        GW_BATCH_EngagementRollup myba = new GW_BATCH_EngagementRollup (true);
        // once the batch process is instantiated, borrow the level-levelname map which is created in constructor, for reference in assertions below
        lvlNameMapTest = myba.lvlNameMap;
        // set override on a few contacts - have to do this after we get the map
        TestCons[14].Engagement_Level_Override__c = lvlNameMapTest.get(4);
        TestCons[15].Engagement_Level_Override__c = lvlNameMapTest.get(4);
        TestCons[15].Engagement_Override_End_Date__c = system.today().addMonths(3);
        Contact[] overrideCons = new Contact[] {TestCons[14],TestCons[15]};
        update overrideCons;
        // then away we go
        Test.StartTest();
        ID batchprocessid = Database.executeBatch(myba);
        Test.StopTest();
    
        Id[] ConIDs = new Id[0];
        for (Contact con : TestCons) {
            ConIDs.add(con.Id);
        }
        
        // query for all the cons we started with
        map<Id,Contact> conP = new map<Id,Contact> ([SELECT Id,Name,Engagement_Level__c,Engagement_Level_Numeric__c,Engagement_Peak__c,Engagement_Peak_Numeric__c,
            Last_Leadership_Action_Date__c,First_Action_Date_Curr_Level__c,Engagement_Level_Override__c,Engagement_Level_Override_Numeric__c,Engagement_Override_End_Date__c,
            ONEN_Household__c,HouseholdName__c
            FROM Contact WHERE Id IN :ConIDs]);
        system.debug (loggingLevel.WARN, 'conP:' + conP);
        
        // but now have to get them into the same order they started in
        
        
        // only this yr, but higher peak
        Contact con0P = conP.get(TestCons[0].Id);
        System.AssertEquals(3,con0P.Engagement_Level_Numeric__c);       
        System.AssertEquals(lvlNameMapTest.get(3),con0P.Engagement_Level__c);       
        System.AssertEquals(5,con0P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(5),con0P.Engagement_Peak__c);        
        // System.AssertEquals(system.today(),con0P.Engagement_Level_Mod_Date__c);      
        System.AssertEquals(startDateRecent,con0P.Last_Leadership_Action_Date__c);      
        System.AssertEquals(startDateRecent,con0P.First_Action_Date_Curr_Level__c);     
        System.AssertEquals(null,con0P.Engagement_Level_Override__c);       
        System.AssertEquals(null,con0P.Engagement_Override_End_Date__c);        

        // only last yr
        Contact con1P = conP.get(TestCons[1].Id);
        System.AssertEquals(4,con1P.Engagement_Level_Numeric__c);       
        System.AssertEquals(4,con1P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con1P.Engagement_Peak__c);
        System.AssertEquals(startDateMedium,con1P.Last_Leadership_Action_Date__c);  
        
        // both years, last yr greater
        Contact con2P = conP.get(TestCons[2].Id);
        System.AssertEquals(4,con2P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con2P.Engagement_Level__c);       
        System.AssertEquals(startDateRecent,con2P.Last_Leadership_Action_Date__c);          
        System.AssertEquals(startDateMedium,con2P.First_Action_Date_Curr_Level__c);         
        
        // only peak, nothing recent
        Contact con3P = conP.get(TestCons[3].Id);
        System.AssertEquals(0,con3P.Engagement_Level_Numeric__c);       
        System.AssertEquals(5,con3P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(5),con3P.Engagement_Peak__c);
        System.AssertEquals(startDateOld,con3P.Last_Leadership_Action_Date__c); 
        System.AssertEquals(null,con3P.First_Action_Date_Curr_Level__c);  // b/c no actions at level 0  

        // this yr, but board member picklist
        Contact con5P = conP.get(TestCons[5].Id);
        System.AssertEquals(txtfield1lvl,con5P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(txtfield1lvl.intvalue()),con5P.Engagement_Level__c);                
        System.AssertEquals(txtfield1lvl,con5P.Engagement_Peak_Numeric__c);
        System.AssertEquals(startDateRecent,con5P.Last_Leadership_Action_Date__c);  // this doesn't care about the lvl
        System.AssertEquals(null,con5P.First_Action_Date_Curr_Level__c);  // b/c no actions, just chkbox

        if (INCOPPS) {
            // recent small donation only
            Contact con6P = conP.get(TestCons[6].Id);
            System.AssertEquals(DONORLVL1,con6P.Engagement_Level_Numeric__c);        
            System.AssertEquals(DONORLVL1,con6P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL1),con6P.Engagement_Peak__c);
            System.AssertEquals(startDateRecent,con6P.Last_Leadership_Action_Date__c);  
            System.AssertEquals(startDateRecent,con6P.First_Action_Date_Curr_Level__c);
    
            // recent small donation & maj donation (should work out to donor tier 3)
            Contact con7P = conP.get(TestCons[7].Id);
            System.AssertEquals(DONORLVL2+1,con7P.Engagement_Level_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL2+1),con7P.Engagement_Level__c);        
            System.AssertEquals(DONORLVL2+1,con7P.Engagement_Peak_Numeric__c);
            System.AssertEquals(startDateRecent,con7P.Last_Leadership_Action_Date__c);  
            System.AssertEquals(giftYearStartDate,con7P.First_Action_Date_Curr_Level__c);
    
            // historical maj gift, recent small gift & campaign
            Contact con8P = conP.get(TestCons[8].Id);
            integer lvlnow = (DONORLVL1>3) ? DONORLVL1 : 3;
            System.AssertEquals(lvlnow,con8P.Engagement_Level_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(lvlnow),con8P.Engagement_Level__c);          
            System.AssertEquals(DONORLVL2,con8P.Engagement_Peak_Numeric__c);
    
            // 2 gifts, one lesser action
            Contact con9P = conP.get(TestCons[9].Id);
            System.AssertEquals(DONORLVL2,con9P.Engagement_Level_Numeric__c);        
            System.AssertEquals(DONORLVL2,con9P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL2),con9P.Engagement_Peak__c);
            System.AssertEquals(startDateRecent,con9P.Last_Leadership_Action_Date__c);  
            System.AssertEquals(giftYearStartDate,con9P.First_Action_Date_Curr_Level__c);
    
            // gift this yr
            Contact con10P = conP.get(TestCons[10].Id);
            System.AssertEquals(DONORLVL1,con10P.Engagement_Level_Numeric__c);       
            System.AssertEquals(DONORLVL1,con10P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(DONORLVL1),con10P.Engagement_Peak__c);
            // System.AssertEquals(system.today().addMonths(-2),con10P.Engagement_Level_Mod_Date__c);
            
            // HH mbr w/ no other activity, shouldn't get HH donation credit
            Contact con19P = conP.get(TestCons[19].Id);
            System.AssertEquals(0,con19P.Engagement_Level_Numeric__c);        
            System.AssertEquals(0,con19P.Engagement_Peak_Numeric__c);
            System.AssertEquals(null,con19P.Last_Leadership_Action_Date__c);
              
            // HH mbr other activity, should get HH donation credit
            Contact con20P = conP.get(TestCons[20].Id);
            system.debug (Logginglevel.WARN,'testcon20:' + con20P);
            System.AssertEquals(DONORLVL2,con20P.Engagement_Level_Numeric__c);        
            System.AssertEquals(DONORLVL2,con20P.Engagement_Peak_Numeric__c);
            System.AssertEquals(startDateRecent,con20P.Last_Leadership_Action_Date__c);
            System.AssertEquals(startDateRecent,con20P.First_Action_Date_Curr_Level__c);
        }

        // in long campaign, but CM date is recent
        Contact con11P = conP.get(TestCons[11].Id);
        System.AssertEquals(4,con11P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con11P.Engagement_Level__c);          
        System.AssertEquals(4,con11P.Engagement_Peak_Numeric__c);
        System.AssertEquals(system.today(),con11P.Last_Leadership_Action_Date__c);  
        System.AssertEquals(system.today(),con11P.First_Action_Date_Curr_Level__c);

        // over frequency limit for campaigns, should get higher level
        Contact con18P = conP.get(TestCons[18].Id);
        System.AssertEquals(3,con18P.Engagement_Level_Numeric__c);
        System.AssertEquals(3,con18P.Engagement_Peak_Numeric__c);
        System.AssertEquals(startDateRecent,con18P.Last_Leadership_Action_Date__c);  
        System.AssertEquals(startDateRecent,con18P.First_Action_Date_Curr_Level__c);

        /* omitting this for now, pending decision whether to include
        // decayed from last yr
        Contact con4P = conP.get(TestCons[4].Id);
        System.AssertEquals(3,con4P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(3),con4P.Engagement_Level__c);               
        System.AssertEquals(4,con4P.Engagement_Peak_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con4P.Engagement_Peak__c);
        System.AssertEquals(startDateRecent,con4P.First_Action_Date_Curr_Level__c); 
        */
        
        IF (INCMBR) {
            // mbrship this yr only
            Contact con12P = conP.get(TestCons[12].Id);
            System.AssertEquals(NEWMBRLVL,con12P.Engagement_Level_Numeric__c);      
            System.AssertEquals(NEWMBRLVL,con12P.Engagement_Peak_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(NEWMBRLVL),con12P.Engagement_Peak__c);
            System.AssertEquals(startDateRecent,con12P.Last_Leadership_Action_Date__c); 
            System.AssertEquals(startDateRecent,con12P.First_Action_Date_Curr_Level__c);
    
            // renewing mbr this yr
            Contact con13P = conP.get(TestCons[13].Id);
            System.AssertEquals(RENMBRLVL,con13P.Engagement_Level_Numeric__c);
            System.AssertEquals(lvlNameMapTest.get(RENMBRLVL),con13P.Engagement_Level__c);          
            System.AssertEquals(RENMBRLVL,con13P.Engagement_Peak_Numeric__c);
        }

        // lvl 3 this yr, but overridden to 4 w/ default date
        Contact con14P = conP.get(TestCons[14].Id);
        System.AssertEquals(4,con14P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con14P.Engagement_Level__c);          
        System.AssertEquals(4,con14P.Engagement_Peak_Numeric__c);
        System.AssertEquals(4,con14P.Engagement_Level_Override_Numeric__c);     
        System.AssertEquals(system.today().addMonths(12),con14P.Engagement_Override_End_Date__c);   

        // ditto, but used custom end date
        Contact con15P = conP.get(TestCons[15].Id);
        System.AssertEquals(4,con15P.Engagement_Level_Numeric__c);
        System.AssertEquals(lvlNameMapTest.get(4),con15P.Engagement_Level__c);          
        System.AssertEquals(4,con15P.Engagement_Peak_Numeric__c);
        System.AssertEquals(4,con15P.Engagement_Level_Override_Numeric__c);     
        System.AssertEquals(system.today().addMonths(3),con15P.Engagement_Override_End_Date__c);    

        // lvl 1 due to email field being populated
        Contact con21P = conP.get(TestCons[21].Id);
        System.AssertEquals(1,con21P.Engagement_Level_Numeric__c);        
        System.AssertEquals(null,con21P.Last_Leadership_Action_Date__c);
                 
        // and one that has nothing!
        Contact con22P = conP.get(TestCons[22].Id);
        System.AssertEquals(0,con22P.Engagement_Level_Numeric__c);        
    }
    
            
}