public class ONEN_CTRL_InstallmentWizard {
// Written by Matthew Scholtz, copyright (c) 2008 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	//Opportunity for the opp we're coming from
    private final Opportunity currentOpp;
    
    //opp payment object for form field binding
    public OppPayment__c thisInstallment;
    
    //the integer value from the form
    private Integer selectedInstallmentCount;
    
    //constructor gets the opp from the passed in Id
    public ONEN_CTRL_InstallmentWizard() {
    	//query of current opp
        currentOpp= [select name, amount, stagename, description, closedate, total_unpaid__c from Opportunity where id =:ApexPages.currentPage().getParameters().get('id')];
    }
    
    //get the current opportunity
    public Opportunity getCurrentOpp() {
    	return currentOpp;
    }
    
    //list of items for picklist of the number of payments to be created
    public List<SelectOption> getItems() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('1','1'));
        options.add(new SelectOption('2','2'));
        options.add(new SelectOption('3','3'));
        options.add(new SelectOption('4','4'));
        options.add(new SelectOption('5','5'));
        options.add(new SelectOption('6','6'));
        options.add(new SelectOption('7','7'));
        options.add(new SelectOption('8','8'));
        options.add(new SelectOption('9','9'));
        options.add(new SelectOption('10','10'));
        options.add(new SelectOption('11','11'));
        options.add(new SelectOption('12','12'));
        return options;
    }
    
    //integer for the number of installments to create
    public Decimal numberofinstallments { get {return numberofinstallments;} set {numberofinstallments = value;} }
    public boolean multipleinstallments { get {return (numberofinstallments > 1);} }
    
    //integer to hold the interval chosen
    public Integer interval { get {return interval;} set {interval = value;} }    
    
    //list of items for picklist of the interval between payments to be created
    public List<SelectOption> getIntervals() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('1','1'));
        options.add(new SelectOption('2','2'));
        options.add(new SelectOption('3','3'));
        options.add(new SelectOption('4','4'));
        options.add(new SelectOption('5','5'));
        options.add(new SelectOption('6','6'));
        options.add(new SelectOption('7','7'));
        options.add(new SelectOption('8','8'));
        options.add(new SelectOption('9','9'));
        options.add(new SelectOption('10','10'));
        options.add(new SelectOption('11','11'));
        options.add(new SelectOption('12','12'));
        return options;
    }
    
    //the unit of the interval
    public String intervalUnit { get {return intervalUnit;} set {intervalUnit = value;} }
    
    //list of items for picklist of the interval unit between payments to be created
    public List<SelectOption> getIntervalUnits() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('Week','Week'));
        options.add(new SelectOption('Month','Month'));
        options.add(new SelectOption('Year','Year'));
        return options;
    }
    
    //list to hold new payments
    private List<OppPayment__c> newPayments = new List<OppPayment__c>();
    
    //get the payments
    public List<OppPayment__c> getPayments() {
    	//empty out the list if we've used it before
        newPayments.clear();
		//divide the amount by the number of installments, and deal with the remainder - can't get this to work
        Decimal paymentCount = 1;
        //set the real value if we've got one
         if(numberofinstallments!=null){
        	paymentCount = numberofinstallments;
        }
        
        // get the opp amount
        // ejc 8/3/10 - for a partially paid opp, start with the remaining unpaid amount
        Decimal thisOppAmount = (currentOpp.Total_Unpaid__c != null &&
        	currentOpp.Total_Unpaid__c > 0) ? currentOpp.Total_Unpaid__c : 
        	(currentOpp.Amount != null) ? currentOpp.Amount : 0; 
        
        //get the amount of each payment
        Decimal paymentAmount = thisOppAmount/paymentCount; 
        //round it
        Integer roundedPayment = paymentAmount.intValue();
        //get the remainder into the last payment amount
        Decimal finalPayment = thisOppAmount - (roundedPayment*(paymentCount-1));
        
        Date paymentDate = System.Today();
        //get the real date if there is one
        if (thisInstallment!=null) {
	        if (thisInstallment.Date__c!=null) {        	
	        	paymentDate = thisInstallment.Date__c;
	        }
        }
        //loop through creating new payment objects
        for(Integer installmentcounter=1;(installmentcounter-1)<numberofinstallments;installmentcounter++){
        	
     		//do the math of interval times interval unit and adding to the first payment date
     		//if we're on the second payment or higher
     		if (installmentcounter>1) {
     			//check the interval unit and do the math
	     		if (intervalUnit=='Year') {
	     			paymentDate=paymentDate.addYears(interval);
	     		} else if (intervalUnit=='Month') {
	     			paymentDate=paymentDate.addMonths(interval);
	     		} else if (intervalUnit=='Week') {
	     			paymentDate=paymentDate.addDays(interval*7);
	     		} 
     		}
     		//create the payment objects
            OppPayment__c firstOppPayment = new OppPayment__c();  
            
            firstOppPayment.Opportunity__c=currentOpp.id;
            //hack: we're using the Check Number field to easily display the payment number.
            //we throw it away later
            firstOppPayment.Check_Number__c='Payment # ' + installmentcounter;
            firstOppPayment.Opp_For_Installment__c=currentOpp.id;
            firstOppPayment.Date__c=paymentDate;
            firstOppPayment.IsInstallment__c=true;
            
            //use the rounded payment unless we're on the last one, then use the final payment
            if(installmentcounter==numberofinstallments) {
            	firstOppPayment.Amount__c = finalPayment;
            } else {
            	firstOppPayment.Amount__c = roundedPayment;
            }
            //put them in the list
            newPayments.add(firstOppPayment);
        }
        
        return newPayments ;
    }
    //this object is used for the input form for creating multiple payments
    public OppPayment__c getThisInstallment() {
        if (thisInstallment== null) thisInstallment = new OppPayment__c(Date__c=currentOpp.closedate);
        return thisInstallment;
    }
	//create the new payments
    public PageReference createInstallments() {
    	//loop through, blanking out the bogus values in check number
    	for (OppPayment__c thisPayment : newPayments) {
    		thisPayment.Check_Number__c=null;
    	}
        insert newPayments;
        
        List<OppPayment__c> mirrorOppPaymentsToDelete = new List<OppPayment__c>();  
        mirrorOppPaymentsToDelete = [Select Id from OppPayment__c where IsInstallment__c=false and Opportunity__c=:currentOpp.id];
        if(mirrorOppPaymentsToDelete.size()>0){
        	delete mirrorOppPaymentsToDelete;
        }
        // Send the user to the detail page for the Opp.
        PageReference oldOppPage = new PageReference('/' + currentOpp.id);
        oldOppPage .setRedirect(true);
        return oldOppPage;
    }
   
    ////////////////////   TESTS    /////////////////////////////
    
    static testmethod void TestInstallments () {
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.installmentWizard'));
		
		//create an opportunity
		Opportunity firstOpp = new Opportunity (
			Name='Test Opp',
			StageName = ONEN_Constants.OPP_DEFAULT_STAGE,
			CloseDate = System.Today(),
			Amount=100			
		);
		
		insert firstOpp;
		//trigger will have created one mirror payment
		
		//get the created opp Id
		ApexPages.currentPage().getParameters().put('id', firstOpp.id);
		//instantiate the controller for this opp
		ONEN_CTRL_InstallmentWizard controller = new ONEN_CTRL_InstallmentWizard();
				
				
		system.AssertNotEquals(0,controller.getItems().size());
		system.AssertNotEquals(0,controller.getIntervals().size());
		system.AssertNotEquals(0,controller.getIntervalUnits().size());
		//set the interval unit	
		String unit = 'Year';	
		controller.Intervalunit = unit;
		system.AssertEquals(unit,controller.Intervalunit);
		
		//set the number of installments
		Integer paymentCount = 3;
		controller.numberofinstallments = paymentCount;
		system.AssertEquals(paymentCount,controller.numberofinstallments);
		
		//set the interval
		Integer intervalCount = 2;
		controller.interval = intervalCount;
		system.AssertEquals(intervalCount,controller.interval);
		
		//a list for the new payments
		List<OppPayment__c> newPayments = new List<OppPayment__c>();
		//create the new payment objects
		newPayments = controller.getPayments();
		
		//there should be the payment count
		system.AssertEquals(paymentCount,newPayments.size());
		
		//create the installments
		controller.createInstallments();
		
		//query the newly created installments
		OppPayment__c[] createdPayments = [select Id,IsInstallment__c,Date__c from OppPayment__c where Opportunity__c =:firstOpp.id ORDER BY Date__c];
			system.debug ('installments created: ' + createdPayments);
		//should match the payment count
		system.AssertEquals(paymentCount,createdPayments.size());
		//date should be the same
		system.AssertEquals(system.Today(),createdPayments[0].Date__c);
		//next payment date should be out the interval
		system.AssertEquals(system.Today().addYears(intervalCount),createdPayments[1].Date__c);		
		
 		// now chg the Opp's amount & stage, the installments shouldn't chg
		firstOpp.Amount = 1500;
		firstOpp.StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE;
		update firstOpp;
		
		OppPayment__c[] Installments = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id ORDER BY Date__c];
		System.AssertEquals ( paymentCount , Installments.size() );
		
		OppPayment__c OP1 = Installments[0];
		System.AssertEquals ( 33, OP1.Amount__c);
		System.AssertEquals ( firstOpp.CloseDate, OP1.Date__c);
		System.AssertEquals ( true , OP1.IsInstallment__c);
		System.AssertEquals ( false , OP1.Paid__c);
		
		// now delete all the installments
		// we should end up w/ one mirror pmt
		
		delete Installments;
		 
		Installments = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id];
		System.AssertEquals ( 1 , Installments.size() );
		
		OP1 = Installments[0];
		System.AssertEquals ( 1500, OP1.Amount__c);
		System.AssertEquals ( firstOpp.CloseDate, OP1.Date__c);
		System.AssertEquals ( false , OP1.IsInstallment__c);
		System.AssertEquals ( true , OP1.Paid__c);
		
	}
	
}