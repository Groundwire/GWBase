public with sharing class GW_CTRL_SettingsTabCampMbr {
	
	// constructor
	public GW_CTRL_SettingsTabCampMbr(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	}
	
	public List<Campaign_Mbr_Status_Settings__c> listCampMbrSettings {
    	get {
    		if (listCampMbrSettings == null) {
    			listCampMbrSettings = Campaign_Mbr_Status_Settings__c.getall().values();    			
    			AddEmptyRows();
    		}
    		return listCampMbrSettings;
    	}
    	set;
    }	
	
	
	public PageReference AddEmptyRows() {
		for (integer i = 0; i < GW_CTRL_SettingsWizard.cEmptyRows; i++) {
			listCampMbrSettings.add(new Campaign_Mbr_Status_Settings__c());
		}
		return null;
	}	
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabCampMbr';
		return null;
	}
	
	public PageReference saveTab() {
		list<Campaign_Mbr_Status_Settings__c> listCStoDel = new list<Campaign_Mbr_Status_Settings__c>();
		  
		// go thru the campaign member settings, and delete empty ones
		for (integer i = listCampMbrSettings.size()-1; i >= 0; i--) {
			Campaign_Mbr_Status_Settings__c cs = listCampMbrSettings[i];
			if (isnullStr(cs.Campaign_Subtype__c) &&
				isnullStr(cs.Campaign_Type__c) &&
				isnullStr(cs.Status_Label__c)) {
					if (cs.Id == null) {
						// it's a new empty dls; just remove it
						listCampMbrSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listCampMbrSettings.remove(i);
						listCStoDel.add(cs);
					}
			}
		}

		// name new settings
		ctrlWizard.nameNewSettings(listCampMbrSettings, 'CampaignMemberSetting');

		if (listCStoDel.size() > 0) delete listCStoDel;
		try {
			system.debug(listCampMbrSettings);
			upsert listCampMbrSettings;
        } catch (exception ex) {
        	ApexPages.addMessages(ex);
        	return null;
        }		
		AddEmptyRows();
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabCampMbr';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listCampMbrSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabCampMbr' + ctrlWizard.strSalesforceTabNameParam);
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
	static testmethod void TestTabCampMbr() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabCampMbr != null);
		system.assertEquals(ctrl.ctabCampMbr.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabCampMbr.isEditingTab, false);
		ctrl.ctabCampMbr.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabCampMbr');
		ctrl.ctabCampMbr.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabCampMbr.cancelTab() != null);		
	}


}