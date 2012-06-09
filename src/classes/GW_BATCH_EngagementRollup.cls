// Written by Matthew Scholtz, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Matthew Scholtz
* @date 01/01/2010
* @description This is the primary class for Engagement Tracker.  This class calculates and assigns engagement levels for contacts based on custom settings and
*  Campaign, Opp, and Contact data.  Currently this class only runs during batch, not from a trigger, so in general we recommend scheduling it to run nightly.  
*/
global virtual class GW_BATCH_EngagementRollup implements Database.Batchable<Sobject>, Schedulable {

    public String Query;
    public boolean isTest; 
    boolean filterTestConsOnly = false;
    
    public map<integer,string> lvlNameMap = new map<integer,string>();
    map<integer,string> lvlNameSettingMap = new map<integer,string> {
            1 => addNSPrefixET('Level_1_Name__c',true,false) , 
            2 => addNSPrefixET('Level_2_Name__c',true,false) , 
            3 => addNSPrefixET('Level_3_Name__c',true,false) , 
            4 => addNSPrefixET('Level_4_Name__c',true,false) , 
            5 => addNSPrefixET('Level_5_Name__c',true,false) , 
            6 => addNSPrefixET('Level_6_Name__c',true,false) , 
            7 => addNSPrefixET('Level_7_Name__c',true,false) , 
            8 => addNSPrefixET('Level_8_Name__c',true,false) };
    integer[] lvlsNoNeedResp = new integer[0];
    map<string,EngagementContactFieldSettings__c> fieldSettingsMap = new map<string,EngagementContactFieldSettings__c>(); 
    map<string,EngagementFrequencySettings__c> freqSettingsMap = new map<string,EngagementFrequencySettings__c>(); 
    public integer monthsRecent;
    public integer monthsMedium;
    private date cutoffDateRecent;
    private date cutoffDateMedium; 
    private integer NewMbrLvl;
    private integer RetMbrLvl;

    // these fieldlists are static so that static methods called from triggers can access them
    // all of these fields will be blanked out on insert (clone)
    static final string CON_FIELDS_ET_EDITABLE = 'Engagement_Level__c,Engagement_Peak__c,Engagement_Level_Numeric__c,Engagement_Peak_Numeric__c,First_Action_Date_Curr_Level__c,' +
									   			 'Engagement_Level_Override__c,Engagement_Override_End_Date__c,Last_Leadership_Action_Date__c,'; 
	static final string CON_FIELDS_ET_READONLY = 'Engagement_Level_Override_Numeric__c,'; 
    
    /*******************************************************************************************************
	* @description This constructor is needed to allow this class to be schedulable.
	*/
    global GW_BATCH_EngagementRollup() { }
    
    
    /*******************************************************************************************************
	* @description Main constructor.  The arg should be set to true only in a test.
	*/
    global GW_BATCH_EngagementRollup (boolean isTestArg) {
        isTest = isTestArg;
        //DH GW_OppRollups.isTest = isTestArg;
        getSettingParams();
        constructQuery();
    }
    
    /*******************************************************************************************************
	* @description Standard schedulable execute method.  This simply gets the batch started when called from a scheduled job.  Note, this uses a batch size of 50 unless
	*  a different batch size is given in the settings.
	*/    
    global void execute(SchedulableContext SC) {
                 
        integer batchSize = 50;  // default
        if (settings.Batch_Size__c > 0) {
            batchSize = settings.Batch_Size__c.intvalue(); 
        }
         
        GW_BATCH_EngagementRollup ladderBatch = new GW_BATCH_EngagementRollup(false);
        id batchinstanceid = database.executeBatch (ladderBatch, batchSize);  
    }
    
    /*******************************************************************************************************
	* @description Loads an instance of EngagementTrackerSettings__c, creating one with useful defaults
	* if one isn't found.
	*/   
	//public class MyException extends Exception {}
	 
    public static EngagementTrackerSettings__c settings {
        get {
            if (settings == null) {
                settings = EngagementTrackerSettings__c.getOrgDefaults();  
                
                if (settings == null) {
           			// MatthewS felt that if no settings exist, we should give an error to the user,
           			// but DaveH found that this was too easily hit in GWBase instances that will always have this ET, even if not being used.
            		//throw(new MyException('Engagement Tracker requires Engagement Tracker Settings to have been created.  Please create these custom settings.'));
            		settings = new EngagementTrackerSettings__c();
            		// set values code assumes exist
                    settings.Timeframe_Medium__c = 18;
                    settings.Timeframe_Recent__c = 12;
           		}            
            }
            return settings;
        }
        
        set;
    }
    
    protected void getSettingParams() {

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
        
    	// first ET fields
        string querySOQL = 'SELECT Id,Name,' + CON_FIELDS_ET_EDITABLE + CON_FIELDS_ET_READONLY;
        querySOQL = addAllNSPrefixET(querySOQL,true,false);

        // then fields w/ same name in gwbase & NPSP
        string querySOQLmore = 'OppAmountLastNDays__c,LastCloseDate__c,LastCloseDateHH__c,OppsClosedLastNDays__c,' +
        						'OppAmountThisYear__c, OppAmountLastYear__c, OppAmount2YearsAgo__c,Account.Name,Account.OppAmountLastNDays__c,Account.LastCloseDate__c,' +
	        					'MembershipJoinDate__c,MembershipEndDate__c,LastMembershipLevel__c,LastMembershipOrigin__c,LastMembershipDate__c,LastMembershipAmount__c,';
        querySOQLmore = addAllNSPrefixET(querySOQLmore,false,true);
        querySOQL += ',' + querySOQLmore; 
        
        if (IsGWBaseInstalled) {
        	// then fields that exist only in gwbase
        	querySOQLmore = ' Best_Gift_Year__c,Best_Gift_Year_Total__c,OppAmountLastNDaysHH__c, ' + 
        							'ONEN_Household__c,ONEN_Household__r.OppsClosedLastNDays__c,ONEN_Household__r.Best_Gift_Year__c,ONEN_Household__r.Best_Gift_Year_Total__c,' +
									'HouseholdMembershipEndDate__c,';
        	querySOQLmore = addAllNSPrefixET (querySOQLmore,false,true);
        	querySOQL += ',' + querySOQLmore;
        } else if (IsNPSPHHInstalled)	{
        	// and finally fields that only exist in NPSP
			querySOQLmore = 
				'Household__c,' +
				'Household__r.OppAmountLastNDays__c,' +
				'Household__r.OppAmountThisYear__c, Household__r.OppAmountLastYear__c, Household__r.OppAmount2YearsAgo__c,' +
				'Household__r.OppsClosedLastNDays__c, Household__r.LastMembershipDate__c,';
			querySOQLmore = addAllNSPrefixET (querySOQLmore,false,true);
			querySOQL += ',' + querySOQLmore;
		} 
        
        // include any checkbox fields from settings in the query
        if (fieldSettingsMap.size()>0) {
            for (EngagementContactFieldSettings__c s : fieldSettingsMap.values() ) {
                querySOQL += ',' + s.Fieldname__c ; 
            }
        }
        // querySOQL = querySOQL.substring(0,querySOQL.length()-1);   //lop off trailing comma
        
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
	* @description Standard batch start method.   This doesn't do anything interesting.  
	*/    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(Query);
    }

    /*******************************************************************************************************
	* @description The main batch execute method.  This is where the majority of the real work is done for the engagement calculation.  This method looks at custom settings, 
	*  and then all related Campaigns and Opps for each contact, to determine the correct score to assign.  It only makes a write to the contact if any of the rollup fields need changing.  
	*/
    global void execute(Database.BatchableContext BC, List<Sobject> SBatch){
        system.debug (Logginglevel.WARN,'running execute!');
        Map<id,Contact> conMap = new Map<id,Contact>();
        Map<id,engTrackConWrapper> conWrapMap = new Map<id,engTrackConWrapper>();
        set<id> conIDs = new set<id>();       
        Contact[] consToUpd = new Contact[0]; 
        
        cutoffDateRecent = system.today().addMonths(monthsRecent * -1);
        cutoffDateMedium = system.today().addMonths(monthsMedium * -1);
        
        // cast sobjects to Contacts, and add to wrappers & maps        
        for (sobject s: SBatch) {
            Contact con = (Contact)s;
            system.debug (Logginglevel.WARN,'con before cals: ' + con);
            system.debug (Logginglevel.WARN,'con member end date: ' + con.MembershipEndDate__c);
            system.debug (Logginglevel.WARN,'con member origin: ' + con.LastMembershipOrigin__c);
            conIDs.add(con.Id);
            engTrackConWrapper cw = new engTrackConWrapper(con.Id);
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
        
        system.debug (Logginglevel.WARN,'conwrapper map before calcs: ' + conWrapMap);
        
        // grab opp rollup data and store data on the contact wrapper object
        if (settings.Include_Opps__c || settings.Include_Membership__c) {
        	CalculateOppData(conWrapMap, conIDs);
        }
        

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
                    engTrackConWrapper cw;
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
                    engTrackConWrapper cw = conWrapMap.get(conid);
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
                qstr = addAllNSPrefixET (qstr,true,false);
                // fields coming from settings we can't assume should be namespace prefixed.
                qstr +=         ' AND Campaign.' + fqset.Fieldname_1__c + '= \'' + fqset.Field_Value_1__c + '\' ';
                qstr +=         addAllNSPrefixET(' GROUP BY ROLLUP ( ContactId, Calendar_Year(Effective_Action_Date__c) )' , true, false);
                //system.debug (Logginglevel.WARN,'querystring: ' + qstr);
                sobject[] results = Database.query(qstr);
                for (sobject row : results) {
                    double count = (double)row.get('CountCMs');
                    if (row.get('subtCon')==0 && row.get('yr')==null && count >= fqset.Number_Of_Actions_Required__c) {
                        // if this is con row, and we meet the frequency criteria, assign lvl to con as appropriate
                        Id conid = (id)row.get('ContactId');
                        engTrackConWrapper cw = conWrapMap.get(conid);
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
                        engTrackConWrapper cw = conWrapMap.get(conid);
                        if (fqset.Level_To_Assign__c > cw.PeakLvl) {
                            cw.PeakLvl = fqset.Level_To_Assign__c.intvalue();
                        }
                    }
                }
            }
        }
    
        // now loop back through our contacts and apply contact-centric level rules
        for (engTrackConWrapper cw : conWrapMap.values() ) {
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
                    decimal recentGiftTtl = cw.OppAmountLastNDays_c; 
                    decimal recentGiftTtlHH = cw.OppAmountLastNDaysHH_c;
                    double lvlRecent; 
                    double lvlPeak;
                    for (integer i=0;i<donorBreakpoints.size();i++) {
                        //system.debug(Logginglevel.WARN, 'i=: ' + i);
                        decimal brkpt = donorBreakpoints[i];
                        integer lvl = donorLvlMap.get(brkpt).intvalue();
                        // award the level if either this contact made it on "personal" gifts (where they were primary contact)...
                        if (recentGiftTtl >= brkpt && lvl > cw.CurrLvl) {
                            cw.CurrLvl = lvl;
                            cw.LastActionDate = cw.LastCloseDate_c;
                            if (cw.OppsClosedLastNDays_c==1) {
                                cw.FirstActionDateInLvl = cw.LastCloseDate_c;     // if only 1 gift, last is also the first
                            } else {
                                // TBD we could add this con to a list, and then query for the actual first date??
                                cw.FirstActionDateInLvl = cutoffDateRecent;  // b/c level is awarded for entire year, not one gift
                            }
                        //  ...or for HH gifts, but only if they have at some point been awarded a level on their own, for any other reason
                        //      the reasoning being that that makes it more likely the gift is really from the family/couple and not just the primary con 
                        } else if  (recentGiftTtlHH > brkpt && (cw.CurrLvl > 0 || cw.PeakLvl > 0) && lvl > cw.CurrLvl )  {
                            cw.CurrLvl = lvl;
                            cw.LastActionDate = cw.LastCloseDateHH_c;
                            if (cw.OppsClosedLastNDaysHH_c==1) {
                                cw.FirstActionDateInLvl = cw.LastCloseDateHH_c;
                            } else {
                                cw.FirstActionDateInLvl = cutoffDateRecent;
                            }
                        // assign lastaction date even if we don't give the level, as long as they already had a date (i.e. level not due to override or chkbox)
                        //  and this date is more recent
                        } else if (cw.Best_Gift_Year_Total_c > 0 && cw.LastCloseDate_c > cw.LastActionDate && cw.LastActionDate!=null) {
                            cw.LastActionDate = cw.LastCloseDate_c;
                        }
                        // for peak level, look at best year calcs
                        //  as above, we're willing to take it from the HH if this contact has credits from anything else ever
                        if ( lvl > cw.PeakLvl && 
                            ( cw.Best_Gift_Year_Total_c >= brkpt || (cw.Best_Gift_Year_TotalHH_c >= brkpt && (cw.CurrLvl > 0 || cw.PeakLvl > 0)) ) 
                        ) {
                            cw.PeakLvl = lvl;
                        }
                    }
                }
            }
           
            // now figure membership
            if (settings.Include_Membership__c && (cw.MembershipEndDate_c!=null || cw.HouseholdMembershipEndDate_c!=null) && RetMbrLvl!=null && NewMbrLvl!=null) {
                integer mbrlvl;
                if (cw.LastMembershipOrigin_c=='Renewal' || cw.LastMembershipDate_c > cw.MembershipJoinDate_c) {
                    mbrlvl = RetMbrLvl;
                } else {
                    mbrlvl = NewMbrLvl;
                }
                if (cw.LastMembershipDate_c >= cutoffDateRecent && mbrlvl > cw.CurrLvl) cw.CurrLvl = mbrlvl;
                if (mbrlvl > cw.PeakLvl) cw.PeakLvl = mbrlvl;  
            }   
           
            //system.debug (Logginglevel.WARN,'conwrapper map after calcs: ' + conWrapMap);
            
            // do any final custom processing implemented via override
            customFinalLvlAssign (conWrapMap, conIDs);
        
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
	* @description Go through the contacts' opportunities, and cache a bunch of donor and membership related
	* data.
	*/      
	private	void CalculateOppData(Map<id,engTrackConWrapper> conWrapMap, set<id> conIDs) {
		
            for (engTrackConWrapper cw : conWrapMap.values()) {
				Contact con = cw.con;    				      	
		        
			// these fields have the same name in gwbase & npsp, just have to mind the prefix  
	        cw.OppAmountLastNDays_c = (decimal)con.get( addNSPrefixET('OppAmountLastNDays__c',false,true) );		        
	        cw.LastCloseDate_c = (date)con.get( addNSPrefixET('LastCloseDate__c',false,true) );
	        cw.OppsClosedLastNDays_c = (decimal)con.get( addNSPrefixET('OppsClosedLastNDays__c',false,true) );
	        cw.LastCloseDateHH_c = (date)con.get( addNSPrefixET('LastCloseDateHH__c',false,true) );
	        cw.MembershipEndDate_c = (date)con.get( addNSPrefixET('MembershipEndDate__c',false,true) );
	        cw.LastMembershipOrigin_c = (string)con.get( addNSPrefixET('LastMembershipOrigin__c',false,true) );
	        cw.LastMembershipDate_c = (date)con.get( addNSPrefixET('LastMembershipDate__c',false,true) );
	        cw.MembershipJoinDate_c = (date)con.get( addNSPrefixET('MembershipJoinDate__c',false,true) );
	        
	        if (IsGWBaseInstalled) {
	        	// these fields are only in gwbase (for now) or have different names
		        cw.Best_Gift_Year_Total_c = (decimal)con.get( addNSPrefixET('Best_Gift_Year_Total__c',false,true) );
		        cw.OppAmountLastNDaysHH_c = (decimal)con.get( addNSPrefixET('OppAmountLastNDaysHH__c',false,true) );
		        cw.HouseholdMembershipEndDate_c = (date)con.get( addNSPrefixET('HouseholdMembershipEndDate__c',false,true) );
				sObject hh = con.getSObject(addNSPrefixET('ONEN_Household__r',false,true) );  
				if (hh != null) {
		        	cw.Best_Gift_Year_TotalHH_c = (decimal)hh.get(addNSPrefixET('Best_Gift_Year_Total__c',false,true));
		        	cw.OppsClosedLastNDaysHH_c = (decimal)hh.get(addNSPrefixET('OppsClosedLastNDays__c',false,true));
				}
	        } else if (IsNPSPHHInstalled)	{
		        // estimate this for now, until npsp implements best gift year
		        decimal d1 = (decimal)con.get('npo02__OppAmountThisYear__c');
		        decimal d2 = (decimal)con.get('npo02__OppAmountLastYear__c');
		        decimal d3 = (decimal)con.get('npo02__OppAmount2YearsAgo__c');
		        cw.Best_Gift_Year_Total_c = math.max(d1 == null ? 0 : d1,
		        		math.max(d2 == null ? 0 : d2,
		        			d3 == null ? 0 : d3));

				sObject hh = con.getSObject('npo02__Household__r');  
				if (hh != null) {
					// npsp doesn't roll up some HH metrics to the contact
			        cw.OppAmountLastNDaysHH_c = (decimal)hh.get('npo02__OppAmountLastNDays__c');		        
			        cw.OppsClosedLastNDaysHH_c = (decimal)hh.get('npo02__OppsClosedLastNDays__c');
			        cw.HouseholdMembershipEndDate_c = (date)hh.get('npo02__LastMembershipDate__c');
			        
			        // estimate this for now.
			        d1 = (decimal)hh.get('npo02__OppAmountThisYear__c');
			        d2 = (decimal)hh.get('npo02__OppAmountLastYear__c');
			        d3 = (decimal)hh.get('npo02__OppAmount2YearsAgo__c');
			        cw.Best_Gift_Year_TotalHH_c = math.max(d1 == null ? 0 : d1,
			        		math.max(d2 == null ? 0 : d2,
			        			d3 == null ? 0 : d3));
				}
            }            
		}		
	}
 
    
    /*******************************************************************************************************
	* @description an empty hook method intended for overriding - this will get called once all of the regular logic has been run and all contacts in the batch have been asssigned
	*  an engagement level (in memory only, not yet written to database)
	*  This gives developers an opportunity to tweak the levels according to custom logic before those levels get written
	*  In order to utilize this, extend the engagementRollup class, override this method, and then schedule the subclass to run, and disable any schedules using the superclass
	*/      
    global virtual void customFinalLvlAssign (Map<id,engTrackConWrapper> conWrapMap, set<id> conIDs){
        
    }
    

    

    /*******************************************************************************************************
	* @description The standard batch finish method.  Currently does nothing.
	*/      
    global void finish(Database.BatchableContext BC){
        
    }

    


    /* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ */
    
    // NAMESPACE PREFIX METHODS
    
    public static string addNSPrefixET (string str, boolean isETField, boolean isNP02Field) {
	     if (str.endsWith('__c') || str.endsWith('__r') ) {
	     	if (str.contains('.')) {
	     		// if we're passed a related field w/ object notation, recurse and do each part of the fieldname separately
	     		// that's because if we may need namespace on both the relationship and the fieldname
	     		// for example in npo02 we need npo02__Household__r.npo02__MembershipEndDate__c
	     		string[] strParts = str.split('\\.');	// need to escape the dot char since this is regex
	     		string newString = '';
	     		for (string s : strParts) {
	     			newString += addNSPrefixET(s,isETField,isNP02Field) + '.';
	     		}
	     		newString = newString.substring(0,newString.length()-1);   //lop off trailing period
	     		return newString;
	     	} else {
				if (isETField) {
					// for fields that are part of ET (like the level fields in contact and campaign)
					// possibilities are:
					// * GWET prefix (ET package installed in NPSP context, or ET package dev instance)
					// * GWBase prefix (GWBase installed, or GWBase package dev instance)
					// * no prefix (unmanaged context, e.g. git clone of GWBase)
					if (InETPackage) {
						return 'GWET__' + str;
					} else {
						return GW_Utilities.StrTokenNSPrefix(str);
					}
				} else {
					// OTOH, if the fields is not part of ET, but rather part of either GWBase or NPSP (like opp rollup fields)
					// possibilities are:
					// * np02 or npe01 prefix (NPSP package installed - which prefix depends on which package the field is in)
					// * GWBase prefix (NPSP not installed, GWBase installed or GWBase package dev instance)
					// * no prefix (as above)
					// note that we don't allow for the case of a developer/unmanaged instance of NPSP, since we (GW) never work in that context
					if (IsNPSPHHInstalled) {
						if (isNP02Field) {
							return 'npo02__' + str;
						} else {
							return 'npe01__' + str;
						}
					} else {
						return GW_Utilities.StrTokenNSPrefix(str);
					}
				}
	     	}
	     } else {
		     return str;
	     }
	     
	}
		    
    private static string addAllNSPrefixET (string str,boolean isETFields, boolean isNP02Fields) {
		string[] fields = str.split(',');
		string newString = '';
		for (string s:fields) {
			s = s.trim();
			newString += addNSPrefixET (s,isETFields,isNP02Fields) + ',';
		}
		newString = newString.substring(0,newString.length()-1);   //lop off trailing period
		return newString;
	}
		    
	private static boolean fCheckedForNPSPHH = false;
	public static boolean IsNPSPHHInstalled {
		get {
			if (!fCheckedForNPSPHH) {
				Schema.SObjectType token = Schema.getGlobalDescribe().get('npo02__Household__c');
				IsNPSPHHInstalled = (token != null);
				fCheckedForNPSPHH = true;
			}
			return IsNPSPHHInstalled;
		}
		set;
	}
		    
	private static boolean fCheckedForGWBase = false;
	public static boolean IsGWBaseInstalled {
		get {
			if (!fCheckedForGWBase) {
				Schema.SObjectType token = Schema.getGlobalDescribe().get('ONEN_Household__c');
				IsGWBaseInstalled = (token != null);
				fCheckedForGWBase = true;
			}
			return IsGWBaseInstalled;
		}
		set;
	}
		
	private static boolean CheckedForETPkg = false;
	public static boolean InETPackage {
		get {
			if (!CheckedForETPkg) {
				// first try to look up a ET object using ET pkg namespace - this should only work in an installed (i.e. client) instance
				Schema.SObjectType token = Schema.getGlobalDescribe().get('GWET__EngagementTrackerSettings__c');
				if (token != null) {
					InETPackage = true;
					CheckedForETPkg = true;
				} else {
					// if this doesn't work, we are either in the ET dev instance itself, or in an unmanaged developer instance (git clone)
					// the former still needs to include the prefixes, while the latter needs to not include them
					// in order to tell the difference, try a dynamic query w/ the prefix and see if we get an err
					string soql = 'SELECT Id,GWET__Engagement_Level__c FROM Contact LIMIT 1';
					try {
						SObject[] recs = database.query(soql);
					} catch (exception e) {
						system.debug ('err: ' + e.getMessage() );
						InETPackage = false;
						CheckedForETPkg = true;
					} finally {
						if (!CheckedForETPkg) {
							InETPackage = true;
							CheckedForETPkg = true;
						}
					}
				}
			}
			return InETPackage;
		}
		set;
	}
	
	
	public static void BlankETConFields (list<Contact> cons) {
		// called from before insert trigger
		// blank out all ET fields on contact on insert
		// this is done to prevent problems when contact is cloned, since some fields are semi-persistent
		// e.g. peak level won't drop once it's set
		// and as long as we're nulling some it's less confusing for user if we null them all
		string fieldList = addAllNSPrefixET(CON_FIELDS_ET_EDITABLE,true,false);
		string[] fieldnames = fieldList.split(',');
		for (Contact con : cons) {
			for (string fieldname : fieldnames) {
				con.put(fieldname , null);
			}
		}
	}
	
	
    /* ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ */

    
    // *** WRAPPER CLASS **************************************************************
    
    
    global class engTrackConWrapper {
        private id conId;
        global Contact con;
        
        global integer CurrLvl=0;
        global integer PeakLvl=0;
        global date LastActionDate;
        global date FirstActionDateInLvl;
        
        // our cache of Opp Rollup data
        global decimal OppAmountLastNDays_c;
        global decimal OppAmountLastNDaysHH_c;
        global date LastCloseDate_c;
        global decimal OppsClosedLastNDays_c;
        global date LastCloseDateHH_c;
        global decimal OppsClosedLastNDaysHH_c;
        global decimal Best_Gift_Year_Total_c;
        global decimal Best_Gift_Year_TotalHH_c;
        
        // our cache of membership data
        global date MembershipEndDate_c;
        global date HouseholdMembershipEndDate_c;
        global string LastMembershipOrigin_c;
        global date LastMembershipDate_c;
        global date MembershipJoinDate_c;

        //constructor 
        public engTrackConWrapper (id argId) {
            conId = argId;  
        }   

    }

    // called from the Contact before trigger
    public static void ContactEngagementLvlOverride() {    
        // when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
        // can't do this w/ workflow due to limitations in date arithmetic
        
        Contact[] cons = new Contact[0];
        integer months = (settings.Override_Default_Duration__c==null) ? settings.Timeframe_Recent__c.intvalue() : 
        	settings.Override_Default_Duration__c.intvalue();
        
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

        settings.Include_Opps__c = IsNPSPHHInstalled || IsGWBaseInstalled; 
        settings.Timeframe_Recent__c = 12;
        settings.Timeframe_Medium__c = 12;
        settings.Include_Membership__c = IsNPSPHHInstalled || IsGWBaseInstalled;
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
            Fieldname_1__c = 'Type',
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
            1 => addNSPrefixET('Level_1_Name__c',true,false) , 
            2 => addNSPrefixET('Level_2_Name__c',true,false) , 
            3 => addNSPrefixET('Level_3_Name__c',true,false) , 
            4 => addNSPrefixET('Level_4_Name__c',true,false) , 
            5 => addNSPrefixET('Level_5_Name__c',true,false) , 
            6 => addNSPrefixET('Level_6_Name__c',true,false) , 
            7 => addNSPrefixET('Level_7_Name__c',true,false) , 
            8 => addNSPrefixET('Level_8_Name__c',true,false) };
        
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

        // note: in addition to this batch process, this test relies on the GW_ContactTriggerBefore trigger
        string txtfield1 = 'Title';
        double txtfield1lvl = 6;
        string txtfield1FV = 'Board Member';
        setSettingsForTests(txtfield1, txtfield1FV, txtfield1lvl);  
        
        integer howMany = 23;
        Date datClose = System.Today();
        string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
        string MbrRectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
        integer monthsRecent = settings.Timeframe_Recent__c.intvalue();
        integer monthsMedium = settings.Timeframe_Medium__c.intvalue();
        date startDateRecent = datClose.addMonths((monthsRecent*-1)+1);
        date startDateMedium = datClose.addMonths((monthsMedium*-1)+1);
        date startDateOld = datClose.addMonths((monthsMedium*-1)-12);
        date giftYearStartDate = datClose.addMonths((monthsRecent*-1));
        date cutoffDateRecent = system.today().addMonths(monthsRecent * -1);
        
        
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
                
        TestCons[5].Title = 'Board Member'; 
        TestCons[10].Engagement_Level_Numeric__c = 3;  
        TestCons[10].Engagement_Peak_Numeric__c = 3;  
        // TestCons[10].Engagement_Level_Mod_Date__c = system.today().addMonths(-2);
        TestCons[21].Email = 'test@test.com';   // this should give lvl 1
        
        insert TestCons;
        
        // now add 2 new contacts who are in existing households
        Contact[] consHH = ONEN_UnitTestData.CreateMultipleTestContactsInHouseholds(new list<Contact> {TestCons[16], TestCons[17]});
        consHH[0].FirstName = '16Spouse';
        consHH[1].FirstName = '17Spouse';
        insert consHH;
               
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
                Type = 'Online Action'
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
            //ContactId = TestCons[20].Id,
            ContactId = consHH[1].Id,
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

		// we need to bracket opp code with startTest and stopTest so that npsp rollups will
		// get processed (they must use future calls)
		test.startTest();
		
        // create new opps
        double smallAmt = donorBreakpoints[1] - 5; // assumes at least $5 of separation, good assumption I hope!
        double majAmt = donorBreakpoints[2] - 5;   // also assumes at least 3 lvls
        Contact[] ConsForSmallOpps = new Contact[]{TestCons[6],TestCons[7],TestCons[8],TestCons[9],TestCons[10],TestCons[12],TestCons[13],TestCons[16]};
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
            opp.put( addNSPrefixET('Membership_Start_Date__c',false,false), opp.CloseDate);
            opp.put( addNSPrefixET('Membership_End_Date__c',false,false), opp.CloseDate.AddYears(1)); 
	    }	        
        // note that we also made sure contact 12 and 13 (those with membership),
        // have normal gift opps, to work around a bug in NPSP where they wouldn't
        // rollup membership opps if membership was in the excluded set, and the contact
        // had no other opps.

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
        ID batchprocessid = Database.executeBatch(myba);
        Test.StopTest();

        Id[] ConIDs = new Id[0];
        for (Contact con : TestCons) {
            ConIDs.add(con.Id);
        }
        for (Contact con : consHH) {
            ConIDs.add(con.Id);
        }
        
        // query for all the cons we started with
        map<Id,Contact> conP = new map<Id,Contact> ([SELECT Id,Name,Engagement_Level__c,Engagement_Level_Numeric__c,Engagement_Peak__c,Engagement_Peak_Numeric__c,
            Last_Leadership_Action_Date__c,First_Action_Date_Curr_Level__c,Engagement_Level_Override__c,Engagement_Level_Override_Numeric__c,Engagement_Override_End_Date__c
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
            Contact con19P = conP.get(consHH[0].Id);
            System.AssertEquals(0,con19P.Engagement_Level_Numeric__c);        
            System.AssertEquals(0,con19P.Engagement_Peak_Numeric__c);
            System.AssertEquals(null,con19P.Last_Leadership_Action_Date__c);
              
            // HH mbr other activity, should get HH donation credit
            Contact con20P = conP.get(consHH[1].Id);
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
            System.Assert(startDateRecent == con12P.First_Action_Date_Curr_Level__c ||
            	cutoffDateRecent == con12P.First_Action_Date_Curr_Level__c);
    
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