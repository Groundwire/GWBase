public class ONEN_EXT_OppListExport {
// Written by Matthew Scholtz, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public List<Opportunity> selectedOpps;
	public List<OpportunityContactRole> finalOpps;
	
	
	public string testreturl {get;set;}
	map<string,string> testparams = new map<string,string>(); 

	public ONEN_EXT_OppListExport(ApexPages.StandardSetController controller) {
      	this.selectedOpps = (List<Opportunity>)controller.getSelected();
      	queryOpps();
      	/*
      	// filterId = '00B80000006diAZ';
      	controller.setFilterId('00B80000006diAZ');
      	this.testreturl = System.currentPageReference().getParameters().get('retURL');
      	*/
      	
      	
      	this.testparams = System.currentPageReference().getParameters();
      	system.debug ('testparams:' + testparams);
      	
      	system.debug ('selectedOpps' + selectedOpps);
	}
	
	private void queryOpps() {
		// tbd make this dynamic apex w/ list of fields in list custom setting??
		finalOpps = [SELECT Contact.FirstName,Contact.LastName,Contact.Primary_Address_Household_Name__c,Contact.Primary_Address_Household_Greeting__c,
			Contact.Primary_Address_Name_Block_HH__c,Contact.Primary_Street__c,Contact.Primary_City__c,Contact.Primary_State_Province__c,
			Contact.Primary_Postal_Code__c,Contact.Primary_Country__c,Contact.Primary_Address_Org_Name__c,Contact.Primary_Address_Title__c,
			Opportunity.Amount,Opportunity.CloseDate,Opportunity.RecordType.Name
			FROM OpportunityContactRole WHERE Opportunity.Id IN :selectedOpps AND IsPrimary=True];
	} 
	
	public list<OpportunityContactRole> getSelectedOpps() {
		return finalOpps;
	}
	
	static testmethod void testNada () {		
		ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
			Database.getQueryLocator([SELECT id FROM Opportunity limit 1]));
		ONEN_EXT_OppListExport ext = new ONEN_EXT_OppListExport(sc); 

	}
	
}