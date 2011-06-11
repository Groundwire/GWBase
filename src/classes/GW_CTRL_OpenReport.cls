// Written by Dave Habib, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

public with sharing class GW_CTRL_OpenReport {
	
	//---------------------------------------------------------------------------------------------
	// Main routine that gets invoked as a page action to redirect to open the specified report.
	// note that it expects a DeveloperName, and it will append any Url parameters to the report,
	// so that you can filter the report.
	//---------------------------------------------------------------------------------------------
	public PageReference OpenReportDevName() {
		string strDevName = ApexPages.currentPage().getParameters().get('ReportDevName');
		if (strDevName == null || strDevName == '') {
			return null;
		}
				
		//redirect to newly created opp in edit mode
		ID reportId = GW_Utilities.reportIdFromDevName(strDevName);
		if (reportId != null) {
			string strParams = ApexPages.currentPage().getUrl();
			integer iparams = strParams.indexOf('?');
			if (iparams >= 0){
				strParams = strParams.substring(iparams);
			} else {
				strParams = '';
			}
			PageReference page = new PageReference('/' + reportId + strParams);
        	page.setRedirect(true);
        	return page;
		} 
		
		return null;		
	}
 

	//---------------------------------------------------------------------------------------------
	// TEST CODE
	//---------------------------------------------------------------------------------------------

	static testmethod void TestOpenReport() {
		PageReference pageRef = Page.OpenReport; 
		Test.setCurrentPage(pageRef); 

		// test no parameters
		GW_CTRL_OpenReport ctrl = new GW_CTRL_OpenReport();
		system.assertEquals(null, ctrl.OpenReportDevName());	

		// test null parameters
		ApexPages.currentPage().getParameters().put('ReportDevName', null);
		ctrl = new GW_CTRL_OpenReport();
		system.assertEquals(null, ctrl.OpenReportDevName());	

		// test bogus parameters
		ApexPages.currentPage().getParameters().put('bogus', 'bogus');
		ctrl = new GW_CTRL_OpenReport();
		system.assertEquals(null, ctrl.OpenReportDevName());	

		// test bad report name parameters
		ApexPages.currentPage().getParameters().put('ReportDevName', 'bogus report');
		ctrl = new GW_CTRL_OpenReport();
		system.assertEquals(null, ctrl.OpenReportDevName());	

		// test good report name parameters
		ApexPages.currentPage().getParameters().put('ReportDevName', 'ONEN_Campaign_List_Simple');
		ctrl = new GW_CTRL_OpenReport();
		system.assertNotEquals(null, ctrl.OpenReportDevName());	
	}
	
}