// Written by Dave Habib, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

public with sharing class GW_RecurringPayments {

	//------------------------------------------------------------------------------
	// return a RecurringPaymentProfile name given its information.	
	//------------------------------------------------------------------------------
	public static string strNameForRPP(Recurring_Payment_Profile__c rpp) {
		string strName;
		if (rpp.Account__c != null) {
			Account acc = [select Name from Account where Id = :rpp.Account__c limit 1];
			strName = acc.Name;
		} else if (rpp.Contact__c != null) {
			Contact con = [select FirstName, LastName, HouseholdName__c from Contact where Id = :rpp.Contact__c limit 1];
			strName = (con.HouseholdName__c != null) ? con.HouseholdName__c : 
					((con.FirstName == null) ? con.LastName : (con.FirstName + ' ' + con.LastName));		
		} else {
			return null;
		}
		
		string strYear;
		if (rpp.Start_Date__c != null) {
			strYear = string.valueOf(rpp.Start_Date__c.year());
		} 
		
		return strName + ' ' + strYear + ' Recurring Payment Profile';
	}


	//------------------------------------------------------------------------------
	// HandleEndDateChange() 
	// called by the RPP trigger to deal with the RPP
	// having its EndDate changed, so that we can close any pending Opportunities.
	//------------------------------------------------------------------------------	
	public static void HandleEndDateChange(list<Recurring_Payment_Profile__c> listRPPNew, list<Recurring_Payment_Profile__c> listRPPOld) {
		
		map<Id, Date> mapRppIdEndDate = new map<Id, Date>();
		
		// find all the recurring payment profiles that have had their end date changed
		for (integer i = 0; i < listRPPNew.size(); i++) {
			if (listRPPNew[i].End_Date__c != null && listRPPNew[i].End_Date__c != listRPPOld[i].End_Date__c) {
				mapRppIdEndDate.put(listRPPNew[i].Id, listRPPNew[i].End_Date__c);
			}
		}		
		
		// find all the Opportunties for these recurring payments profiles		
		// and close those opportunties, whose date is after the new EndDate
		list<Opportunity> listOppToUpdate = new list<Opportunity>();
		for (list<Opportunity> listOpp : [select Id, CloseDate, StageName, Recurring_Payment_Profile__r.Id from Opportunity where 
				Recurring_Payment_Profile__r.Id in :mapRppIdEndDate.keySet() and
				StageName = :ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE]) {
			for (Opportunity opp : listOpp) {
				if (opp.CloseDate >= mapRppIdEndDate.get(opp.Recurring_Payment_Profile__r.Id)) {
					opp.StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE;
					listOppToUpdate.add(opp);
				}
			}
		}		
		update listOppToUpdate;
	}	

	//------------------------------------------------------------------------------
	// CreateRecurringOppsIfNeeded 
	// called by the Opportunity after trigger to deal with the the last opp
	// being closed, and seeing whether its RPP should have new recurring opps created.
	//------------------------------------------------------------------------------	
	public static void CreateRecurringOppsIfNeeded(list<Opportunity> listOppNew, list<Opportunity> listOppOld) {
		
		map<ID, Opportunity> mapIdRPPToOpp = new map<ID, Opportunity>();
		integer i;
		
		// find which RPP's we need to look at.
		for (i =0; i < listOppNew.size(); i++) {
			Opportunity oppNew = listOppNew[i];
			Opportunity oppOld = (listOppOld == null ? null : listOppOld[i]);
			if (oppNew.Recurring_Payment_Profile__c != null && oppNew.isClosed && (oppOld == null || !oppOld.isClosed)) {
				// we save the original Opp in our map, so we can later use
				// it's CloseDate.  It would seem better to use the oppNew, but
				// Salesforce will change its CloseDate to today's date if it was in the future,
				// and this would throw off our calculation for the next recurring opp date.
				mapIdRPPToOpp.put(oppNew.Recurring_Payment_Profile__c, oppOld == null ? oppNew : oppOld); 
			}			
		}
	
		// for these RPP's, see which have open opps.
		set<ID> setIdRPPWithOpps = new set<ID>();
		for (list<Opportunity> listOpp : [select Id, Recurring_Payment_Profile__c from Opportunity 
			where IsClosed = false and Recurring_Payment_Profile__c in :mapIdRPPToOpp.keySet()]) {
			for (Opportunity opp : listOpp) {
				setIdRPPWithOpps.add(opp.Recurring_Payment_Profile__c);
			}
		}
		
		// remove the RPP's with open opps from our map.
		for (ID id : mapIdRPPToOpp.keySet()) {
			if (setIdRPPWithOpps.contains(id)) {
				mapIdRPPToOpp.remove(id);
			}
		}
		
		// now if an RPP has no open Opps, create a new Recurring Opp for it.
		list<Opportunity> listOppsToCreate = new list<Opportunity>();
		
		for (Recurring_Payment_Profile__c rpp : [select Id, IsActive__c, Amount__c, Contact__c, Account__c, 
			Payment_Period__c, End_Date__c, Frequency__c from Recurring_Payment_Profile__c
			where IsActive__c = 'Yes' and Id in :mapIdRPPToOpp.keySet()]) {
			Opportunity oppClosed = mapIdRPPToOpp.get(rpp.Id);
			Date dt = oppClosed.CloseDate;
			integer fq = rpp.frequency__c.intValue();
			dt = 
				(rpp.Payment_Period__c == 'Day') ? dt.addDays(fq) :
				(rpp.Payment_Period__c == 'Week') ? dt.addDays(fq * 7) :
				(rpp.Payment_Period__c == 'Year') ? dt.addYears(fq) :
				dt.addMonths(fq);			

			Opportunity opp = new Opportunity(
				RecordTypeId = oppClosed.RecordTypeId,
				Amount = rpp.Amount__c,
				CloseDate = dt,
				StageName = ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE,
				AccountId = oppClosed.AccountId,
				ContactId__c = oppClosed.ContactId__c,
				CR_Contact_Id__c = oppClosed.CR_Contact_Id__c, 
				Recurring_Payment_Profile__c = rpp.Id);	
			listOppsToCreate.add(opp);				
		}
		
		// create them.
		insert listOppsToCreate;			
	}
	
	//------------------------------------------------------------------------------
	// Tests
	//------------------------------------------------------------------------------
	
	static testmethod void TestRPPName() {
		
		//create a Contact
		Contact con = new Contact (FirstName='Joe',	LastName = 'Smith');
		insert con;
				
		Recurring_Payment_Profile__c rpp = new Recurring_Payment_Profile__c(
			Contact__c = con.id,
			Start_Date__c = system.today()
		);
		
		// test name by contact
		rpp.Name = GW_RecurringPayments.strNameForRPP(rpp);
		system.assert(rpp.Name != null);	
		
		// create an Account
		Account acc = new Account(Name='Acme');
		insert acc;
		rpp.Contact__c = null;
		rpp.Account__c = acc.id;

		// test name by account
		string str = GW_RecurringPayments.strNameForRPP(rpp);
		system.assert(str != null);
		system.assert(rpp.Name != str);  		
	}
	
	//------------------------------------------------------------------------------
	static testmethod void TestRPPEndDateChange() {
		
		//create a Contact
		Contact con = new Contact (FirstName='Joe',	LastName = 'Smith');
		insert con;
				
		//create a recurring payment profile				
		Recurring_Payment_Profile__c rpp = new Recurring_Payment_Profile__c(
			Contact__c = con.id,
			Start_Date__c = system.today(),
			Amount__c = 10,
			Payment_Period__c = 'month',
			Frequency__c = 1,
			Name = 'my rpp'
		);
		insert rpp;	
		
		//create some opps associated with the rpp
		list<Opportunity> listOpp = new list<Opportunity>();
		integer cOpp = 5;
		for (integer i = 0; i < cOpp; i++) {
			Opportunity opp = new Opportunity(
				Amount = rpp.Amount__c,
				ContactId__c = rpp.Contact__c,
				CloseDate = system.today().addMonths(i),
				StageName = ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE,
				Recurring_Payment_Profile__c = rpp.Id);
			listOpp.add(opp);
		}
		insert listOpp;
		
		//verify we got all our recurring opps for the rpp
		integer cOppRecurring = [select count() from Opportunity where Recurring_Payment_Profile__c = :rpp.id and
			StageName = :ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE]; 
		system.assertEquals(cOpp, cOppRecurring);
						
		//close the rpp, and ensure later opps are closed
		integer cOppToClose = 2;						
		rpp.End_Date__c = system.today().addMonths(cOpp - cOppToClose);
		update rpp;
		cOppRecurring = [select count() from Opportunity where Recurring_Payment_Profile__c = :rpp.id and
			StageName = :ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE]; 
		system.assertEquals(cOpp - cOppToClose, cOppRecurring);		
	}
	

	//------------------------------------------------------------------------------
	static testmethod void TestRPPAutoExtendOpps() {
		
		//create a Contact
		Contact con = new Contact (FirstName='Joe',	LastName = 'Smith');
		insert con;
				
		//create a recurring payment profile				
		Recurring_Payment_Profile__c rpp = new Recurring_Payment_Profile__c(
			Contact__c = con.id,
			Start_Date__c = system.today(),
			Amount__c = 10,
			Payment_Period__c = 'month',
			Frequency__c = 1,
			Name = 'my rpp'
		);
		insert rpp;	
		
		//create 1 opps associated with the rpp
		list<Opportunity> listOpp = new list<Opportunity>();
		integer cOpp = 1;
		for (integer i = 0; i < cOpp; i++) {
			Opportunity opp = new Opportunity(
				Amount = rpp.Amount__c,
				ContactId__c = rpp.Contact__c,
				CloseDate = system.today().addMonths(i),
				StageName = ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE,
				Recurring_Payment_Profile__c = rpp.Id);
			listOpp.add(opp);
		}
		insert listOpp;
		
		//verify we got all our recurring opps for the rpp
		integer cOppRecurring = [select count() from Opportunity where Recurring_Payment_Profile__c = :rpp.id and
			StageName = :ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE]; 
		system.assertEquals(cOpp, cOppRecurring);
	
		//we now close the single opp, and verify that a new recurring opp is created.
		listOpp[0].StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE;
		update listOpp;
		
		list<Opportunity> listOppAuto = [select Id, StageName, CloseDate from Opportunity 
			where Recurring_Payment_Profile__c = :rpp.id and
			StageName = :ONEN_Constants.OPP_DEFAULT_RECURRING_STAGE]; 		
		system.assertEquals(1, listOppAuto.size());
		system.assertNotEquals(listOpp[0].id, listOppAuto[0].id);
		system.assertEquals(system.today().addMonths(1), listOppAuto[0].CloseDate);
	}	
}