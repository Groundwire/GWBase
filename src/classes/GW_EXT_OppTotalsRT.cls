public class GW_EXT_OppTotalsRT {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class calculates opportunity fiscal year totals for display in a small VF "pagelet."
*
* Each row has Fiscal Year, Amount for each record type up to 8, and Total
* The "grand total" row has the word "Total" and the total for each column
-----------------------------------------------------------------------------------------------*/

	// subclass represents a row of totals for displaying in a list
	public class OppTotals {
		public string oppYear { get; set; }
		public decimal rt1 { get; set; }
		public decimal rt2 { get; set; }
		public decimal rt3 { get; set; }
		public decimal rt4 { get; set; }
		public decimal rt5 { get; set; }
		public decimal rt6 { get; set; } 
		public decimal rt7 { get; set; }
		public decimal rt8 { get; set; }
		public decimal totalAmount { get; set; } 
		
		OppTotals(string s) { 
			oppYear = s; 
			totalAmount = rt1 = rt2 = rt3 = rt4 = rt5 = rt6 = rt7 = rt8 = 0.00;
		}		
	} 

	// these properties allow you to display the totals in a table on the page
	public list<OppTotals> detailRows { get; set; }
	public OppTotals totalRow { get; set; }
	public string header1 { get; set; }
	public string header2 { get; set; }
	public string header3 { get; set; }
	public string header4 { get; set; }
	public string header5 { get; set; }
	public string header6 { get; set; }
	public string header7 { get; set; }
	public string header8 { get; set; }

	// use settings to limit the opp types you include in your rollups 
	set<id> recordTypesToExcludeAccts = new set<id>();
	set<id> recordTypesToExcludeCons = new set<id>();
	set<string> oppTypesToExcludeAccts = new set<string>();
	set<string> oppTypesToExcludeCons = new set<string>();	
		
	// set this to limit contact totals to opps with a specific 'bucket' account
	final string defaultAccountId = ONEN_DefaultAccount.getIndividualAccountId();

	// id of the object on the page
	id objectId;

	// constructor 
	public GW_EXT_OppTotalsRT(ApexPages.StandardController stdController) {

		// load settings
        OppRollupSettings__c rollupSettings = OppRollupSettings__c.getInstance();

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
				oppTypesToExcludeAccts = new set<string>(rollupSettings.Excluded_Contact_Opp_Types__c.split(';'));
			}
		}

		// we need to build the rows for the result table
		map<string, OppTotals> allRows = new map<string, OppTotals>();
		list<string> rownames = new list<string>();
		list<string> rtNames = new list<string>();
			
		objectId = stdController.getId();
		if (objectId != null) {	
		
			// store the results here
			list<sObject> rollups;
			
 			if (stdController.getRecord().getSObjectType() == Account.sObjectType) { 
				rollups = [SELECT Fiscal_Year(CloseDate) FiscalYear, recordTypeId rtype,
			     	SUM(Amount) TotalOppAmount
			     	FROM Opportunity 
			    	WHERE isWon=true 
			    	AND (Amount > 0 OR Amount < 0) 
			    	AND RecordTypeId NOT IN : recordTypesToExcludeAccts
			    	AND Type NOT IN : oppTypesToExcludeAccts
	    			AND accountId = : objectId
					GROUP BY CUBE(Fiscal_Year(closeDate), RecordTypeId)			
					ORDER BY Fiscal_Year(CloseDate) DESC ];
 			} else if (stdController.getRecord().getSObjectType() == Contact.sObjectType) {
				rollups = [SELECT Fiscal_Year(Opportunity.CloseDate) FiscalYear, Opportunity.recordTypeId rtype,
			     	SUM(Opportunity.Amount) TotalOppAmount 
			     	FROM OpportunityContactRole 
			    	WHERE isPrimary=true AND opportunity.isWon=true 
			    	AND (Opportunity.Amount > 0 OR Opportunity.Amount < 0) 
			    	AND Opportunity.RecordTypeId NOT IN : recordTypesToExcludeCons
			    	AND Opportunity.Type NOT IN : oppTypesToExcludeCons
					AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null)  
	    			AND contactId = : objectId 
					GROUP BY CUBE(Fiscal_Year(opportunity.closeDate), Opportunity.recordTypeId)
					ORDER BY Fiscal_Year(Opportunity.CloseDate) DESC ];
			} else {
				rollups = [SELECT Fiscal_Year(Opportunity.CloseDate) FiscalYear, Opportunity.recordTypeId rtype,
			     	SUM(Opportunity.Amount) TotalOppAmount 
			     	FROM OpportunityContactRole 
			    	WHERE isPrimary=true AND opportunity.isWon=true 
			    	AND (Opportunity.Amount > 0 OR Opportunity.Amount < 0) 
			    	AND Opportunity.RecordTypeId NOT IN : recordTypesToExcludeCons
			    	AND Opportunity.Type NOT IN : oppTypesToExcludeCons
					AND (opportunity.accountid = : defaultAccountId OR opportunity.accountid = null)  
	    			AND contact.ONEN_Household__c = : objectId 
					GROUP BY CUBE(Fiscal_Year(opportunity.closeDate), Opportunity.recordTypeId) 
					ORDER BY Fiscal_Year(Opportunity.CloseDate) DESC ];
			}
	
			// the "current" year might actually be named for next year
			integer fyAdjustment = 0;
			// you can optionally comment the following 2 lines out if you know FY starts in Jan (or is named for start month)
			organization o = [select fiscalYearStartMonth, UsesStartDateAsFiscalYearName from organization limit 1];
			if (o.FiscalYearStartMonth > 1 && !o.UsesStartDateAsFiscalYearName) fyAdjustment = 1;

			// process the aggregate results
			integer i = 0;
			list<string> recordTypes = new list<string>();
			set<string> recordTypeSet = new set<string>();
			for (sobject r : rollups) {
				//system.debug('ROLLUP ROW: ' + r);

				// get the year for this row
				integer fy = (integer)(r.get('FiscalYear'));
				
				// null year means this is the totals row
				string row = (fy != null) ? string.valueOf(fy + fyAdjustment) : 'Total';
				
				// get or create the totals object for this result row
				if (!allrows.containsKey(row)) {
					allrows.put(row, new oppTotals(row));
					rownames.add(row);
				}
				oppTotals thisRow = allrows.get(row);
				 
				// fill the right field
				decimal rtAmt = (decimal)(r.get('TotalOppAmount'));
				if (r.get('rtype') != null) {
					
					// get the record type name and amount
					string rtName = GW_RecTypes.GetRecordTypeName('Opportunity', (id)(r.get('rtype')));
					
					// if this is a new record type, add a column
					if (!recordTypeSet.contains(rtName)) {
						recordTypes.add(rtName);
						recordTypeSet.add(rtName);
					}
					
					// put these in the correct column
					if (recordTypes[0] == rtName) {
						header1 = rtName;
						thisRow.rt1 = rtAmt;
					} else if (recordTypes.size() > 1 && recordTypes[1] == rtName) {
						header2 = rtName;
						thisRow.rt2 = rtAmt;
					} else if (recordTypes.size() > 2 && recordTypes[2] == rtName) {
						header3 = rtName;
						thisRow.rt3 = rtAmt;
					} else if (recordTypes.size() > 3 && recordTypes[3] == rtName) {
						header4 = rtName;
						thisRow.rt4 = rtAmt;
					} else if (recordTypes.size() > 4 && recordTypes[4] == rtName) {
						header5 = rtName;
						thisRow.rt5 = rtAmt;
					} else if (recordTypes.size() > 5 && recordTypes[5] == rtName) {
						header6 = rtName;
						thisRow.rt6 = rtAmt;
					} else if (recordTypes.size() > 6 && recordTypes[6] == rtName) {
						header7 = rtName;
						thisRow.rt7 = rtAmt;
					} else if (recordTypes.size() > 7 && recordTypes[7] == rtName) {
						header8 = rtName;
						thisRow.rt8 = rtAmt;
					}
					i++;
				} else {
					thisRow.totalAmount = rtAmt;
				}
			}
				
			detailRows = new list<OppTotals>();
			for (string row : rownames) {
				
				// add it to the list
				if (row != 'Total') {
					detailRows.add(allRows.get(row));
				} else {
					totalRow = allRows.get(row);
				}
			}
		}
	}

	static testMethod void testFYTotalsRT () {
		
		Date datClose = System.Today();
			
		// create & insert contact(s)
		Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( 5 ) ;
		insert TestCons;

		Test.StartTest();

		// create new opps
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Closed Won', datClose, 100 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);
		insert newOpps;

		account testacct = new account(name='testacct');
		insert testacct;
		id FirstConId = TestCons[4].id;
		Contact UpdatedCon = [SELECT id, account.TotalOppAmount__c, OppAmountThisYear__c, OppAmountLastYear__c, onen_household__c, TotalOppAmount__c FROM Contact WHERE Id = :FirstConId];

		GW_EXT_OppTotalsRT fyt;

		// create a page to test account totals
		fyt = new GW_EXT_OppTotalsRT(new ApexPages.StandardController(testacct));

		System.AssertEquals ( 0, fyt.detailRows.size());
		System.AssertEquals ( null, fyt.totalRow);

		// create a page to test contact totals
		fyt = new GW_EXT_OppTotalsRT(new ApexPages.StandardController(UpdatedCon));

		System.AssertEquals ( 100, fyt.detailRows[0].totalAmount);
		System.AssertEquals ( 100, fyt.totalRow.totalAmount);

		// create a page to test household totals
		fyt = new GW_EXT_OppTotalsRT(new ApexPages.StandardController(new ONEN_Household__c(id = UpdatedCon.ONEN_Household__c)));

		System.AssertEquals ( 100, fyt.detailRows[0].totalAmount);
		System.AssertEquals ( 100, fyt.totalRow.totalAmount);

		Test.StopTest();
	}	
}