public with sharing class GW_CTRL_SettingsTabMisc {
	
	// constructor
	public GW_CTRL_SettingsTabMisc(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabMisc';
		return null;
	}
	
	public PageReference saveTab() {
		upsert ctrlWizard.mSettings;
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabMisc';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		ctrlWizard.mSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabMisc' + ctrlWizard.strSalesforceTabNameParam);
		p.setRedirect(true);
		return p;
	}

	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestTabMisc() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabMisc != null);
		system.assertEquals(ctrl.ctabMisc.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabMisc.isEditingTab, false);
		system.assert(ctrl.ctabMisc.ctrlWizard.mSettings != null);
		ctrl.ctabMisc.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabGeneral');
		ctrl.ctabMisc.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabMisc.cancelTab() != null);
	}


}