// Written by Steve Andersen, copyright (c) 2007 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// Modifications by David Habib, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Steven Anderson, David Habib
* @date 01/01/2007
* @description ONEN_Constants is a class which holds constants and custom settings, including
* miscellaneous base settings and Opportunity rollup options.
*/

global class ONEN_Constants {

//--- MISCELLANEOUS BASE SETTINGS options ---
	

	/*******************************************************************************************************
	* @description Returns the custom setting Individual_Account_Name__c, the name of the catch-all account
	* for contacts that aren't associated to another account. Defaults to 'Individual', unless called by a
	* test, which defaults to 'IndividualAccountForTests'.
	*/
	private static string strIndAccountName;
	global static String INDIVIDUAL_ACCOUNT_NAME {
		get {
			if (strIndAccountName != null) return strIndAccountName;
			if (Test.isRunningTest()) {
				strIndAccountName = 'IndividualAccountForTests';
			} else { 
				MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
				strIndAccountName = (miscBaseSettings == null) ? 'Individual' : miscBaseSettings.Individual_Account_Name__c;
			}
			return strIndAccountName;
		}		
		set {
			strIndAccountName = value;
		}
	}
	
	/*******************************************************************************************************
	* @description Returns the custom setting Lead_Converter_Account_Name_Not_Provided__c, used by
	* LeadConverter when an Account name is not provided. Defaults to '[not provided]'.
	*/
	global static String NOT_PROVIDED_LABEL { // used by LeadConverter code
		get {
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			return (miscBaseSettings == null) ? '[not provided]' : miscBaseSettings.Lead_Converter_Account_Name_Not_Provided__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Campaign_Member_Status_Donated__c, the default Donated status
	* for campaign members. Defaults to 'Donated'.
	*/
	global static string CAMPAIGN_DEFAULT_DONATED_STATUS {
		get {
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			return (miscBaseSettings == null) ? 'Donated' : miscBaseSettings.Campaign_Member_Status_Donated__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Job_Change_Wizard_Relationship__c, the default 
	* Employee relationship for the Job Change Wizard. Defaults to 'Employee'.
	*/		
	global static string StrJobChangeWizardEmployeeRelationship {		
		get {
			MiscellaneousBaseSettings__c miscBaseSettings = MiscellaneousBaseSettings__c.getInstance();
			return (miscBaseSettings == null) ? 'Employee' : miscBaseSettings.Job_Change_Wizard_Relationship__c;
		}
	}
			
//--- OPPORTUNITY (ROLLUP) options ---

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Stage_Default__c, the default stage for Opportunities
	* created in the NewOppWizard by the user.
	* Defaults to 'Prospecting'.
	*/
	global static string OPP_DEFAULT_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Prospecting' : oppSettings.Opp_Stage_Default__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Stage_Won_Not_Thanked__c, a closed stage for Opportunities,
	* that helps identify which opportunities still need an acknowledgement letter sent to the donor.
	* Defaults to 'Won, Not Thanked'.
	*/
	global static string OPP_DEFAULT_WON_NOT_THANKED_STAGE {
		 get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Won, Not Thanked' : oppSettings.Opp_Stage_Won_Not_Thanked__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Stage_Closed_Won__c, a closed won stage for Opportunities.
	* Defaults to 'Closed Won'.
	*/
	global static string OPP_DEFAULT_CLOSED_WON_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Closed Won' : oppSettings.Opp_Stage_Closed_Won__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Stage_Closed_Lost__c, a closed lost stage for Opportunities.
	* Defaults to 'Closed Lost'.
	*/
	global static string OPP_DEFAULT_CLOSED_LOST_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Closed Lost' : oppSettings.Opp_Stage_Closed_Lost__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Stage_Pledged_Default__c, a stage for Opportunities used
	* for Pledged opportunities, that are made up of a set of installments.
	* Defaults to 'Pledged'.
	*/
	global static string OPP_DEFAULT_PLEDGED_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Pledged' : oppSettings.Opp_Stage_Pledged_Default__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Stage_Recurring_Default__c, an Open stage for Opportunities used
	* for recurring donations (Opportunities) that are associated with a Recurring Payment Profile.
	* Defaults to 'Recurring'.
	*/
	global static string OPP_DEFAULT_RECURRING_STAGE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Recurring' : oppSettings.Opp_Stage_Recurring_Default__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the Opportunity Contact Role to use for the donor contact, given the passed in recordtype.
	* Defaults to 'Donor'.
	* @param recordTypeName A recordtype name.
	* @returns String The contact role to use.
	*/
	global static string OPP_GIFT_DONOR_ROLE(string recordTypeName) {
		ConRole_Settings__c crSettings = ConRole_Settings__c.getInstance(recordTypeName);
		return (crSettings == null) ? 'Donor' : crSettings.Primary__c;
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Gift_Role_Contact_HH_Donor__c, a donor role for Household
	* members who are not the primary donor for an opportunity.
	* Defaults to 'Household Soft Credit'.
	*/
	global static string OPP_GIFT_HH_DONOR_ROLE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Household Soft Credit' : oppSettings.Opp_Gift_Role_Contact_HH_Donor__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Gift_Role_Org_Donor__c, a donor role for the primary contact 
	* for an Organization donation.
	* Defaults to 'Organizational Donor'.
	*/
	global static string OPP_ORG_GIFT_DONOR_ROLE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Organizational Donor' : oppSettings.Opp_Gift_Role_Org_Donor__c;
		}
	}		

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Gift_Role_Matching_Donor__c, a donor role for the contact
	* the matching gift is on behalf of.
	* Defaults to 'Donor - Corporate Match'.
	*/
	global static string OPP_MATCHING_GIFT_DONOR_ROLE {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Donor - Corporate Match' : oppSettings.Opp_Gift_Role_Matching_Donor__c;
		}
	}

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Record_Type_Contact_Gift__c, a record type for 
	* Opportunities. Defaults to 'Gift'.
	*/
	global static string OPP_DEFAULT_RECTYPE_CONTACT {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Gift' : oppSettings.Opp_Record_Type_Contact_Gift__c;
		}
	}		

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Rectype_For_Tests_Member__c, a record type for 
	* Opportunities used in membership testing. Defaults to 'Membership'.
	*/
	global static string OPP_MEMBER_RECTYPE_FORTESTS {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Membership' : oppSettings.Opp_Rectype_For_Tests_Member__c;
		}
	}		

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Rectype_For_Tests_NonMember__c, a record type for 
	* Opportunities used in testing (other than membership tests). Defaults to 'Gift'.
	*/
	global static string OPP_NONMEMBER_RECTYPE_FORTESTS {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Gift' : oppSettings.Opp_Rectype_For_Tests_NonMember__c;
		}
	}		

	/*******************************************************************************************************
	* @description Returns the custom setting Opp_Rectype_For_Tests_Default__c, a record type for 
	* Opportunities used in testing. Defaults to 'Gift'.
	*/
	global static string OPP_DEFAULT_RECTYPE_FORTESTS {
		get {
	        OppRollupSettings__c oppSettings = OppRollupSettings__c.getInstance();
			return (oppSettings == null) ? 'Gift' : oppSettings.Opp_Rectype_For_Tests_Default__c;
		}
	}		

}