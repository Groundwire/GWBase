public with sharing class GW_CTRL_MarkCampaignHHDupes {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* controller for Mark Campaign Household Duplicates visualforce page
* page should be called with parameter as follows:
*   /apex/CampaignHHDedupe?id=[campaign-id]
*
* the page displays a link to a campaign report - or simply redirects to that report if there
* are 1000 or fewer records and no duplicates to mark or unmark
* 
* for the report to use, you pass the report Developer Name to the page:
*   /apex/CampaignHHDedupe?id=[campaign-id]&reportDevName=[developer-name-of-report]
-----------------------------------------------------------------------------------------------*/

	// properties for page
	public boolean noCampaignId { get; private set; }
	public boolean batching { get; private set; }
	public integer dupesFound { get; private set; }
	public integer totalContacts { get; private set; }
	public string reportURL { get; private set; }
	public string reportDevName { get; private set; }

	// object id passed in via parameter
	string objectId;
	id cmpid;
	id lastHHid;

	public boolean isTest = false;
	public boolean useBatch = false;
	
	// constructor
	public GW_CTRL_MarkCampaignHHDupes() {
		batching = false;			

		// get parameter if any
		try {
			objectId = ApexPages.currentPage().getParameters().get('id');
			cmpid = objectId;
			reportDevName = ApexPages.currentPage().getParameters().get('reportDevName');
			if (reportDevName == null) reportDevName = 'Campaign_Household_Mailing_List';
			reportURL = '/' + GW_Utilities.reportIdFromDevName(reportDevName);	
		} catch (exception e) {		
		}  		
		noCampaignId = (cmpid == null); 
		if (reportURL != null && objectid != null) 
			reportURL += '?pc7=CAMPAIGN_ID&pn7=eq&pv7=' + objectid;
	}
	
	public PageReference startAction() {
		PageReference ref;
		if (cmpid != null) {

			list<campaignMember> cms = 
				[SELECT id, contact.onen_household__c, household_duplicate__c FROM campaignmember
				WHERE campaignid = :cmpid AND contact.onen_household__c != null 
				ORDER BY contact.onen_household__c, contact.createddate limit 1000];
			
			// can we do this without batch?
			if (cms.size() < 1000  && !useBatch) {
				totalContacts = cms.size();
				dupesFound = 0;			
				list<campaignMember> cmsForUpdate = new list<campaignMember>();
				for (campaignMember cm : cms) {
					id thisHHid = cm.contact.onen_household__c;
					boolean isDupe = (thisHHid == lastHHid);
					if (isDupe) dupesFound += 1;
					if (cm.household_duplicate__c != isDupe)
						cmsForUpdate.add( new CampaignMember( id = cm.id, household_duplicate__c = isDupe ) );							
					lastHHid = thisHHid;
				} 		
				// if no changes, redirect to the report
				if (cmsForUpdate.isEmpty() && reportURL != null)
					ref = new PageReference(reportURL);
				else 
					update cmsForUpdate;
			
			} else {
				// run the batch process for the specified campaign
				GW_BATCH_MarkCampaignHHDupes bcc = new GW_BATCH_MarkCampaignHHDupes();
				
				// set the batch query text
				bcc.query = GW_Utilities.StrAllNSPrefix('SELECT id, contact.onen_household__c FROM campaignmember ' +
					'WHERE campaignid = \'' + cmpid + '\' AND contact.onen_household__c != null ' +
					'ORDER BY contact.onen_household__c, contact.createddate');
				if (isTest) bcc.query += ' limit 200'; 

				id batchProcessId = database.executeBatch(bcc);
				batching = true;
 			}
		}
		return ref;
	}

/* not used!
    public PageReference cancel() {
        PageReference ref = new PageReference('/home/home.jsp');
        ref.setRedirect(true);
        return ref;
    }
*/
	public static testMethod void testDedupe() {

		// create test data
		Contact[] testCons = New list<contact> ();
		
		for (integer i=0;i<50;i++) {
			Contact newCon = New Contact (
				FirstName = 'Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
			);
			testCons.add (newCon);
		}
		insert testCons;		
		Contact[] testConHHs = [select id, onen_household__c from contact where id in : testCons limit 8];
		
		Contact[] testCons2 = New list<contact> ();
		for (integer i=0;i<10;i++) {
			Contact newCon = New Contact (
				FirstName = 'Spouse' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle',
				onen_household__c = testConHHs[((i<8) ? i : 7)].onen_household__c
			);
			testCons2.add (newCon);
		}
		insert testCons2;		

		lead ld = new lead(lastname = 'nobody');
		insert ld;
		
		Campaign cmp0 = new Campaign (
			Name='Target',
			IsActive=true
		);
		insert cmp0;

		// add a few contacts to each campaign - some should overlap
		campaignmember[] cms = new campaignmember[0];
		for (integer i = 0; i < 50; i++) {
			cms.add(new campaignmember(campaignId = cmp0.Id, contactId = testCons[i].id));
		}
		for (integer i = 0; i < 10; i++) {
			cms.add(new campaignmember(campaignId = cmp0.Id, contactId = testCons2[i].id));
		}
		cms.add(new campaignmember(campaignId = cmp0.Id, leadId = ld.id));					

		insert cms;
		
		Test.startTest();
	 		
		// create the page 
		PageReference pageRef=Page.CampaignHHDedupe; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('id', cmp0.id);
		ApexPages.currentPage().getParameters().put('reportDevName', 'Campaign_Household_Mailing_List');
		
		// instantiate the controller
		GW_CTRL_MarkCampaignHHDupes controller=new GW_CTRL_MarkCampaignHHDupes();

		// run the page
		pageReference nextref = controller.startAction();

		// check properties
		system.assertEquals(false, controller.batching);
		system.assertEquals(10, controller.dupesFound);
		system.assertEquals(60, controller.totalContacts);
		system.assert(controller.reportURL.startsWith('/00O'));
		system.assertEquals(null, nextref);

		// make sure 10 out of 60 got marked dupe
		campaignmember[] cm1 = [SELECT id FROM campaignmember WHERE campaignid = : cmp0.id AND household_duplicate__c = false];
		campaignmember[] cm2 = [SELECT id FROM campaignmember WHERE campaignid = : cmp0.id AND household_duplicate__c = true];
		system.assertEquals(51, cm1.size());
		system.assertEquals(10, cm2.size());

		test.stopTest();
		
		// do it again
		pageReference nextref2 = controller.startAction();		

		// check properties
		system.assertEquals(false, controller.batching);

		// page ref should have changed this time
		system.assertEquals(controller.reportURL, nextref2.getURL());
		
	}
	
	public static testMethod void testBatchDedupe() {

		// create test data
		Contact[] testCons = New list<contact> ();
		
		for (integer i=0;i<50;i++) {
			Contact newCon = New Contact (
				FirstName = 'Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
			);
			testCons.add (newCon);
		}
		insert testCons;		
		Contact[] testConHHs = [select id, onen_household__c from contact where id in : testCons limit 8];
		
		Contact[] testCons2 = New list<contact> ();
		for (integer i=0;i<10;i++) {
			Contact newCon = New Contact (
				FirstName = 'Spouse' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle',
				onen_household__c = testConHHs[((i<8) ? i : 7)].onen_household__c
			);
			testCons2.add (newCon);
		}
		insert testCons2;		

		lead ld = new lead(lastname = 'nobody');
		insert ld;
		
		Campaign cmp0 = new Campaign (
			Name='Target',
			IsActive=true
		);
		insert cmp0;

		// add a few contacts to each campaign - some should overlap
		campaignmember[] cms = new campaignmember[0];
		for (integer i = 0; i < 50; i++) {
			cms.add(new campaignmember(campaignId = cmp0.Id, contactId = testCons[i].id));
		}
		for (integer i = 0; i < 10; i++) {
			cms.add(new campaignmember(campaignId = cmp0.Id, contactId = testCons2[i].id));
		}
		cms.add(new campaignmember(campaignId = cmp0.Id, leadId = ld.id));					

		insert cms;
		
		Test.startTest();
	 			 		
		// create the page 
		PageReference pageRef=Page.CampaignHHDedupe; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('id', cmp0.id);
		
		// instantiate the controller
		GW_CTRL_MarkCampaignHHDupes controller=new GW_CTRL_MarkCampaignHHDupes();
		controller.isTest = true;
		controller.useBatch = true;

		// rollup the contact
		pageReference nextref = controller.startAction();		
		
		// this is critical - otherwise no test runs
		Test.stopTest();		

		// make sure we are batching
		system.assertEquals(true, controller.batching);
		system.assertEquals(null, nextref);

		// make sure 10 out of 60 got marked dupe
		campaignmember[] cm1 = [SELECT id FROM campaignmember WHERE campaignid = : cmp0.id AND household_duplicate__c = false];
		campaignmember[] cm2 = [SELECT id FROM campaignmember WHERE campaignid = : cmp0.id AND household_duplicate__c = true];
		system.assertEquals(51, cm1.size());
		system.assertEquals(10, cm2.size());
	}
	
}