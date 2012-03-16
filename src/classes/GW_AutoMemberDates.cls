/*******************************************************************************************************
* @author Nicolas Campbell
* @date 09/01/2011
* @description Sets membership start and end dates on membership Opportunities, optionally based on
* previous membership expiration.
*/

public without sharing class GW_AutoMemberDates {

	private OppRollupSettings__c ors;
	
	private map<id,Contact> conmap = new map<id,Contact>();
	private map<id,Account> accmap = new map<id,Account>();
	private set<id> conset = new set<id>();
	private set<id> accset = new set<id>();
	private set<String> membershipRecTypes = new set<String>();
	private list<Opportunity> otp = new list<Opportunity>();
	
	//constructor - instantiates settings variables
	public GW_AutoMemberDates() {
		
		//if there is no instance of settings and we're running a test, set membership period to 1 year and don't do rolling dates.
		ors = OppRollupSettings__c.getInstance();
		if (test.isRunningTest()){
			if (ors==null || ors.Membership_Period__c == null || ors.Membership_Renewal_Period__c == null) {
				ors = new OppRollupSettings__c(
					Membership_Period__c=365,
					Membership_Renewal_Period__c=0,
					Membership_Rolling_Start_Date__c=false,
					Membership_Record_Types__c='Membership'
				);
			}
		}
		
		//create a set of membership record types based on the setting
		if (ors!=null){
			if (ors.Membership_Record_Types__c==NULL) membershipRecTypes.add('Membership');
			else for (String s : ors.Membership_Record_Types__c.split(';')) membershipRecTypes.add(s); 
		}
	}

	public void memberDates(List<Opportunity> opplist) {

		//creates list of valid opportunities, and sets of contact/account IDs if rolling dates are active
		if (ors != NULL) {
			 if(ors.Membership_Period__c!=NULL && ors.Membership_Renewal_Period__c!=NULL) for (Opportunity o:opplist) {
				system.debug('rtset & name ' + membershipRecTypes + ' rt: ' + o.RecordTypeId + ' name ' + GW_RecTypes.GetRecordTypeName('Opportunity', o.RecordTypeId));
				
				//this opportunity is valid if it is a membership opportunity, and no membership date/origin fields are set.
				if ( membershipRecTypes.contains(GW_RecTypes.GetRecordTypeName('Opportunity', o.RecordTypeId)) 
					 && o.Membership_End_Date__c==null && o.Membership_Start_Date__c==null && o.Membership_Origin__c==null ) {
					
					if (o.contactId__c!=null) conset.add(o.ContactId__c);
					if (o.AccountId!=null) accset.add(o.AccountId);
					otp.add(o);
				}
			}		
		//these opps are from a before trigger so no update is needed
		if (otp.size() > 0) autoDate();
		}
	}

	//processes auto-merged opportunities and resets member dates for DupeBlocker compatibility
	public void mergeDates(List<Opportunity> opplist) {
		
		list<Opportunity> oppstoprocess = new list<Opportunity>();
		
		if (ors!=null) {
			if (ors.Membership_Period__c!=NULL && ors.Membership_Renewal_Period__c!=NULL) for (Opportunity o:opplist) {
				if ( membershipRecTypes.contains(GW_RecTypes.GetRecordTypeName('Opportunity', o.RecordTypeId)) 
					 && o.Membership_Start_Date__c==o.CloseDate && o.Membership_Origin__c=='New' ) {
		
					 	if (o.ContactId__c!=null) conset.add(o.ContactId__c);
					 	if (o.AccountId!=null) accset.add(o.AccountId);
					 	otp.add(o);
				}
			}
			if (!oppstoprocess.isEmpty()) {
				autoDate();
				//These opps are not from a before trigger so they need to be updated
				update otp;
			}	
		}
	}

	private void autoDate() {
		
		if (!conset.isEmpty()) conmap = new map<id,Contact>([SELECT Id, MembershipEndDate__c, LastMembershipDate__c FROM Contact WHERE Id in :conset]);
		if (!accset.isEmpty()) accmap = new map<id,Account>([SELECT Id, MembershipEndDate__c, LastMembershipDate__c FROM Account WHERE Id in :accset]);
				
		for (Opportunity o : otp) {
			//Most recent closed/won membership opportunity, and the membership end date.
			date oppdate;
			date enddate;
			
			if (o.ContactId__c!=null) {
				oppdate=conmap.get(o.ContactId__c).LastMembershipDate__c;
				enddate=conmap.get(o.ContactId__c).MembershipEndDate__c;
			} else if (o.AccountId!=null){
				oppdate=accmap.get(o.AccountId).LastMembershipDate__c;
				enddate=accmap.get(o.AccountId).MembershipEndDate__c;
			}
			
			//Only set fields if this opp is newer than the last membership opp
			if (oppdate == null || oppdate < o.CloseDate) {
				//No membership end date: a new membership starts on closedate
				if (enddate==null) {
					o.Membership_Origin__c = 'New';
					o.Membership_Start_Date__c=o.CloseDate;
					
				// Membership end date + renewal period is after this close date: this is a Renewal
				} else if (enddate.addDays(ors.Membership_Renewal_Period__c.intValue()) > o.CloseDate) {
					o.Membership_Origin__c = 'Renewal';
					//if we're rolling start dates, this membership starts when the last one ends, otherwise on Opp CloseDate
					o.Membership_Start_Date__c=(ors.Membership_Rolling_Start_Date__c ? enddate : o.CloseDate);
				
				//Renewal period is passed, this is a reacquire
				} else {
					o.Membership_Origin__c = 'Reacquire';
					o.Membership_Start_Date__c=o.CloseDate;
				}
				
				// end date calculation handles leap years for membership periods that are multiples of 365 in order to preserve anniversary dates
				if (math.mod(ors.Membership_Period__c.intValue(), 365) == 0) 
					o.Membership_End_Date__c=o.Membership_Start_Date__c.addYears(integer.valueOf(ors.Membership_Period__c.intValue() / 365));
				else o.Membership_End_Date__c=o.Membership_Start_Date__c.addDays(ors.Membership_Period__c.intValue());
			}
		}
	}
	
	/********
	* TESTS *
	********/
	
	public static void forceSettings(integer mp, integer mrp, boolean mrsd){
		delete [select Id from OppRollupSettings__c];				 
		OppRollupSettings__c forcedSettings = OppRollupSettings__c.getInstance();
		System.Assert(forcedSettings == null);
		forcedSettings = new OppRollupSettings__c(
			Membership_Period__c=mp,
			Membership_Renewal_Period__c=mrp,
			Membership_Rolling_Start_Date__c=mrsd,
			Membership_Record_Types__c=ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS
		);
		insert forcedSettings;
	}
	
	//Membership dates and origin are set for a new contact
	static testMethod void testNewContactDates(){

		forceSettings(365,100,true);
				 
		Contact con = new Contact (
			LastName='test'	
		);
		insert con;
		
		Opportunity opp = new Opportunity(
			RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
			Name='foo',
			Amount=10,
			ContactId__c=con.id,
			CloseDate=system.today()
		);
		insert opp;
		
		Opportunity queryOpp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id=:opp.id ];
		system.assertequals('New', queryOpp.Membership_Origin__c);
		system.assertequals(system.today(), queryOpp.Membership_Start_Date__c);
		system.assertequals(system.today().addYears(1), queryOpp.Membership_End_Date__c);
	}
	
	//membership dates and origin are not set if the contact has a membership opportunity newer than the one being inserted
	static testMethod void testOldOpp(){
		
		forceSettings(365,100,true);
				 
		Contact con = new Contact (
			LastName='test',
			LastMembershipDate__c=system.today()
		);
		insert con;
		
		Opportunity opp = new Opportunity(
			RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
			Name='foo',
			Amount=10,
			ContactId__c=con.id,
			CloseDate=system.today().addYears(-1)
		);
		insert opp;
		
		Opportunity queryOpp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id=:opp.id ];
		system.assertequals(null, queryOpp.Membership_Origin__c);
		system.assertequals(null, queryOpp.Membership_Start_Date__c);
		system.assertequals(null, queryOpp.Membership_End_Date__c);
	}
	
	//Membership origin is Renewal and start date is set back to the last membership date within the renewal period.
	static testMethod void testRenewalPeriod(){
		
		forceSettings(365,100,true);
				 
		Account acc = new Account (
			Name='test',
			LastMembershipDate__c=system.today().addDays(-400),
			MembershipEndDate__c=system.today().addDays(-50)
		);
		insert acc;
		
		Opportunity opp = new Opportunity(
			RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
			Name='foo',
			Amount=10,
			AccountId=acc.id,
			CloseDate=system.today()
		);
		insert opp;
		
		Opportunity queryOpp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id=:opp.id ];
		system.assertequals('Renewal', queryOpp.Membership_Origin__c);
		system.assertequals(system.today().addDays(-50), queryOpp.Membership_Start_Date__c);
		system.assertequals(system.today().addDays(-50).addYears(1), queryOpp.Membership_End_Date__c);
	}
	
	//Membership origin is Renewal and start date is set back to the last membership date within the renewal period, but rolling start dates are not active.
	static testMethod void testRenewalNoRolling(){
		
		forceSettings(730,100,false);
				 
		Contact con = new Contact (
			LastName='test',
			LastMembershipDate__c=system.today().addDays(-400),
			MembershipEndDate__c=system.today().addDays(-50)
		);
		insert con;
		
		Opportunity opp = new Opportunity(
			RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
			Name='foo',
			Amount=10,
			ContactId__c=con.id,
			CloseDate=system.today()
		);
		insert opp;
		
		Opportunity queryOpp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id=:opp.id ];
		system.assertequals('Renewal', queryOpp.Membership_Origin__c);
		system.assertequals(system.today(), queryOpp.Membership_Start_Date__c);
		system.assertequals(system.today().addYears(2), queryOpp.Membership_End_Date__c);
	}
	
	//Membership end date is in the future, start date is set to future.
	static testMethod void testFutureExpiration(){
		
		forceSettings(100,10,true);
						 
		Contact con = new Contact (
			LastName='test',
			LastMembershipDate__c=system.today().addDays(-50),
			MembershipEndDate__c=system.today().addDays(10)
		);
		insert con;
		
		Opportunity opp = new Opportunity(
			RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
			Name='foo',
			Amount=10,
			ContactId__c=con.id,
			CloseDate=system.today()
		);
		insert opp;
		
		Opportunity queryOpp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id=:opp.id ];
		system.assertequals('Renewal', queryOpp.Membership_Origin__c);
		system.assertequals(system.today().addDays(10), queryOpp.Membership_Start_Date__c);
		system.assertequals(system.today().addDays(110), queryOpp.Membership_End_Date__c);
	}
	
	//Membership origin is Reaquire and start date is opp close date once the renewal period is passed
	static testMethod void testReacquire(){
		
		forceSettings(365,100,true);
				 
		Contact con = new Contact (
			LastName='test',
			LastMembershipDate__c=system.today().addDays(-500),
			MembershipEndDate__c=system.today().addDays(-150)
		);
		insert con;
		
		Opportunity opp = new Opportunity(
			RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
			Name='foo',
			Amount=10,
			ContactId__c=con.id,
			CloseDate=system.today()
		);
		insert opp;
		
		Opportunity queryOpp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id=:opp.id ];
		system.assertequals('Reacquire', queryOpp.Membership_Origin__c);
		system.assertequals(system.today(), queryOpp.Membership_Start_Date__c);
		system.assertequals(system.today().addYears(1), queryOpp.Membership_End_Date__c);
	}
	
	//inserting opportunities in bulk does not exceed governer limits
	static testMethod void testBulkOpp(){
		
		//number of contacts and opps to create
		integer bulkamt = 20;
		
		list<Opportunity> listopp = new list<Opportunity>();
		list<Contact> listcon; 
		
		forceSettings(365,100,true);
		
		listcon = ONEN_UnitTestData.CreateMultipleTestContacts(bulkamt);
		
		insert listcon;
		
		for (Integer i=0; i<bulkamt; i++){
			Opportunity o = new Opportunity(
				RecordTypeId=GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS),
				ContactId__c = listcon[i].id,
				Amount = 1+i,
				CloseDate = system.today()
			);
			listopp.add(o);
		}
		
		test.startTest();
		insert listopp;
		test.stopTest();
		
		list<Opportunity> queryopp = [SELECT Id, Membership_Origin__c, Membership_Start_Date__c, Membership_End_Date__c FROM Opportunity WHERE Id IN :listopp ];
		
		for (Opportunity o : queryopp){
			system.assertequals('New', o.Membership_Origin__c);
			system.assertequals(system.today(), o.Membership_Start_Date__c);
			system.assertequals(system.today().addYears(1), o.Membership_End_Date__c);
		}
	}

	/*static testMethod void testConMerge(){
		list<Contact> lcon = new list<Contact>();
		
	}*/
	
}