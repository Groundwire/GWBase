public with sharing class GW_CTRL_SettingsTabOpp {
	
	// constructor
	public GW_CTRL_SettingsTabOpp(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabOpp';
		return null;
	}
	
	public PageReference saveTab() {
		upsert ctrlWizard.oSettings;
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabOpp';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		ctrlWizard.oSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabOpp' + ctrlWizard.strSalesforceTabNameParam);
		p.setRedirect(true);
		return p;
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabOpp() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabOpp != null);
		system.assertEquals(ctrl.ctabOpp.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabOpp.isEditingTab, false);
		system.assert(ctrl.ctabOpp.ctrlWizard.oSettings != null);
		ctrl.ctabOpp.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabOpp');
		ctrl.ctabOpp.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabOpp.cancelTab() != null);
	}


}