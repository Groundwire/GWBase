// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author Evan Callahan
* @date 12/01/2010
* @description Batch apex class that marks duplicate household members in a campaign. Checkbox field on 
* Campaign Member called Household Duplicate, which can be used to filter campaign member reports. This class
* is called from a Visualforce Command Link on the Campaign page (which passes in the Campaign Id).  The VF page
* directs the user to the campaign member report with the Household Duplicate filter after running this batch.
*/
global class GW_BATCH_MarkCampaignHHDupes implements Database.Batchable<SObject>, Database.Stateful {


    // the query you send to this batch must be campaign members, 
    // because they are in HH id order, we can always tell if this is the first one in the HH
    // we use "stateful" so the lastHHid crosses batches of 200
    public String query { get; set; }           // this must be campaign members 
    
    // need to keep track of the last Id in the previous batch
    private id lastHHid; 

    /*******************************************************************************************************
    * @description standard batch start method, must be global
    * @param bc Database.BatchableContext - standard batch start method argument
    * @return query - my chunk of records from the batch query, to process
    */ 
    global database.Querylocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);      
    }

    /*******************************************************************************************************
    * @description standard batch execute method.  Tallies up people in a household and marks additional household members in the 
    * campaign with the Household Duplicate checkbox on campaign member.
    * @param bc - Database.BatchableContext - standard batch execute method argument
    * @param scope - list of sobjects - standard batch execute method argument
    */ 
    global void execute(Database.BatchableContext bc, Sobject[] scope) {
        
        // update this set up 200 household members as to whether they are duplicates
        list<campaignMember> cmsForUpdate = new list<campaignMember>();
        for (sobject sobj : scope) {
            campaignMember cm = (campaignMember)(sobj);
            id thisHHid = cm.contact.onen_household__c;
            cmsForUpdate.add( 
                new CampaignMember( id = ((id)(sobj.get('id'))), household_duplicate__c = (thisHHid == lastHHid) )
            );
            lastHHid = thisHHid;
        }       
        update cmsForUpdate;
    }
    
    /*******************************************************************************************************
    * @description standard batch finish method, must be global, nothing to see here
    * @param bc - Database.BatchableContext - standard batch finish argument
    */ 
    global void finish(Database.BatchableContext bc) {
    }
    
    public static testMethod void testBatchDedupe() {
        // create test data
        Contact[] testCons = New list<contact> ();
        list<ONEN_Household__c> hhs = new list<ONEN_Household__c>();
        
        //have to create hhs by hand since we don't do this automatically as of 11/2011
        for (integer i=0;i<50;i++) {
            ONEN_Household__c hh = new ONEN_Household__c(Name='Foo');
            hhs.add(hh);
        }
        insert hhs;
        
        for (integer i=0;i<50;i++) {
            Contact newCon = New Contact (
                FirstName = 'Number' + i,
                LastName = 'Doppleganger',
                ONEN_Household__c = hhs[i].id,
                OtherCity = 'Seattle'
            );
            testCons.add (newCon);
        }
        insert testCons;       
        Contact[] testConHHs = [select id, onen_household__c from contact where id in : testCons limit 8];
        
        Contact[] testCons2 = New list<contact> ();
        for (integer i=0;i<10;i++) {
            Contact newCon = New Contact (
                FirstName = 'Spouse' + i,
                LastName = 'Doppleganger',
                OtherCity = 'Seattle',
                onen_household__c = testConHHs[((i<8) ? i : 7)].onen_household__c
            );
            testCons2.add (newCon);
        }
        insert testCons2;       

        lead ld = new lead(lastname = 'nobody');
        insert ld;
        
        Campaign cmp0 = new Campaign (
            Name='Target',
            IsActive=true
        );
        insert cmp0;

        // add a few contacts to each campaign - some should overlap
        campaignmember[] cms = new campaignmember[0];
        for (integer i = 0; i < 50; i++) {
            cms.add(new campaignmember(campaignId = cmp0.Id, contactId = testCons[i].id));
        }
        for (integer i = 0; i < 10; i++) {
            cms.add(new campaignmember(campaignId = cmp0.Id, contactId = testCons2[i].id));
        }
        cms.add(new campaignmember(campaignId = cmp0.Id, leadId = ld.id));                  

        insert cms;
        
        Test.startTest();
            
        GW_BATCH_MarkCampaignHHDupes bcc;
        
        // instantiate the class
        bcc = new GW_BATCH_MarkCampaignHHDupes();
        
        // set the batch query text
        bcc.query = GW_Utilities.StrAllNSPrefix('SELECT id, contact.onen_household__c FROM campaignmember ' +
            'WHERE campaignid = \'' + cmp0.id + '\' AND contact.onen_household__c != null ' +
            'ORDER BY contact.onen_household__c, contact.createddate limit 200'); 
        id batchProcessId = database.executeBatch(bcc);
        
        // this is critical - otherwise no test runs
        Test.stopTest();        

        // make sure 10 out of 60 got marked dupe
        campaignmember[] cm1 = [SELECT id FROM campaignmember WHERE campaignid = : cmp0.id AND household_duplicate__c = false];
        campaignmember[] cm2 = [SELECT id FROM campaignmember WHERE campaignid = : cmp0.id AND household_duplicate__c = true];
        system.assertEquals(51, cm1.size());
        system.assertEquals(10, cm2.size());
    }   
}