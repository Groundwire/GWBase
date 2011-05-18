public class ONEN_CTRL_WebToLead {
// Written by Dave Manelski, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public Lead lead { 
		get {
			if (lead == null) lead = new Lead();
			return lead;
		}
		
		set; 
	}
	
	public PageReference Save() {
		if (lead.Company == null) lead.Company = '[not provided]'; 
		insert lead;
		StrSaveResult = 'Your information has been saved.  Thank you.';
		lead = null;	// so fields get reset to null.
		return null;
	}
	
	public String StrSaveResult { get; set; }
	
	public PageReference insertLead() {
		Map<string,string> postParameters = ApexPages.currentPage().getParameters();
		
		if (!postParameters.isEmpty()) {
			Lead newLead = new Lead();
			newLead.FirstName = ApexPages.currentPage().getParameters().get('First_Name');
			
			//hard code [not provided] for people without last names or company
			if (ApexPages.currentPage().getParameters().get('Last_Name')==null || ApexPages.currentPage().getParameters().get('Last_Name')=='') {
				newLead.LastName = '[not provided]';
			} else {
				newLead.LastName = ApexPages.currentPage().getParameters().get('Last_Name');
			}
			
			if (ApexPages.currentPage().getParameters().get('Organization')==null || ApexPages.currentPage().getParameters().get('Organization')=='') {
				newLead.LastName = '[not provided]';
			} else {
				newLead.Company = ApexPages.currentPage().getParameters().get('Organization');
			}
	
			newLead.Email = ApexPages.currentPage().getParameters().get('Email');
			newLead.Home_Phone__c = ApexPages.currentPage().getParameters().get('Home_Phone');
			newLead.MobilePhone = ApexPages.currentPage().getParameters().get('Mobile');
			newLead.LeadSource = ApexPages.currentPage().getParameters().get('Lead_Source');
			if (ApexPages.currentPage().getParameters().get('Email_Opt_Out') != null) {
				newLead.HasOptedOutOfEmail = ApexPages.currentPage().getParameters().get('Email_Opt_Out').contains('true');
			}
			newLead.Campaign_Id__c = ApexPages.currentPage().getParameters().get('Campaign_Id');
			newLead.Campaign_Member_Status__c = ApexPages.currentPage().getParameters().get('Campaign_Member_Status');
			newLead.Home_Street__c = ApexPages.currentPage().getParameters().get('Home_Street');
			newLead.Home_City__c = ApexPages.currentPage().getParameters().get('Home_City');
			newLead.Home_State__c = ApexPages.currentPage().getParameters().get('Home_State');
			newLead.Home_PostalCode__c = ApexPages.currentPage().getParameters().get('Home_PostalCode');
			
			insert newLead;
		}
		
		return null;
	}
	
	//==================== TEST METHOD(s) ======================================
	static testmethod void CodeCoverageTests() {

		PageReference pageRef=Page.webtolead; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('Last_Name', 'Chekov');

		//instantiate the controller 
		ONEN_CTRL_WebToLead ctrl = new ONEN_CTRL_WebToLead();

		ctrl.insertlead();
		
		Lead lead = ctrl.lead;
		System.Assert(lead != null);
		lead.FirstName = 'TestFirstName';
		lead.LastName = 'TestLastName';
		ctrl.Save();
		System.AssertEquals('Your information has been saved.  Thank you.', ctrl.StrSaveResult);
	}	
}