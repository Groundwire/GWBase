public class ONEN_OpportunityInstallments {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
  
	public static void CreateMirrorPayments(list<Opportunity> listOpps) {
		// every time we add an opp, create a non-installment payment obj that mirrors the opp
		// (contains same amount and date)
		// most field assignment is handled by workflow, all we have to do is create the obj	
		// TBD - maybe want list of rectypes that shouldn't trigger this?? (non-financial opps?)
	
		list<OppPayment__c> OPToCreate = new list<OppPayment__c> ();
			
		if ( listOpps.size() > 0 ) {
			OPToCreate = ONEN_OpportunityInstallments.GetMirrorPayments (listOpps);	
		}
	
		//system.debug ('Payments to create: ' + OPToCreate.size() );
		if ( OPToCreate.size() > 0 ) {
			insert OPToCreate;
		}			
	}    

	public static void CheckMirrorPayments(list<Opportunity> listOppsNew, map<id, Opportunity>mapOppsOld) {	
		// if an opp has no installments (meaning it only has a single "mirror" payment
		// we want to update that mirror whenever the Opp chgs date / Amt / Stage
		
		set<id> OppsToUpdate = new set<id>();
		map<id,Opportunity> oppUpdateMap = new map<id,Opportunity>();
		
		for (Opportunity thisOpp : listOppsNew) {
			Opportunity oldOpp = mapOppsOld.get(thisOpp.id);
			
			// see if any of the relevant fields have changed
			if ( 	thisOpp.Amount != oldOpp.Amount ||
					thisOpp.StageName != oldOpp.StageName ||
					thisOpp.CloseDate != oldOpp.CloseDate ||
					thisOpp.Check_Number__c != oldOpp.Check_Number__c ||
					thisOpp.Check_Date__c != oldOpp.Check_Date__c
			) {
				// if so, add to set for processing	
				oppUpdateMap.put(thisOpp.id, thisOpp);
			}	
			
			if (!oppUpdateMap.isEmpty()) ONEN_OpportunityInstallments.updateMirrorPayments(oppUpdateMap);
		}			
	}
	
    private static void updateMirrorPayments (map<id,Opportunity> OppsToUpdateMap) {
        // get the mirror payments that exist (by excluding those w/ Installment flag set)
        // if that flag is set, it's an installment & we don't want to touch it 
        OppPayment__c[] OppPayments = [SELECT id, Opportunity__r.Check_Number__c, Opportunity__r.Check_Date__c, Opportunity__r.Amount,
                                       Opportunity__r.CloseDate, Opportunity__r.IsWon,
                                       IsInstallment__c FROM OppPayment__c WHERE IsInstallment__c = false AND Opportunity__c 
                                       IN :OppsToUpdateMap.keyset() ];
            
        if ( OppPayments.size() > 0 ) {
        
            // for the mirror payments we found, update the fields to keep in sync between opp and payment
            for ( OppPayment__c thisPaymt : OppPayments ) {
                // system.debug ('paymt before update: ' + thisInst);
                thisPaymt.Paid__c = ( thisPaymt.Opportunity__r.IsWon && !thisPaymt.IsInstallment__c) ? true : false;
                thisPaymt.Check_Number__c = thisPaymt.Opportunity__r.Check_Number__c;
                thisPaymt.Check_Date__c = thisPaymt.Opportunity__r.Check_Date__c;
                thisPaymt.Amount__c = thisPaymt.Opportunity__r.Amount;
                thisPaymt.Date__c = thisPaymt.Opportunity__r.CloseDate;
                //system.debug ('paymt after update: ' + thisInst);
            }
        
            update OppPayments;
        }
    }	

    public static void SyncTotalPaymentAmount (list<OppPayment__c> listOppPayments, map<id, OppPayment__c> mapOldOppPayments, boolean isInsert, boolean isDelete) {
    
    	// update the amount on opps when a payment changes	    	
    	set<id> changedAmtOpps = new set<id>();
    	set<id> changedPmtStateOpps = new set<id>();
	
    	// get list of payments for which the amount has changed (including new or deleted payments)
    	// also get the list of opps for which payments have been marked paid or written off
    	for ( OppPayment__c op : ((listOppPayments != null) ? listOppPayments : mapOldOppPayments.values())) {
    		if ( op.IsInstallment__c ) {
    			changedPmtStateOpps.add(op.opportunity__c);
	    		if ( isInsert || isDelete || op.amount__c != mapOldOppPayments.get(op.id).amount__c )
	    			changedAmtOpps.add(op.opportunity__c);
    		}
    	}    		
    		
    	map<id, opportunity> oppsToUpdate = new map<id, opportunity>();
    	
    	// aggregate the total payment amount for each affected opportunity
		for ( aggregateResult result : 
			[SELECT opportunity__c, sum(amount__c) amt FROM OppPayment__c WHERE IsInstallment__c = true
				AND Opportunity__c IN :changedAmtOpps GROUP BY opportunity__c]) {
					oppsToUpdate.put((id)(result.get('opportunity__c')),
						new Opportunity(
							id = (id)(result.get('opportunity__c')), 
							amount = (decimal)(result.get('amt'))
						));
		}
		
			
		string closedStage = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE;
		for (opportunity o : [select id, stageName from opportunity where id in :changedPmtStateOpps and 
			id not in (select opportunity__c from oppPayment__c where paid__c = false and written_off__c = false)
			and stageName != : closedStage]) {
			
			if (oppsToUpdate.containsKey(o.id)) {
				oppsToUpdate.get(o.id).stagename = closedStage;
			} else {
				oppsToUpdate.put(o.id, 
					new Opportunity(
						id = o.id, stagename = closedStage
					));
			}                                  
		}    
		
		// save the new amounts
		if (!oppsToUpdate.isEmpty())
			update oppsToUpdate.values(); 			
    }

    public static void DeleteMirrors (list<OppPayment__c> listOppPayments) {
    
    	// update the amount on opps when a payment changes	    	
    	set<id> oppsWithInsertedPayments = new set<id>();
	
    	// get list of payments for which the amount has changed (including new or deleted payments)
    	for ( OppPayment__c op : listOppPayments) { 
    		if (op.isInstallment__c) 
    			oppsWithInsertedPayments.add(op.opportunity__c);
    	}    		

    	delete ([select id from oppPayment__c where 
    		opportunity__c in : oppsWithInsertedPayments and isInstallment__c = false]);     		
    }	

/*	Opps w/ installments are no longer used for recurring payments, so there is no scenario of the user marking the opp as discontinued.

	public static void WriteOffUpcomingPayments(Opportunity oppNew, Opportunity oppOld) {
		// Written by Dave Manelski, copyright (c) 2009 ONE/Northwest
		// if an opp is a monthly payment and is marked as discontinued,
		// we want to update the upcoming unpaid installment payments to Written Off
		// trigger written for a single update only, does not work in bulk
	 
		if (trigger.size==1 && oppNew.Monthly_Gift_Discontinued_Date__c != null && oppOld.Monthly_Gift_Discontinued_Date__c == null) {
	
			// get the installment payments for this opp
			OppPayment__c[] OppPayments = [SELECT id, Written_Off__c FROM OppPayment__c WHERE IsInstallment__c = true AND Paid__c = false AND Opportunity__c = :oppNew.id];
	   
			if ( OppPayments.size() > 0 ) {
	  
				// for the mirror payments we found, set the written off flag
				for ( OppPayment__c thisPaymt : OppPayments ) {
					thisPaymt.Written_Off__c = true;
				}
	  
				update OppPayments;
			}
		}
	}
*/    
    private static list<OppPayment__c> GetMirrorPayments ( list<Opportunity> OppsToMirror ) {
    
        list<OppPayment__c> OPToCreate = new list<OppPayment__c>();
    
        for ( Opportunity thisOpp: OppsToMirror ) {
            
            boolean IsWon = thisOpp.IsWon;
            boolean IsPaid = ( IsWon ) ? true : false;
            
            OppPayment__c newInst = new OppPayment__c ( 
                Opportunity__c = thisOpp.Id,
                IsInstallment__c = false,
                Amount__c = thisOpp.Amount,
                Date__c = thisOpp.CloseDate,
                Paid__c = IsPaid,
                Check_Number__c = thisOpp.Check_Number__c,
                Check_Date__c = thisOpp.Check_Date__c
            );
            OPToCreate.add (newInst);
        }
        
        return OPToCreate;
        
    }
    
	public static void ConvertDeletedInstallmentsToMirror(list<OppPayment__c> listOppPayments) {    
		// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
		// if a user tries to delete the last installment on an opp, create a mirror pmt to take its place
		// but only if the opp hasn't also been deleted
		
		// as of now (1/23/08), cascade deletes don't fire apex delete triggers, so this shouldn't be an issue
		// but we'll handle it in an attempt to future-proof this
		
		set<id> OppsToCheck = new set<id> ();
		list<Opportunity> OppsToMirror = new list<Opportunity> ();
		list<OppPayment__c> OPToCreate = new list<OppPayment__c> ();
		map<id,integer> PmtCountsPerOpp = new map<id,integer>();
		
		for ( OppPayment__c thisPmt : listOppPayments ) {
			OppsToCheck.add (((OppPayment__c)thisPmt).Opportunity__c);
		}
		
		//system.debug ('TEST>>>> OppsToCheck: ' + OppsToCheck);
		
		Opportunity[] OppsWithPmtsLeft = [SELECT id, Name, Amount, CloseDate, IsWon, Check_Number__c, Check_Date__c, (SELECT id, IsInstallment__c FROM Payments__r) FROM Opportunity WHERE id IN :OppsToCheck ]; 
		
		for ( Opportunity thisOpp : OppsWithPmtsLeft ) {
			//system.debug ('TEST>>>> Opp being checked: ' + thisOpp);
			// if ( thisOpp.payments__r == null ) {
			if ( thisOpp.Payments__r.size() == 0 ) {
				OppsToMirror.add (thisOpp);	
			}	
		}
		
		if ( OppsToMirror.size() > 0 ) {
			OPToCreate = ONEN_OpportunityInstallments.GetMirrorPayments (OppsToMirror);	
		}
	
		//system.debug ('Payments to create: ' + OPToCreate.size() );
	
		if ( OPToCreate.size() > 0 ) {
			insert OPToCreate;
		}				
	}    
    
	/*------------------------------------------------------------------------------------
	* createInstallmentList method
	* set up payments for the specified timeframe then set the total opp amount
	-------------------------------------------------------------------------------------*/
	public static list<OppPayment__c> createInstallmentList(
		Opportunity opp, 
		Date dateStart,
		decimal decPmtAmount,
		integer cFrequency,
		string strPeriod,
		integer cInstallments) {
						
		list<OppPayment__c> listPmt = new list<OppPayment__c>();
		decimal decOppTotal = 0; 
		date dateNextPmt = dateStart;	
		
		for (integer i = 0; i < cInstallments; i++) {
			listPmt.add(
				new OppPayment__c(
					Amount__c = decPmtAmount,
					Date__c = dateNextPmt,
					isInstallment__c = true,
					paid__c = false
				)
			);
			decOppTotal += decPmtAmount;
			
			dateNextPmt = 
				(strPeriod == 'Day') ? dateNextPmt.addDays(cFrequency) :
				(strPeriod == 'Week') ? dateNextPmt.addDays(cFrequency * 7) :
				(strPeriod == 'Year') ? dateNextPmt.addYears(cFrequency) :
				dateNextPmt.addMonths(cFrequency); 

		}	
			
		// set the opp amount
		opp.Amount = decOppTotal;
		
		return listPmt;
	}

    
////////////////////////////////////////////////////////////////////////////////////////////
// TEST CODE
///////////////////////////////////////////////////////////////////////////////////////////
    
    private static string MbrRectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
    private static string GiftRectype = ONEN_Constants.OPP_NONMEMBER_RECTYPE_FORTESTS;
     
    static testMethod void testMirrorPaymentCreate () {
      
        Date datToday = System.Today();
        Date datClose = datToday;
           
        // create & insert Account
        Account[] TestAccts = ONEN_UnitTestData.CreateMultipleTestAccounts(1) ;
        insert TestAccts;
          
        Account Acct1 = TestAccts[0];
          
        // create & insert grant opp
        Opportunity[] TestOpps = ONEN_UnitTestData.OppsForAccountList (TestAccts, null, ONEN_Constants.OPP_DEFAULT_STAGE, datClose, 1000, GiftRectype);
        insert TestOpps;
          
        Opportunity Opp1 = TestOpps[0];
          
        // test that a mirror payment was created
        OppPayment__c[] mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
          
        OppPayment__c OP1 = mirrorOPs[0];
        System.AssertEquals ( 1000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( false , OP1.Paid__c);
          
        // now chg the amt of the opp, test that mirror chgs too
        system.debug ('TEST>>>> chging Amount of Opp..');
        Opp1.Amount = 2000;
        update Opp1;
          
        mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
          
        OP1 = mirrorOPs[0];
        System.AssertEquals ( 2000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
          
        // now chg opp to ClosedWon, make sure mirror goes to Paid
        system.debug ('TEST>>>> chging Opp to ClosedWon..');
        system.debug ('TEST>>>> Paymt before chg: ' + OP1);
        Opp1.StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE;
        update Opp1;
          
        mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
          
        OP1 = mirrorOPs[0];
        system.debug ('TEST>>>> Paymt after chg: ' + OP1);
        
        System.AssertEquals ( 2000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( true , OP1.Paid__c);
          
        // now delete the Payment, trigger should create a new mirror
        delete mirrorOPs;
          
        mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
        OP1 = mirrorOPs[0];
        System.AssertEquals ( 2000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( true , OP1.Paid__c);
          
    }

// OppPayments no longer writeoff their siblings.  this is handled at the RecurringPaymentProfile object.
// thus this test is no longer appropriate.
/*     
	static testMethod void discontinuePayments() {
        
		//create an opportunity
		Opportunity firstOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name='Test Opp',
			StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,
			CloseDate = System.Today(),
			Amount=100			
		);
		
		insert firstOpp;
			
		//now create a bunch of payments
		List<OppPayment__c> paymentsToCreate = new List<OppPayment__c>();
		OppPayment__c p1 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today(),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = True 
		);
		paymentsToCreate.add(p1);
		
		OppPayment__c p2 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today().addDays(10),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = False 
		);
		paymentsToCreate.add(p2);
		
		OppPayment__c p3 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today().addDays(20),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = False 
		);
		paymentsToCreate.add(p3);
		
		OppPayment__c p4 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today().addDays(30),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = False 
		);
		paymentsToCreate.add(p4);
		
		if (paymentsToCreate.size()>0) {
			insert paymentsToCreate;
		}
		
		//now update the opp to discontinue payments
		firstOpp.Monthly_Gift_Discontinued_Date__c = Date.today();
		update firstOpp;
		
		//SOQL the results to find out if trigger fired and remaining unpaid payments were set to written off
    	OppPayment__c[] writtenOffPayments = [SELECT Written_Off__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id AND IsInstallment__c = true AND Written_Off__c = true];
    	System.assertEquals(writtenOffPayments.size(),3);
    
    }
*/
    static testMethod void testInstallmentManagement () {
	// test that adding an installment payment updates the opp amount AND deletes the mirror payment,
	// and that marking the last installment paid closes the opp

        // create & insert Account
        Account[] TestAccts = ONEN_UnitTestData.CreateMultipleTestAccounts(1) ;
        insert TestAccts;
        Account Acct1 = TestAccts[0];
          
        // create & insert opp
        Opportunity[] TestOpps = ONEN_UnitTestData.OppsForAccountList (TestAccts, null, ONEN_Constants.OPP_DEFAULT_STAGE, System.Today(), 1000, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
        insert TestOpps;          
        Opportunity Opp1 = TestOpps[0];

        // insert an installment
		OppPayment__c installment = new oppPayment__c(opportunity__c = opp1.id, amount__c = 123);
		insert installment;
		
		// did the opp amount get updated?
		Opportunity[] opp2 = [SELECT id, stagename, Amount FROM Opportunity WHERE id = :Opp1.id];
		system.assertEquals(123, opp2[0].amount);
		system.assertNotEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, opp2[0].stagename);
        
		// did the mirror payment get deleted?
        OppPayment__c[] mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c 
        	WHERE isInstallment__c = false and Opportunity__c = :Opp1.id];
        system.assertEquals(0, mirrorOPs.size());
          
        // mark the installment paid
		installment.paid__c = true;
		update installment;
		
        // did the opp get the stage change 
		Opportunity[] opp3 = [SELECT id, stagename, amount FROM Opportunity WHERE id = :Opp1.id];
		system.assertEquals(123, opp3[0].amount);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE, opp3[0].stagename);
    }	
}