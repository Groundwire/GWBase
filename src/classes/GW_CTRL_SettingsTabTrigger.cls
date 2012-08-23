public with sharing class GW_CTRL_SettingsTabTrigger {
	
	// constructor
	public GW_CTRL_SettingsTabTrigger(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabTrigger';
		return null;
	}
	
	public PageReference saveTab() {
		upsert ctrlWizard.tSettings;
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabTrigger';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		ctrlWizard.tSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabTrigger' + ctrlWizard.strSalesforceTabNameParam);
		p.setRedirect(true);
		return p;
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabTrigger() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabTrigger != null);
		system.assertEquals(ctrl.ctabTrigger.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabTrigger.isEditingTab, false);
		system.assert(ctrl.ctabTrigger.ctrlWizard.tSettings != null);
		ctrl.ctabTrigger.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabTrigger');
		ctrl.ctabTrigger.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabTrigger.cancelTab() != null);
	}


}