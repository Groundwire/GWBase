public with sharing class GW_CTRL_SettingsWizard {

	// constructor	
	public GW_CTRL_SettingsWizard() {

        map<string, string> params = ApexPages.currentPage().getParameters();
        string str = params.get('currentTab');
        if (str != null && str != '') {
        	strCurrentTab = str;
        } else {
        	strCurrentTab = 'tabOpp';
        }
        str = params.get('sfdc.tabName');
        if (str != null && str != '') {
        	strSalesforceTabNameParam = '&sfdc.tabName=' + str;
        } else {
        	strSalesforceTabNameParam = '';
        }		
	} 
	
	public boolean inEditMode {
		get { 
			return  
				ctabLead.isEditingTab ||
				ctabOrg.isEditingTab ||
				ctabRoles.isEditingTab ||
				ctabTrigger.isEditingTab ||
				ctabMisc.isEditingTab || 
				ctabOpp.isEditingTab  ||
				ctabCampMbr.isEditingTab;
				
		}
		set;
	}
	
	public string strSalesforceTabNameParam { get; set; }
	
	public string strCurrentEditTab {
		get {
			if (ctabCampMbr.isEditingTab) return 'tabCampMbr';
			if (ctabLead.isEditingTab) return 'tabLead';
			if (ctabOrg.isEditingTab) return 'tabOrg';
			if (ctabRoles.isEditingTab) return 'tabRoles';
			if (ctabMisc.isEditingTab) return 'tabMisc';
			if (ctabTrigger.isEditingTab) return 'tabTrigger';
			if (ctabOpp.isEditingTab) return 'tabOpp';
			
			return null;
		}
		set;
	}
	 
	// tabPanel sets this thru an ajax call.
	public string strCurrentTab { get; set; }
	

	public GW_CTRL_SettingsTabCampMbr ctabCampMbr { 
		get {
			if (ctabCampMbr == null) ctabCampMbr = new GW_CTRL_SettingsTabCampMbr(this);
			return ctabCampMbr;
		}
		set;
	}
	
	public GW_CTRL_SettingsTabLead ctabLead { 
		get {
			if (ctabLead == null) ctabLead = new GW_CTRL_SettingsTabLead(this);
			return ctabLead;
		}
		set;
	}
	
	public GW_CTRL_SettingsTabMisc ctabMisc { 
		get {
			if (ctabMisc == null) ctabMisc = new GW_CTRL_SettingsTabMisc(this);
			return ctabMisc;
		}
		set; 
	}
	
	public GW_CTRL_SettingsTabRoles ctabRoles { 
		get {
			if (ctabRoles == null) ctabRoles = new GW_CTRL_SettingsTabRoles(this);
			return ctabRoles;
		}
		set; 
	}
	
	public GW_CTRL_SettingsTabTrigger ctabTrigger { 
		get {
			if (ctabTrigger == null) ctabTrigger = new GW_CTRL_SettingsTabTrigger(this);
			return ctabTrigger;
		}
		set; 
	}
	
	public GW_CTRL_SettingsTabOrg ctabOrg { 
		get {
			if (ctabOrg == null) ctabOrg = new GW_CTRL_SettingsTabOrg(this);
			return ctabOrg;
		}
		set; 
	}
	
	public GW_CTRL_SettingsTabOpp ctabOpp { 
		get {
			if (ctabOpp == null) ctabOpp = new GW_CTRL_SettingsTabOpp(this);
			return ctabOpp;
		}
		set; 
	}
	
	public OppRollupSettings__c oSettings {
		get {
			if (oSettings == null) oSettings = OppRollupSettings__c.getOrgDefaults();
			return oSettings;
		}
		set;
	}
	
	public TriggerSettings__c tSettings {
		get {
			if (tSettings == null) tSettings = TriggerSettings__c.getOrgDefaults();
			return tSettings;
		}
		set;
	}
	
	public MiscellaneousBaseSettings__c mSettings {
		get {
			if (mSettings == null) mSettings = MiscellaneousBaseSettings__c.getOrgDefaults();
			return mSettings;
		}
		set;
	}
	

	
	
	
	// utility to create unique new names for the list of objects that don't have names.
	public void nameNewSettings(list<SObject> listSobj, string strPrefix) { 
		if (listSobj == null || strPrefix == null) return;
		
		// name new settings, by first finding the last name used.
		integer iUsedMax = 0;
		for (integer i = 0; i < listSobj.size(); i++ ) {
			string strName = string.valueOf(listSobj[i].get('name'));
			if (strName != null && strName.startsWith(strPrefix)) {
				integer iNum = integer.valueOf(strName.subString(strPrefix.length()));
				if (iNum > iUsedMax) {
					iUsedMax = iNum;
				}
			}
		}
		for (integer i = 0; i < listSobj.size(); i++ ) {
			if (listSobj[i].get('id') == null) {
				listSobj[i].put('name', strPrefix + string.valueOf(++iUsedMax));
			}
		}
	}
	
	
	
	
	// the list of Engagement Levels to put in the dropdowns (not in use for GWBASE)
	/*
	public list<SelectOption> listSOLevels {
		get {
			if (listSOLevels == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				for (integer i = 1; i <= 8; i++) {
					string strLevel = 'Level_' + string.valueOf(i) + '_Name__c';
					string strLevelName = string.valueOf(etSettings.get(strLevel));
					if (strLevelName != null && strLevelName != '') {
						listSO.add(new SelectOption(string.valueOf(i) + '.0', strLevelName));
					}
				}
				listSOLevels = listSO;
			}		
			return listSOLevels;
		}
		set;
	}
	*/
	// set used to keep track of which contact fields are boolean, 
	// so we can automaticaly mark them as checkbox when saving Contact Field Settings.
	public set<string> setCheckboxFields { get; set; }
	
	// the list of Contact Fields to put in the dropdowns
	public list<SelectOption> listSOContactFields {
		get {
			if (listSOContactFields == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));				
				Map<String, Schema.SObjectField> mapS = Schema.SObjectType.Contact.fields.getMap();	
				
				// create temp list of strings to sort by alpha 
				list<string> listStr = new list<string>();
				setCheckboxFields = new set<string>();
				for (Schema.SObjectField sf : mapS.values()) {
					Schema.DescribeFieldResult f = sf.getDescribe();
					listStr.add(f.Label + '.' + f.Name);
					if (f.Type == Schema.DisplayType.Boolean) {
						setCheckboxFields.add(f.Name);
					}
				}				
				listStr.sort();
				
				for (string str : listStr) {
					list<string> listPair = str.split('\\.');  // need to escape the dot char since this is regex
					listSO.add(new SelectOption(listPair[1], listPair[0]));					
				}				
							
				listSOContactFields = listSO;
			}		
			return listSOContactFields;
		}
		set;
	}
	
	// helper to say whether this instance has any campaign record types defined.
	// used by several tabs to hide a campaign record type column, when not needed.
	public boolean hasCampaignRecordTypes {
		get {
			return (listSOCampaignRecordTypes.size() > 1);
		}
	}
	
	// the list of Campaign Record Types to put in the dropdowns
	public list<SelectOption> listSOCampaignRecordTypes {
		get {
			if (listSOCampaignRecordTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));				
				for (RecordType rt : [SELECT Name FROM RecordType WHERE SobjectType='Campaign']) {
					listSO.add(new SelectOption(rt.Name, rt.Name));	
				}
				listSOCampaignRecordTypes = listSO;
			}		
			return listSOCampaignRecordTypes;
		}
		set;
	}
	
	// the list of Campaign Types to put in the dropdowns
	public list<SelectOption> listSOCampaignTypes {
		get {
			if (listSOCampaignTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				Schema.DescribeFieldResult F = Campaign.Type.getDescribe();
				for (Schema.PicklistEntry pe : F.getPicklistValues()) {
					listSO.add(new SelectOption(pe.Value, pe.Label));
				}
				listSOCampaignTypes = listSO;
			}		
			return listSOCampaignTypes;
		}
		set;
	}
	
	
	// the list of Opportunity Stages to put in the dropdowns
	public list<SelectOption> listSOOppStages {
		get {
			if (listSOOppStages == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				Schema.DescribeFieldResult F = Opportunity.StageName.getDescribe();
				for (Schema.PicklistEntry pe : F.getPicklistValues()) {
					listSO.add(new SelectOption(pe.Value, pe.Label));
				}
				listSOOppStages = listSO;
			}		
			return listSOOppStages;
		}
		set;
	}
	
	// the list of Opportunity Types to put in the dropdowns
	public list<SelectOption> listSOOppTypes {
		get {
			if (listSOOppTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				Schema.DescribeFieldResult F = Opportunity.Type.getDescribe();
				for (Schema.PicklistEntry pe : F.getPicklistValues()) {
					listSO.add(new SelectOption(pe.Value, pe.Label));
				}
				listSOOppTypes = listSO;
			}		
			return listSOOppTypes;
		}
		set;
	}
	
	
	// the list of Opportunity Record Types to put in the dropdowns
	public list<SelectOption> listSOOppRecordTypes {
		get {
			if (listSOOppRecordTypes == null) {
				
				list<SelectOption> listSO = new list<SelectOption>();			
				for (RecordType rt : [SELECT Name FROM RecordType WHERE SobjectType='Opportunity']) {
					
					listSO.add(new SelectOption(rt.Name, rt.Name));	
				}
				listSOOppRecordTypes = listSO;
			}		
			return listSOOppRecordTypes;
		}
		set;
	}
	
	// the list of Opportunity Contact Roles to put in the dropdowns
	public list<SelectOption> listSOContactRoles {
		get {
			if (listSOContactRoles == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				Schema.DescribeFieldResult F = OpportunityContactRole.Role.getDescribe();
				for (Schema.PicklistEntry pe : F.getPicklistValues()) {
					listSO.add(new SelectOption(pe.Value, pe.Label));
				}
				listSOContactRoles = listSO;
			}		
			return listSOContactRoles;
		}
		set;
	}
	
	// the list of Campaign Member Statuses to put in the dropdowns
	public list<SelectOption> listSOMbrStatus {
		get {
			if (listSOMbrStatus == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				Schema.DescribeFieldResult F = CampaignMember.Status.getDescribe();
				for (Schema.PicklistEntry pe : F.getPicklistValues()) {
					listSO.add(new SelectOption(pe.Value, pe.Label));
				}
				listSOMbrStatus = listSO;
			}		
			return listSOMbrStatus;
		}
		set;
	}
	
	
	// the list of Campaign Sub Types to put in the dropdowns
	public list<SelectOption> listSOCampaignSubTypes {
		get {
			if (listSOCampaignSubTypes == null) {
				list<SelectOption> listSO = new list<SelectOption>();
				listSO.add(new SelectOption('', ''));
				
				if (GW_BATCH_EngagementRollup.IsGWBaseInstalled) {
					Map<String, Schema.SObjectField> M = Schema.SObjectType.Campaign.fields.getMap();	
					String sub_type = GW_BATCH_EngagementRollup.addNSPrefixET('Campaign_Sub_Type__c', false, false);								
					Schema.DescribeFieldResult F = M.get(sub_type).getDescribe();
					for (Schema.PicklistEntry pe : F.getPicklistValues()) {
						listSO.add(new SelectOption(pe.Value, pe.Label));
					}
				}
				
				listSOCampaignSubTypes = listSO;
			}		
			return listSOCampaignSubTypes;
		}
		set;
	}
	
	// helper used to hide Campaign Sub Type columns when not running with GWBase.
	public boolean IsGWBaseInstalled {
		get {
			return (GW_BATCH_EngagementRollup.IsGWBaseInstalled);
		}
	}
		
	public boolean isnullStr(string str) {
		return (str == null || str == '');
	}

	public boolean isnullNum(decimal num) {
		return (num == null || num == 0);
	}
	
	public static integer cEmptyRows = 3;
	
	//---------------------------------------- TEST CODE -------------------------------------------------
	static testmethod void TestWizard() {
		GW_CTRL_SettingsWizard ctrl = new GW_CTRL_SettingsWizard(); 

		system.assert(ctrl.ctabOpp != null);
		system.assert(ctrl.ctabRoles != null);
		system.assert(ctrl.ctabOrg != null);
		system.assert(ctrl.ctabTrigger != null); 
		system.assert(ctrl.ctabCampMbr!= null);
		system.assert(ctrl.ctabLead != null);
		system.assert(ctrl.ctabMisc != null);
		system.assert(ctrl.inEditMode == false);
		system.assert(ctrl.strCurrentEditTab == null);
		system.assert(ctrl.strCurrentTab == 'tabLevels');
		system.assert(ctrl.tSettings != null);	
		system.assert(ctrl.oSettings != null);
		system.assert(ctrl.mSettings != null);
		system.assert(ctrl.listSOContactFields != null);
		system.assert(ctrl.listSOCampaignRecordTypes != null);
		system.assert(ctrl.listSOCampaignTypes != null);
		system.assert(ctrl.setCheckboxFields != null);
		system.assert(ctrl.hasCampaignRecordTypes == (ctrl.listSOCampaignRecordTypes.size() > 1));
		system.assert(ctrl.IsGWBaseInstalled == GW_BATCH_EngagementRollup.IsGWBaseInstalled);

		
	}
}