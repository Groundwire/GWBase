public with sharing class GW_CTRL_HelpDocs {

    private string docsSiteUname;
    private string docsSitePwd;
    private final string DOCS_SITE_DOMAIN = 'http://salesforcehelp.groundwire.org';  //should this be a setting too?
    public string docsFullURL {get;set;} 
    
    // constructor
    public GW_CTRL_HelpDocs() {
        MiscellaneousBaseSettings__c settings = MiscellaneousBaseSettings__c.getOrgDefaults();
        if (settings!=null) {
            docsSiteUname = settings.GW_Help_Docs_Username__c;
            docsSitePwd = settings.GW_Help_Docs_Password__c;
        }
        if (docsSiteUname==null || docsSitePwd==null) {
            docsFullURL = DOCS_SITE_DOMAIN;
        } else {
            docsFullURL = DOCS_SITE_DOMAIN + '/login_form?__ac_name=' + docsSiteUname + '&__ac_password=' + docsSitePwd + '&form.submitted=1&came_from=http://salesforcehelp.groundwire.org/documentation/';
        }
    }
    


    static testmethod void testHelpDocsController() {
        
        GW_CTRL_HelpDocs ctrl = new GW_CTRL_HelpDocs();
        string url = ctrl.docsFullURL;
        
        
    }

}