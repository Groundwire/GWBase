public virtual class ONEN_CampaignMemberStatus {
// Written by Matthew Scholtz, copyright (c) 2009 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    public static void addDefaultStatuses (list<Campaign> camps) {
        
        // run from trigger
        // given a new campaign with a particular type/subtype, assign starting statuses by default
        
        //system.debug ('running addDefaultStatuses!');
        
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        List<Campaign> campaignsToDeleteDefaultStatuses = new List<Campaign>();
        Map<id,Set<string>> CMStoStatusesMap = new Map<id,Set<string>>();
        Map<id,integer> maxSortOrderMap = new Map<id,integer>();
        List<CampaignMemberStatus> existingStatuses = new List<CampaignMemberStatus>([select id, CampaignId, Label, SortOrder from CampaignMemberStatus where CampaignId IN :camps ORDER BY id]);
        Set<string> statusesToAdd = new Set<string>();
                
        //populate a map with all of the campaign ids to a list of new or existing statuses in that campaign.
        //we create this map to check if statuses exist to prevent an exception from cloning a campaign (cloning statuses)
        for (CampaignMemberStatus thisStatus : existingStatuses) {
            if (CMStoStatusesMap.get(thisStatus.CampaignId) == null) {
                statusesToAdd = new Set<string>();
                statusesToAdd.add(thisStatus.Label);
                CMStoStatusesMap.put(thisStatus.CampaignId, statusesToAdd);
            } else {
                statusesToAdd = CMStoStatusesMap.get(thisStatus.CampaignId);
                statusesToAdd.add(thisStatus.Label);
                CMStoStatusesMap.put(thisStatus.CampaignId, statusesToAdd);
            }
            // also keep track of max sort order for each campaign
            integer sortOrd = thisStatus.SortOrder;
            if (maxSortOrderMap.get(thisStatus.CampaignId) == null || maxSortOrderMap.get(thisStatus.CampaignId) < sortOrd ) {
            	maxSortOrderMap.put(thisStatus.CampaignId,sortOrd);
            }
        }
        
        // get default status settings from custom setting object
        map<string,Campaign_Mbr_Status_Settings__c> allSettings = Campaign_Mbr_Status_Settings__c.getAll();
        
        //loop through campaigns and add statuses if they don't exist already
        for (Campaign camp : camps) {
            // integer i = (math.random() * 100).intvalue();
            for (Campaign_Mbr_Status_Settings__c setting : allSettings.values()) {
                if (setting.Campaign_Type__c==camp.Type && 
                (setting.Campaign_SubType__c==camp.Campaign_Sub_Type__c || setting.Campaign_SubType__c==null) ) {
                    if ( !CMStoStatusesMap.get(camp.Id).contains(setting.Status_Label__c)) {
                        CampaignMemberStatus cm = new CampaignMemberStatus(
                            CampaignId = camp.Id,
                            Label = setting.Status_Label__c,
                            HasResponded = setting.IsResponded__c,
                            IsDefault = setting.Default_Status__c,
                            SortOrder = maxSortOrderMap.get(camp.Id) + 1
                        );
                        newStatuses.add(cm);
                        maxSortOrderMap.put(camp.Id,cm.SortOrder);                     
                    }
                }
            }
        }
        
        if ( newStatuses.size() > 0 ) {
            insert newStatuses;
        }
        //get all the old default statuses and delete them
        // TBD is this working??
        List<CampaignMemberStatus> oldStatuses = new List<CampaignMemberStatus>([select id, label from CampaignMemberStatus where CampaignId IN :campaignsToDeleteDefaultStatuses and (label = 'Sent' or label = 'Responded')]);
        if ( oldStatuses.size() > 0 && newStatuses.size() > 0 ) {
            delete oldStatuses; 
        }       
    }

/* NO LONGER USED    
    private virtual class campStatusMapping {
        // class to represent a campaign type/subtype, and the default status(es) to be created 
        public string ctype;
        public string csubtype;
        public defaultCampStatus[] statuses = new defaultCampStatus[0];
        
        // constructor
        public campStatusMapping (string ctypearg,string csubtypearg) {
            this.ctype = ctypearg;
            this.csubtype = csubtypearg;
        }
        
        public void addStatus (defaultCampStatus status) {
            statuses.add(status);
        }
        
    }
    
    private virtual class defaultCampStatus {
        public string status;
        public boolean isResponded;
        public boolean isDefault;
    }
*/


    public static boolean CheckCMStatusExistsBulk (set<id> CampIDs, string Status, boolean requireResponded ) {
        
        map <id,CampaignMemberStatus> CampStatusMap = new Map <id,CampaignMemberStatus> ();
        boolean isSuccess = false;
        list<CampaignMemberStatus> CMSToUpdate = new list<CampaignMemberStatus> ();
        list<CampaignMemberStatus> CMSToInsert = new list<CampaignMemberStatus> ();
        Map<id,integer> maxSortOrderMap = new Map<id,integer>();
        
        // query all CMStatus where status matches and campid is in the list
        // modified 3/17/11 - MMS - instead, query for all statuses for the campaigns (to get max sort order), then later loop through to see if the status we want
        // is included
        CampaignMemberStatus[] CMSFound = [Select CampaignId, Label, HasResponded, SortOrder From CampaignMemberStatus WHERE CampaignId IN :CampIDs ];
        
        // add to map <campId,cmstatus obj>
        for ( CampaignMemberStatus thisCMS : CMSFound ) {
        	if (thisCMS.Label == Status) {
	            CampStatusMap.put ( thisCMS.CampaignId , thisCMS );
        	}
            integer sortOrd = thisCMS.SortOrder;
            if (maxSortOrderMap.get(thisCMS.CampaignId) == null || maxSortOrderMap.get(thisCMS.CampaignId) < sortOrd ) {
            	maxSortOrderMap.put(thisCMS.CampaignId,sortOrd);
            }
        }
                
        // loop through original list of campid's
        for ( id CampId : CampIDs ) {
            
            CampaignMemberStatus thisCMS = CampStatusMap.get(CampId);
            
            if ( thisCMS != null ) {
                // if in map, see if existing one is responded (if required)
                // (if so, do nothing)
                if ( thisCMS.HasResponded == false && requireResponded == true ) {
                    // if not, chg it so it is (add to list of changes)
                    thisCMS.HasResponded = true;
                    CMSToUpdate.add (thisCMS);  
                }
            } else {
                // if not in map, status doesn't exist, so add to list of inserts

				// integer i = (math.random() * 100).intvalue();		// deprecated - instead of random number, assign next sequential integer
				
				CampaignMemberStatus newCMS = new CampaignMemberStatus (
					CampaignId = CampId,
					Label = Status,
					HasResponded = requireResponded,
					SortOrder = maxSortOrderMap.get(CampId) + 1
                );
                CMSToInsert.add (newCMS);
                maxSortOrderMap.put(CampId,newCMS.SortOrder);
            }
        }
        
        // do inserts
        if ( CMSToInsert.size () > 0 ) {
            insert CMSToInsert; 
        }
        
        // do updates
        if ( CMSToUpdate.size () > 0 ) {
            update CMSToUpdate; 
        }
        
        isSuccess = true;
        
        return isSuccess;
    
    }


	/* deprecated 3/17/11 MMS - don't believe this method is used anywhere, and hasn't been for some time - all use the bulk method above
    public static boolean CheckCMStatusExists (Id campId, string CMStatus, boolean isResponded ) {
    
        //original method, one rec only
    
        // for a given Campaign, look to see if a CM Status w/ given name exists
        // if not, create it
        // also require it to be IsResponded if that param is set, chg that if necessary(!!)
    
        boolean statusExists;
        
        CampaignMemberStatus[] cStatus = [Select c.Label, c.HasResponded From CampaignMemberStatus c WHERE c.CampaignId = :campId AND c.Label = :CMStatus ];            
        
        If ( cStatus.size () > 0 ) {
            // if we found a rec (should only return 1 rec, if any)
            // then require it to be Responded if necessary
            
            if (isResponded == True && cStatus[0].HasResponded != True ) {
                // chg status to HasResponded   
            }
            
            statusExists = True;
            
        } else {
            
            // if status doesn't exist, create it
            
            // TBD first have to look up what the SortOrder should be for this new status
            // should make it last
            // for now, just set it to a high number
            integer i = (math.random() * 100).intvalue();
            
            CampaignMemberStatus newCMStatus = new CampaignMemberStatus (
                Label = CMStatus,
                CampaignId = campId,
                HasResponded = isResponded,
                SortOrder = (i < 79) ? i + 20 : i
            );
            
            insert newCMStatus;
            
            statusExists = True;
        }
        
        return statusExists;    
    
    }
    */

/*
    public static string GetRespondedStatus (Id campId) {
    
        // for a given campaign, look up the 'default' status to use for Responded
        // not used currently, may be able to delete
        
        string s;
    
        // first get list of all the statuses w/ HasResponded (should never be empty set)
        CampaignMemberStatus[] cStatus = [Select c.Label, c.IsDefault From CampaignMemberStatus c WHERE c.CampaignId = :campId And c.HasResponded = True ORDER BY c.IsDefault desc];    

        If ( cStatus[0].IsDefault == True ) {
            //if there's a default status that's Responded, use that
            s = cStatus[0].Label;
        } Else {
            // else use 'Responded', if it exists for this camp.
            For ( CampaignMemberStatus eachStatus : cStatus ) {
                If ( eachStatus.Label == 'Responded' ) s = eachStatus.Label;
            }   
            // otherwise, just use the first one queried, at random
            If ( s == Null ) s = cStatus[0].Label;
        }
        
        return s;
    }
*/

////////////////////////////////////////////////////////////
// TEST CODE
////////////////////////////////////////////////////////////

    private static boolean settingsDoneForTests = false; 

    static void setDefaultSettings() {
        // for tests


        // temporarily commented out due to bug 
        // see http://community.salesforce.com/sforce/board/message?board.id=apex&thread.id=23399
        // for now relies on actual settings data being in there that matches the below 
        // so for new installations, will need to install & populate settings obj before migrating this code
        
        if (settingsDoneForTests==False) {
            // first delete any existing settings so there's no conflict
            Campaign_Mbr_Status_Settings__c[] oldsettings = Campaign_Mbr_Status_Settings__c.getAll().values();
            Campaign_Mbr_Status_Settings__c[] setsDel = new Campaign_Mbr_Status_Settings__c[0];
            
            
            for (Campaign_Mbr_Status_Settings__c setting : oldsettings) {
                //Campaign_Mbr_Status_Settings__c oldset = new Campaign_Mbr_Status_Settings__c (id=setting.id);
                setsDel.add(setting);
            }
            
            
            Campaign_Mbr_Status_Settings__c set1 = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest1',
                Campaign_Type__c = 'Communication',
                Campaign_Subtype__c = 'Email',
                Status_Label__c = 'Opened',
                IsResponded__c = True,
                Default_Status__c = false
            );
            insert set1; 

            Campaign_Mbr_Status_Settings__c set1a = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest1a',
                Campaign_Type__c = 'Communication',
                Campaign_Subtype__c = 'Email',
                Status_Label__c = 'Clicked',
                IsResponded__c = True,
                Default_Status__c = false
            );
            insert set1a; 

            Campaign_Mbr_Status_Settings__c set1b = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest1b',
                Campaign_Type__c = 'Communication',
                Campaign_Subtype__c = 'Email',
                Status_Label__c = 'Unsubscribed',
                IsResponded__c = false,
                Default_Status__c = false
            );
            insert set1b; 

            Campaign_Mbr_Status_Settings__c set1c = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest1c',
                Campaign_Type__c = 'Communication',
                Campaign_Subtype__c = 'Email',
                Status_Label__c = 'Bounced',
                IsResponded__c = false,
                Default_Status__c = false
            );
            insert set1c; 

            Campaign_Mbr_Status_Settings__c set2 = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest2',
                Campaign_Type__c = 'Event',
                Campaign_Subtype__c = '',
                Status_Label__c = 'Invited',
                IsResponded__c = false,
                Default_Status__c = True
            );
            insert set2; 

            Campaign_Mbr_Status_Settings__c set3 = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest3',
                Campaign_Type__c = 'Event',
                Campaign_Subtype__c = '',
                Status_Label__c = 'Attended',
                IsResponded__c = True,
                Default_Status__c = false
            );
            insert set3; 

            Campaign_Mbr_Status_Settings__c set4 = new Campaign_Mbr_Status_Settings__c (
                Name = 'fooTest4',
                Campaign_Type__c = 'Appeal',
                Campaign_Subtype__c = '',
                Status_Label__c = 'Donated',
                IsResponded__c = True,
                Default_Status__c = false
            );
            insert set4; 
    
            
            system.debug('oldsettings:' + oldsettings);
            system.debug('setsDel' + setsDel);
            if (setsDel.size()>0) delete setsDel;
            
            settingsDoneForTests = True;
        }
    }

    public static testmethod void testEmailStatuses() {
        
        //system.debug('latest code!!');
        
        setDefaultSettings();
        
        //create a campaign that WON'T trip the trigger to ensure that all of the statuses
        //exist in the CampaignMemberStatus table -- to prevent test errors when statuses don't
        //already exist in production.
        Campaign newCampaign = new Campaign (
            Name = 'Bogus_Campaign'             
        );
        insert newCampaign;
        
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        
        integer i = (math.random() * 100).intvalue();
        CampaignMemberStatus statusOne = new CampaignMemberStatus(
                Label = 'Opened',
                CampaignId = newCampaign.id,
                HasResponded = true,
                SortOrder = 300
        );
        newStatuses.add(statusOne);     

        CampaignMemberStatus statusTwo = new CampaignMemberStatus(
            Label = 'Clicked',
            CampaignId = newCampaign.id,
            HasResponded = true,
            SortOrder = 301
        );
        newStatuses.add(statusTwo);     

        CampaignMemberStatus statusThree = new CampaignMemberStatus(
            Label = 'Unsubscribed',
            CampaignId = newCampaign.id,
            HasResponded = false,
            SortOrder = 302
        );
        newStatuses.add(statusThree);
        
        CampaignMemberStatus statusFour = new CampaignMemberStatus(
            Label = 'Bounced',
            CampaignId = newCampaign.id,
            HasResponded = false,
            SortOrder = 303
        );
        newStatuses.add(statusFour);
        
        try { // unfortunately we know that this will fail if status's have never been created from the Salesforce UI!!!
	        if ( newStatuses.size() > 0 ) {
	            insert newStatuses;
	        }
        } catch (Exception e) {}
                
        // Insert a new campaign with CampaignSub-Type 'Email' to test the trigger
        // TBD these tests should set settings so doesn't rely on user settings
        Campaign newCampaign1 = new Campaign (
            Name = 'New Campaign',
            Type = 'Communication',
            Campaign_Sub_Type__c = 'Email'               
        );
        
        test.startTest();
        insert newCampaign1;
        test.stopTest();
    
        // Verify that the new Campaign Member Status 'Opened' has been created
        CampaignMemberStatus newStatusOne = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Opened' limit 1];
        System.assertEquals('Opened', newStatusOne.Label);
        
        // Verify that the new Campaign Member Status 'Clicked' has been created
        CampaignMemberStatus newStatusTwo = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Clicked' limit 1];
        System.assertEquals('Clicked', newStatusTwo.Label);
        
        // Verify that the new Campaign Member Status 'Unsubscribed' has been created
        CampaignMemberStatus newStatusThree = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Unsubscribed' limit 1];
        System.assertEquals('Unsubscribed', newStatusThree.Label);
        
        // Verify that the new Campaign Member Status 'Unsubscribed' has been created
        CampaignMemberStatus newStatusFour = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Bounced' limit 1];
        System.assertEquals('Bounced', newStatusFour.Label);
    }
    
    public static testmethod void testAppealStatuses() {

        setDefaultSettings();
        //create a campaign that WON'T trip the trigger to ensure that all of the statuses
        //exist in the CampaignMemberStatus table -- to prevent test errors when statuses don't
        //already exist in production.
        Campaign newCampaign = new Campaign (
            Name = 'Bogus_Campaign'             
        );
        insert newCampaign;
        
        //   deprecated // integer i = (math.random() * 100).intvalue();
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        CampaignMemberStatus statusFive = new CampaignMemberStatus(
                Label = 'Donated',
                CampaignId = newCampaign.id,
                HasResponded = false,
                SortOrder = 300
            );
            newStatuses.add(statusFive);
        
        if ( newStatuses.size() > 0 ) {
            insert newStatuses;
        }
        
        // Insert a new campaign with Campaign Type 'Appeal' to test
        Campaign newCampaign2 = new Campaign (
            Name = 'New Campaign',
            Type = 'Appeal'              
        );
        // and also another one w/ a sub-type, to make sure that doesn't trip us up
        Campaign newCampaign3 = new Campaign (
            Name = 'New Campaign 3',
            Type = 'Appeal',              
            Campaign_Sub_Type__c = 'Special Appeal'              
        );
    
        insert new Campaign[]{newCampaign2,newCampaign3};
    
        // Verify that the new Campaign Member Status 'Donated' has been created
        CampaignMemberStatus[] newStatusFive = [select CampaignId, Label from CampaignMemberStatus where (CampaignId=:newCampaign2.id or CampaignId=:newCampaign3.id) and Label = 'Donated'];
        System.assertEquals(2, newStatusFive.size());
        
    }
    
    public static testmethod void testEventStatuses() {

        setDefaultSettings();

        //create a campaign that WON'T trip the trigger to ensure that all of the statuses
        //exist in the CampaignMemberStatus table -- to prevent test errors when statuses don't
        //already exist in production.
        Campaign newCampaign = new Campaign (
            Name = 'Bogus_Campaign'             
        );
        insert newCampaign;
        
        // integer i = (math.random() * 100).intvalue();   // deprecated
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        CampaignMemberStatus statusSix = new CampaignMemberStatus(
                Label = 'Invited',
                CampaignId = newCampaign.id,
                HasResponded = false,
                SortOrder = 300
        );
        newStatuses.add(statusSix);
        
        CampaignMemberStatus statusSeven = new CampaignMemberStatus(
            Label = 'Attended',
            CampaignId = newCampaign.id,
            HasResponded = true,
            SortOrder = 301
        );
        newStatuses.add(statusSeven);
        
        try { // unfortunately we know that this will fail if status's have never been created from the Salesforce UI!!!
	        if ( newStatuses.size() > 0 ) {
	            insert newStatuses;
	        }
        } catch (Exception e) {}
        
        
        // Insert a new campaign with Campaign Type 'Appeal' to test
        Campaign newCampaign3 = new Campaign (
            Name = 'New Campaign',
            Type = 'Event'               
        );
    
        insert newCampaign3;
    
        // Verify that the new Campaign Member Status 'Invited' has been created
        CampaignMemberStatus newStatusSix = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign3.id and Label = 'Invited' limit 1];
        System.assertEquals('Invited', newStatusSix.Label);
        
        // Verify that the new Campaign Member Status 'Attended' has been created
        CampaignMemberStatus newStatusSeven = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign3.id and Label = 'Attended' limit 1];
        System.assertEquals('Attended', newStatusSeven.Label);
        
    }

/*
	public static testmethod void testCheckCMStatusExists() {
		// test singular version
		Campaign cmp = new Campaign(Name='Test Campaign Foo');
		insert cmp;
		System.Assert(cmp.Id != null);
		list<CampaignMemberStatus> listCM = [select Id, CampaignId, Label from CampaignMemberStatus where CampaignId = :cmp.Id and Label = 'test status'];
		System.AssertEquals(0, listCM.size());
		System.AssertEquals(true, CheckCMStatusExists(cmp.Id, 'test status', false));					
		listCM = [select Id, CampaignId, Label from CampaignMemberStatus where CampaignId = :cmp.Id and Label = 'test status'];
		System.AssertEquals(1, listCM.size());
		System.AssertEquals(true, CheckCMStatusExists(cmp.Id, 'test status', true));					
	}
*/
	
	public static testmethod void testCheckCMStatusExistsBulk() {
		// test bulk version
		set<ID> setIdCM = new set<ID>();
		integer i;
		for (i = 1; i <= 5; i++) {		
			Campaign cmp = new Campaign(Name='Test Campaign Foo' + i);
			insert cmp;
			System.Assert(cmp.Id != null);
			setIdCM.add(cmp.Id);
		}
		
		list<CampaignMemberStatus> listCM = [select Id, CampaignId, Label from CampaignMemberStatus where CampaignId in :setIdCM and Label = 'test status'];
		System.AssertEquals(0, listCM.size());
		System.AssertEquals(true, CheckCMStatusExistsBulk(setIdCM, 'test status', false));					
		listCM = [select Id, CampaignId, Label from CampaignMemberStatus where CampaignId in :setIdCM and Label = 'test status'];
		System.AssertEquals(5, listCM.size());		
		System.AssertEquals(true, CheckCMStatusExistsBulk(setIdCM, 'test status', true));					
	}
}