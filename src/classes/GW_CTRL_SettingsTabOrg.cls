public with sharing class GW_CTRL_SettingsTabOrg {

	// constructor
	public GW_CTRL_SettingsTabOrg(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }
	
    public List<OrgConRole_Settings__c> listOrgSettings {
    	get {
    		if (listOrgSettings == null) {
    			listOrgSettings = OrgConRole_Settings__c.getall().values();    			
    			AddEmptyRows();
    		}
    		return listOrgSettings;
    	}
    	set;
    }	

	public PageReference AddEmptyRows() {
		for (integer i = 0; i < GW_CTRL_SettingsWizard.cEmptyRows; i++) {
			listOrgSettings.add(new OrgConRole_Settings__c());
		}
		return null;
	}	

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabOrg';
		return null;
	}
	
	public PageReference saveTab() {
		list<OrgConRole_Settings__c> listOStoDel = new list<OrgConRole_Settings__c>();
		  
		// go thru the frequency settings, and delete empty ones
		for (integer i = listOrgSettings.size()-1; i >= 0; i--) {
			OrgConRole_Settings__c os = listOrgSettings[i];
			if (isnullStr(os.Primary_Contact_Role__c)  &&
				isnullStr(os.Name)) {
					if (os.Id == null) {
						// it's a new empty dls; just remove it
						listOrgSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listOrgSettings.remove(i);
						listOStoDel.add(os);
					}
			}
		}

		if (listOStoDel.size() > 0) delete listOStoDel;
		try {
			system.debug(listOrgSettings);
			upsert listOrgSettings;
        } catch (exception ex) {
        	ApexPages.addMessages(ex);
        	return null;
        }		
		AddEmptyRows();
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabOrg';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listOrgSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabOrg' + ctrlWizard.strSalesforceTabNameParam);
		p.setRedirect(true);
		return p;
	}

	private boolean isnullStr(string str) {
		return (str == null || str == '');
	}

	private boolean isnullNum(decimal num) {
		return (num == null || num == 0);
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabOrg() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabOrg != null);
		system.assertEquals(ctrl.ctabOrg.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabOrg.isEditingTab, false);
		system.assert(ctrl.ctabOrg.listOrgSettings != null);
		ctrl.ctabOrg.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabOrg');
		ctrl.ctabOrg.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabOrg.cancelTab() != null);
	}
	
}