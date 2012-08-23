public with sharing class GW_CTRL_SettingsTabLead {

	// constructor
	public GW_CTRL_SettingsTabLead(GW_CTRL_SettingsWizard cWiz) {
		ctrlWizard = cWiz;
		isEditingTab = false;
	} 
	
	private GW_CTRL_SettingsWizard ctrlWizard { get; set; }
	
    public List<Lead_Converter_Field_Map__c> listLeadSettings {
    	get {
    		if (listLeadSettings == null) {
    			listLeadSettings = Lead_Converter_Field_Map__c.getall().values();    			
    			AddEmptyRows();
    		}
    		return listLeadSettings;
    	}
    	set;
    }	

	public PageReference AddEmptyRows() {
		for (integer i = 0; i < GW_CTRL_SettingsWizard.cEmptyRows; i++) {
			listLeadSettings.add(new Lead_Converter_Field_Map__c());
		}
		return null;
	}	

	public boolean isEditingTab { get; set; }
	
	public PageReference editTab() {
		isEditingTab = true;
		ctrlWizard.strCurrentTab = 'tabLead';
		return null;
	}
	
	public PageReference saveTab() {
		list<Lead_Converter_Field_Map__c> listLStoDel = new list<Lead_Converter_Field_Map__c>();
		  
		// go thru the frequency settings, and delete empty ones
		for (integer i = listLeadSettings.size()-1; i >= 0; i--) {
			Lead_Converter_Field_Map__c ls = listLeadSettings[i];
			if (isnullStr(ls.Contact_Field__c) &&
				isnullStr(ls.Field_Type__c)) {
					if (ls.Id == null) {
						// it's a new empty dls; just remove it
						listLeadSettings.remove(i);
					} else {
						// it's an existing, but cleared entry; delete it.
						listLeadSettings.remove(i);
						listLStoDel.add(ls);
					}
			}
		}

		// name new settings
		ctrlWizard.nameNewSettings(listLeadSettings, 'LeadConversionSetting');

		if (listLStoDel.size() > 0) delete listLStoDel;
		try {
			system.debug(listLeadSettings);
			upsert listLeadSettings;
        } catch (exception ex) {
        	ApexPages.addMessages(ex);
        	return null;
        }		
		AddEmptyRows();
		isEditingTab = false;
		ctrlWizard.strCurrentTab = 'tabLead';
		return null;
	}
	
	public PageReference cancelTab() {
		isEditingTab = false;
		listLeadSettings = null;
		PageReference p = new PageReference('/apex/Settings_Page?currentTab=tabLead' + ctrlWizard.strSalesforceTabNameParam);
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
	static testmethod void TestTabLead() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard();
		system.assert(ctrl.ctabLead != null);
		system.assertEquals(ctrl.ctabLead.ctrlWizard, ctrl);
		system.assertEquals(ctrl.ctabLead.isEditingTab, false);
		system.assert(ctrl.ctabLead.listLeadSettings != null);
		ctrl.ctabLead.editTab();
		system.assertEquals(ctrl.strCurrentEditTab, 'tabLead');
		ctrl.ctabLead.saveTab();
		system.assertEquals(ctrl.strCurrentEditTab, null);
		system.assert(ctrl.ctabLead.cancelTab() != null);
	}
	
}