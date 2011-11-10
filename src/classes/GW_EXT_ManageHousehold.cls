// Written by David Habib, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author David Habib
* @date 11/05/2011
* @description This class is the controller extension for the Household Members visual force pagelet
* that is displayed on the Household layout.
*
*/
public with sharing class GW_EXT_ManageHousehold {

	public ONEN_Household__c hh { get; set; }

	public CampaignMember cm { get; set; } // used for contact lookup on page
	
	public list<Contact> listContact { 
		get {
			if (listContact == null) {
		        listContact = [select contact.Id, contact.Name, Account.Name, Email,
		        	OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry,
		        	Home_County__c, HomePhone, Title, Phone
		        	from Contact where ONEN_Household__c = :hh.Id];		
	        }
	        return listContact;
		}
		
		set; 
	}
	
    public GW_EXT_ManageHousehold(ApexPages.StandardController controller) {
        hh = (ONEN_Household__c)controller.getRecord();
    }

	public GW_EXT_ManageHousehold() {
        //conid = (Contact)controller.getRecord();
        //hh = (ONEN_Household__c)controller.getRecord();
    }
    
    public PageReference ManageHousehold() {
    	string conid = ApexPages.CurrentPage().getParameters().get('id');
    	
    	Contact[] conhh = [SELECT Id, Name, ONEN_Household__c FROM Contact WHERE Id=:conid];
    	if (conhh.size() > 0) {
    		if (conhh[0].ONEN_Household__c != NULL) {
    			PageReference redirect = new PageReference('/'+conhh[0].ONEN_Household__c);
				redirect.setRedirect(true);
				return redirect;
    		} else {
    			hh = new ONEN_Household__c();
    			insert hh;
    			
    			conhh[0].ONEN_Household__c = hh.id;
    			update conhh[0];
    			
    			PageReference newhh = new PageReference('/'+hh.id);
    			newhh.setRedirect(true);
    			return newhh;
    		}
    	}
    	return null;
    }

	public PageReference AddExistingContact() {
		listContact.add(new Contact());
		cm = new CampaignMember();
		return null;
	}
	
	public PageReference SaveEdit() {
		Contact con = [select Id, ONEN_Household__c, OtherStreet, OtherCity, OtherState,
			OtherPostalCode, OtherCountry, Home_County__c from Contact where Id =: cm.contactId];
		con.ONEN_Household__c = hh.Id;
		
		// use first contact's address.
		Contact conSrc = listContact[0];
		con.OtherStreet = conSrc.OtherStreet;
		con.OtherCity = conSrc.OtherCity;
		con.OtherState = conSrc.OtherState;
		con.OtherPostalCode = conSrc.OtherPostalCode;
		con.OtherCountry = conSrc.OtherCountry;
		con.Home_County__c = conSrc.Home_County__c;		
		update con;

		// the above refresh was nice to keep the new person at the end of the list,
		// but it wouldn't refresh the other contacts.
		listContact = null;				
		return null;
	}	
	
	public PageReference CancelEdit() {
		listContact.remove(listContact.size()-1);
		return null;
	}	
	
	public PageReference RemoveContact() {
		String removeId = ApexPages.currentPage().getParameters().get('removeId');	
		Contact con = [select Id, ONEN_Household__c from Contact where Id =:removeId];
		con.ONEN_Household__c = null;
		update con;	
		listContact = null;
		return null;
	}
	
	// TEST METHODS
	public static testmethod void TestHHMembers() {
		Contact con1 = new Contact(
			firstname = 'bart',
			lastname = 'simpson',
			OtherCity = 'Bellevue'
		);		
		insert con1;
		con1 = [select Id, name, ONEN_Household__c from Contact where Id =: con1.Id];
		system.assert(con1.ONEN_Household__c != null);
		ONEN_Household__c hh = [select Id from ONEN_Household__c where Id =: con1.ONEN_Household__c];
		system.assert(hh.Id != null);
		
		Contact con2 = new Contact(
			firstname = 'homer',
			lastname = 'simpson'
		);		
		insert con2;
		
        PageReference pageRef = new PageReference(hh.Id);
        Test.setCurrentPageReference(pageRef);
        ApexPages.StandardController ctrlHH = new ApexPages.StandardController(hh);        
        GW_EXT_ManageHousehold ctrl = new GW_EXT_ManageHousehold(ctrlHH);
        system.assertEquals(1, ctrl.listContact.size());
		ctrl.AddExistingContact();               
        system.assertEquals(2, ctrl.listContact.size());
        ctrl.cm.contactId = con2.Id;
		ctrl.SaveEdit();
        system.assertEquals(2, ctrl.listContact.size());
        system.assert(ctrl.listContact[0].Id == con1.Id ||
        	ctrl.listContact[0].Id == con2.Id );
        system.assert(ctrl.listContact[1].Id == con1.Id ||
        	ctrl.listContact[1].Id == con2.Id );
		ctrl.AddExistingContact();        	
        system.assertEquals(3, ctrl.listContact.size());
		ctrl.CancelEdit();        	
        system.assertEquals(2, ctrl.listContact.size());
	}		
}