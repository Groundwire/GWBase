// Written by Dave Habib, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

global with sharing class GW_Utilities { 
	
	//---------------------------------------------------------------------------------------------
	// track whether we are running in our managed packaged, or unmanaged code.
	//---------------------------------------------------------------------------------------------
	private static boolean fCheckedForManagedPackage = false;
	global static boolean InManagedPackage {
		get {
			if (!fCheckedForManagedPackage) {
				Schema.DescribeSObjectResult r = ONEN_Household__c.SObjectType.getDescribe();
				// if we are running in managed scope, the local name won't have the prefix, but the name will.
				InManagedPackage = (r.getName() != r.getLocalName());  
				fCheckedForManagedPackage = true;				
			}
			return InManagedPackage;			
		}
		set;
	}
	
	
	//---------------------------------------------------------------------------------------------
	// utility to detect DupBlocker, so we can avoid tests that fail with DupBlocker installed.
	//---------------------------------------------------------------------------------------------
	private static boolean fCheckedForDupBlocker = false;
	global static boolean IsDupBlockerInstalled {
		get {
			if (!fCheckedForDupBlocker) {
				Schema.SObjectType token = Schema.getGlobalDescribe().get('CRMfusionDBR101__Setting__c');
				IsDupBlockerInstalled = (token != null);
				fCheckedForDupBlocker = true;
			}
			return IsDupBlockerInstalled;
		}
		set;
	}
	

	//---------------------------------------------------------------------------------------------
	// if we are in a managed package, tokens in dynamic SOQL must include the package namespace prefix
	// if you ever deploy this package as unmanaged to a client, this routine will do nothing!
	//---------------------------------------------------------------------------------------------
	global static string StrTokenNSPrefix(string str) {
		if (!InManagedPackage) return str;
		if (str.endsWith('__c')) {
			str = 'GWBase__' + str;
		}
		return str;
	}
	
	
	//---------------------------------------------------------------------------------------------
	// if we are in a managed package, tokens in dynamic SOQL must include the package namespace prefix
	// if you ever deploy this package as unmanaged to a client, this routine will do nothing!
	//---------------------------------------------------------------------------------------------
	global static string StrAllNSPrefix(string str) {
		if (!InManagedPackage) return str;
		Pattern pat = Pattern.Compile('[a-zA-z0-9]*__c');
		Matcher match = pat.matcher(str);
		return match.replaceAll('GWBase__$0');
	}
	
	
	//---------------------------------------------------------------------------------------------
	// routine to lookup a reportId given its Developer Name.
	//---------------------------------------------------------------------------------------------
	global static ID reportIdFromDevName(string strDevName) { 
		Id reportId = null;
		Report[] rpts = [select Id from Report where DeveloperName = :strDevName];
		if (!rpts.isEmpty()) reportId = rpts[0].Id;
		return reportId;
	}
	
	
	
	//---------------------------------------------------------------------------------------------
	// TEST CODE
	//---------------------------------------------------------------------------------------------

	static testmethod void TestNamespacePrefixFixups() {
		if (InManagedPackage) {
			system.assertEquals('foo', GW_Utilities.StrTokenNSPrefix('foo'));
			system.assertEquals('GWBase__foo__c', GW_Utilities.StrTokenNSPrefix('foo__c'));		
			system.assertEquals('foo', GW_Utilities.StrAllNSPrefix('foo'));
			system.assertEquals('GWBase__foo__c', GW_Utilities.StrAllNSPrefix('foo__c'));
			system.assertEquals('GWBase__foo_bar_baz__c', GW_Utilities.StrAllNSPrefix('foo_bar_baz__c'));
			system.assertEquals('select GWBase__foo__c, bar, GWBase__baz1__c, GWBase__biz_buz__c from Contact', GW_Utilities.StrAllNSPrefix('select foo__c, bar, baz1__c, biz_buz__c from Contact'));
		} else {
			system.assertEquals('foo', GW_Utilities.StrTokenNSPrefix('foo'));
			system.assertEquals('foo__c', GW_Utilities.StrTokenNSPrefix('foo__c'));		
			system.assertEquals('foo', GW_Utilities.StrAllNSPrefix('foo'));
			system.assertEquals('foo__c', GW_Utilities.StrAllNSPrefix('foo__c'));
			system.assertEquals('foo_bar_baz__c', GW_Utilities.StrAllNSPrefix('foo_bar_baz__c'));
			system.assertEquals('select foo__c, bar, baz1__c, biz_buz__c from Contact', GW_Utilities.StrAllNSPrefix('select foo__c, bar, baz1__c, biz_buz__c from Contact'));			
		}		
	}	 			

}