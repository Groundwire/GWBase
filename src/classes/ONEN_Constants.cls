//constants and custom settings file
global class ONEN_Constants {
// Written by Steve Andersen, copyright (c) 2007 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// Modifications by David Habib, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
//--- MISCELLANEOUS BASE SETTINGS options ---
	private static string strIndAccountName;
	global static String INDIVIDUAL_ACCOUNT_NAME {
		get {
			if (strIndAccountName != null) return strIndAccountName;
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			strIndAccountName = (miscBaseSettings == null) ? 'Individual' : miscBaseSettings.Individual_Account_Name__c;
			return strIndAccountName;
		}		
		set {
			strIndAccountName = value;
		}
	}
	
	public static String NOT_PROVIDED_LABEL { // used by LeadConverter code
		get {
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			return (miscBaseSettings == null) ? '[not provided]' : miscBaseSettings.Lead_Converter_Account_Name_Not_Provided__c;
		}
	}

	public static string CAMPAIGN_DEFAULT_DONATED_STATUS {
		get {
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			return (miscBaseSettings == null) ? 'Donated' : miscBaseSettings.Campaign_Member_Status_Donated__c;
		}
	}
		
	public static string StrJobChangeWizardEmployeeRelationship {		
		get {
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			return (miscBaseSettings == null) ? 'Employee' : miscBaseSettings.Job_Change_Wizard_Relationship__c;
		}
	}
			
//--- OPPORTUNITY (ROLLUP) options ---
	global static string OPP_DEFAULT_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Prospecting' : oppSettings.Opp_Stage_Default__c;
		}
	}

	global static string OPP_DEFAULT_WON_NOT_THANKED_STAGE {
		 get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Won, Not Thanked' : oppSettings.Opp_Stage_Won_Not_Thanked__c;
		}
	}

	global static string OPP_DEFAULT_CLOSED_WON_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Closed Won' : oppSettings.Opp_Stage_Closed_Won__c;
		}
	}
		
	global static string OPP_DEFAULT_CLOSED_LOST_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Closed Lost' : oppSettings.Opp_Stage_Closed_Lost__c;
		}
	}

	global static string OPP_DEFAULT_PLEDGED_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Pledged' : oppSettings.Opp_Stage_Pledged_Default__c;
		}
	}
		 
	global static string OPP_DEFAULT_RECURRING_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Recurring' : oppSettings.Opp_Stage_Recurring_Default__c;
		}
	}
		 
	global static string OPP_GIFT_DONOR_ROLE(string recordTypeName) {
		ConRole_Settings__c crSettings = ConRole_Settings__c.getInstance(recordTypeName);
		return (crSettings == null) ? 'Donor' : crSettings.Primary__c;
	}
				
	global static string OPP_GIFT_HH_DONOR_ROLE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Household Soft Credit' : oppSettings.Opp_Gift_Role_Contact_HH_Donor__c;
		}
	}

	global static string OPP_ORG_GIFT_DONOR_ROLE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Organizational Donor' : oppSettings.Opp_Gift_Role_Org_Donor__c;
		}
	}		
		
	global static string OPP_MATCHING_GIFT_DONOR_ROLE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Donor - Corporate Match' : oppSettings.Opp_Gift_Role_Matching_Donor__c;
		}
	}		

	global static string OPP_DEFAULT_RECTYPE_CONTACT {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Gift' : oppSettings.Opp_Record_Type_Contact_Gift__c;
		}
	}		
		
	global static string OPP_MEMBER_RECTYPE_FORTESTS {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Membership' : oppSettings.Opp_Rectype_For_Tests_Member__c;
		}
	}		
		
	global static string OPP_NONMEMBER_RECTYPE_FORTESTS {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Gift' : oppSettings.Opp_Rectype_For_Tests_NonMember__c;
		}
	}		
		
	global static string OPP_DEFAULT_RECTYPE_FORTESTS {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Gift' : oppSettings.Opp_Rectype_For_Tests_Default__c;
		}
	}		

}