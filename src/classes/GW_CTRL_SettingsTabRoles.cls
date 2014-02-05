public with sharing class GW_CTRL_SettingsTabRoles {

	// constructor
	public GW_CTRL_SettingsTabRoles(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }
	
    public List<ConRole_Settings__c> listRoleSettings {
    	get {
    		if (listRoleSettings == null) {
    			listRoleSettings = ConRole_Settings__c.getall().values();    			
    			AddEmptyRows();
    		}
    		return listRoleSettings;
    	}
    	set;
    }	

	public PageReference AddEmptyRows() {
		for (integer i = 0; i < GW_CTRL_SettingsWizard.cEmptyRows; i++) {
			listRoleSettings.add(new ConRole_Settings__c());
		}
		return null;
	}	

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabRoles';
		return null;
	}
	
	public PageReference saveTab() {
		list<ConRole_Settings__c> listRStoDel = new list<ConRole_Settings__c>();
		  
		// go thru the frequency settings, and delete empty ones
		for (integer i = listRoleSettings.size()-1; i >= 0; i--) {
			ConRole_Settings__c rs = listRoleSettings[i];
			if (isnullStr(rs.Primary__c)) {
					if (rs.Id == null) {
						// it's a new empty dls; just remove it
						listRoleSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listRoleSettings.remove(i);
						listRStoDel.add(rs);
					}
			}
		}

		if (listRStoDel.size() > 0) delete listRStoDel;
		try {
			system.debug(listRoleSettings);
			upsert listRoleSettings;
        } catch (exception ex) {
        	ApexPages.addMessages(ex);
        	return null;
        }		
		AddEmptyRows();
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabRoles';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listRoleSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabRoles' + ctrlWizard.strSalesforceTabNameParam);
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
	static testmethod void TestTabRoles() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabRoles != null);
		system.assertEquals(ctrl.ctabRoles.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabRoles.isEditingTab, false);
		system.assert(ctrl.ctabRoles.listRoleSettings != null);
		ctrl.ctabRoles.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabRoles');
		ctrl.ctabRoles.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabRoles.cancelTab() != null);
	}
	
}