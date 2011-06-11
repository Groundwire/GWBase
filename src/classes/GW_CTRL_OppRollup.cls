public class GW_CTRL_OppRollup {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* controller for Opportunity Rollup visualforce page
* allows rolling up opps for all accounts, contacts, and households, or just one
*
* page can be called with or without optional parameter as follows:
*   /apex/OpportunityRollup?id=[target-object-id]
*
* which will roll up opps for a single account, contact, or household
*
-----------------------------------------------------------------------------------------------*/

//foo, here is my change 

    // properties for page
    public boolean batching { get; set; }
    public boolean batchRunning { get; set; }

    // object id passed in via parameter
    string objectId;
    id oid;

    // constructor
    public GW_CTRL_OppRollup() {
        batchRunning = false;

        // get parameter if any
        try {
            objectId = ApexPages.currentPage().getParameters().get('id');
            oid = objectId;
        } catch (exception e) {     
        }  
        
        if (oid != null) {
            batching = false;           
        } else {
            batching = true;
        }
    }
    
    public PageReference startAction() {
        PageReference ref;
        if (oid != null) {
            
            // run the rollup for the specified object
            GW_OppRollups rg = new GW_OppRollups();
            if (objectId.startsWith('001'))
                rg.RollupAccount(oid);
            else if (objectId.startsWith('003'))
                rg.RollupContact(oid);
            else 
                rg.RollupHousehold(oid);
                 
            ref = new PageReference('/' + oid);
            ref.setRedirect(true);
        }
        return ref;
    }

    public PageReference rollup() {
        
        // run batch rollup
        GW_OppRollups rg = new GW_OppRollups();
        rg.rollupAll();
        
        batchRunning = true;
        return null;                
    }

    public PageReference cancel() {
        PageReference ref = new PageReference('/home/home.jsp');
        ref.setRedirect(true);
        return ref;
    }

    // TEST METHOD
    public static testMethod void testRollup() {

        Date datClose = System.Today();
            
        // create & insert contact(s)
        Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( 100 ) ;
        insert TestCons;

        // create new opps
        Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Closed Won', datClose, 1000 , ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS ,null);

        account testacct = new account(name='testacct');
        insert testacct;

        Test.startTest();

        // create the page 
        PageReference pageRef=Page.OpportunityRollup; 
        Test.setCurrentPage(pageRef); 

        // set the parameter for the contact
        ApexPages.currentPage().getParameters().put('id', testcons[3].id);
        
        // instantiate the controller
        GW_CTRL_OppRollup controller=new GW_CTRL_OppRollup();

        // rollup the contact
        pageReference nextref = controller.startAction();       

        system.assert(nextref.getUrl().contains(testcons[3].id));
        
        // roll up everyone
        controller.rollup();
        controller.cancel();
    }
}