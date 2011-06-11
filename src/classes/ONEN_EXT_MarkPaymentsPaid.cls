public with sharing class ONEN_EXT_MarkPaymentsPaid {
// Written by Dave Manelski, copyright (c) 2009 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    private List<OppPayment__c> selectedInstallments;
    private String mark;    
    
    //have to instantiate with StandardSetController for list buttons
    public ONEN_EXT_MarkPaymentsPaid(ApexPages.StandardSetController controller) {
        //get the selected ids that were checked
        this.selectedInstallments = (List<OppPayment__c>)controller.getSelected();
        //thisYear = string.valueOf(system.Today().Year());
        // mark = ApexPages.currentPage().getParameters().get('mark');
    }
    
    public pageReference markInstallmentsPaid() {
        mark='paid';
        PageReference p = markInstallments();
        return p;
    }
    
    public pageReference markInstallmentsWrittenOff() {
        mark='writeoff';
        PageReference p = markInstallments();
        return p;
    }
    
    pageReference markInstallments() {
        //get all the installments that were selected
        List<OppPayment__c> InstallmentsFromSelection = [select Id,paid__c from OppPayment__c where Id IN :selectedInstallments];
        if (InstallmentsFromSelection.size()>0) {
            for (OppPayment__c thisInstallment : InstallmentsFromSelection) {
                //if we're passing in paid on the querystring, mark them paid
                if(mark=='paid') {
                    thisInstallment.paid__c=true;
                    thisInstallment.Written_Off__c=false;
                } else if(mark=='writeoff') {
                    thisInstallment.Written_Off__c=true;
                    thisInstallment.paid__c=false;                  
                }
            }
                
            update InstallmentsFromSelection;
        }
        PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
        
    }

    /* TESTS */

    private static testMethod void TestMarkAsPaid() {
    
    //create first contact
      Contact firstContact = new Contact (
      FirstName='Joe',
      LastName='Schmoe_for_tests'
      );
      insert firstContact;
    
    //new opp for contact
    Opportunity firstOpp = new Opportunity (
        RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
        Name = 'Test first contact opp',
        amount=100,
        StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
        CloseDate=Date.newInstance(2005,10,10),
        CR_Contact_Id__c = firstContact.id,
        CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
    );
    
    insert firstOpp;
    
    OppPayment__c firstPayment = new OppPayment__c (
        Opportunity__c = firstOpp.id,
        Opp_For_Installment__c = firstOpp.id,
        IsInstallment__c = true,
        paid__c=false,
        Date__c = Date.newInstance(2005,10,10),
        Amount__c = 10
    );
    
    insert firstPayment;
    
    List<OppPayment__c> selectedInstallments = new List<OppPayment__c>();
    
    selectedInstallments.add(firstPayment);
    
    PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
    Test.setCurrentPage(p);
    
    //pass selected opportunities into the controller
    ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedInstallments);
    sc.setSelected(selectedInstallments);
    ApexPages.currentPage().getParameters().put('mark', 'paid');
    //pass the controller into the extension
    ONEN_EXT_MarkPaymentsPaid ext = new ONEN_EXT_MarkPaymentsPaid(sc);
    
    ext.markInstallmentsPaid();
    
    OppPayment__c[] payments = [SELECT id, paid__c FROM OppPayment__c where id = :firstPayment.id ];
    system.assertEquals(1,payments.size());
    System.assertEquals(true,payments[0].paid__c);
    
    }
        
    private static testMethod void TestMarkWriteOff() {
    
    //create first contact
      Contact firstContact = new Contact (
      FirstName='Joe',
      LastName='Schmoe_for_tests'
      );
      insert firstContact;
    
    //new opp for contact
    Opportunity firstOpp = new Opportunity (
        RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
        Name = 'Test first contact opp',
        amount=100,
        StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
        CloseDate=Date.newInstance(2005,10,10),
        CR_Contact_Id__c = firstContact.id,
        CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
    );
    
    insert firstOpp;
    
    OppPayment__c firstPayment = new OppPayment__c (
        Opportunity__c = firstOpp.id,
        Opp_For_Installment__c = firstOpp.id,
        IsInstallment__c = true,
        paid__c=false,
        Date__c = Date.newInstance(2005,10,10),
        Amount__c = 10
    );
    
    insert firstPayment;
    
    List<OppPayment__c> selectedInstallments = new List<OppPayment__c>();
    
    selectedInstallments.add(firstPayment);
    
    PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
    Test.setCurrentPage(p);
    
    //pass selected opportunities into the controller
    ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedInstallments);
    sc.setSelected(selectedInstallments);
    // ApexPages.currentPage().getParameters().put('mark', 'writeoff');
    //pass the controller into the extension
    ONEN_EXT_MarkPaymentsPaid ext = new ONEN_EXT_MarkPaymentsPaid(sc);
    
    ext.markInstallmentsWrittenOff();
    
    OppPayment__c[] payments = [SELECT id, written_off__c FROM OppPayment__c where id = :firstPayment.id ];
    system.assertEquals(1,payments.size());
    System.assertEquals(true,payments[0].written_off__c );
    
    }

}