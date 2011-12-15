// Written by Dave Habib, copyright (c) 2011 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*******************************************************************************************************
* @author David Habib
* @date 5/20/2011
* @description Class which holds static methods for common utilities, 
* such as detecting whether we are in a managed package, and some string helpers.
********************************************************************************************************/
global class GW_Utilities { 
	
	/******************************************************************************************************
	* @description boolean property which tracks whether we are running in our managed packaged, or unmanaged code.
	*******************************************************************************************************/	
	private static boolean fCheckedForManagedPackage = false;
	global static boolean InManagedPackage {
		get {
			if (!fCheckedForManagedPackage) {
				Schema.SObjectType token = Schema.getGlobalDescribe().get('ONEN_Household__c');				
				// if we are running in managed scope, the local name won't have the prefix, but the name will.
				InManagedPackage = (token != null);
				fCheckedForManagedPackage = true;				
			}
			return InManagedPackage;			
		}
		set;
	}
	
	
	/*******************************************************************************************************
	* @description boolean property to track whether DupBlocker is installed, so we can avoid tests that fail 
	* with DupBlocker installed.
	********************************************************************************************************/	
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
	
	/*******************************************************************************************************
	* @description boolean property to track whether NPSP Household package is installed, so we can use
	* their opportunity rollups with the Engagement Tracker code.
	********************************************************************************************************/	
	public static boolean IsNPSPHHInstalled {
		get {
			return false;
		}
	}
	
	/*******************************************************************************************************
	* @description boolean property to track whether GWBase package is installed, so we can use
	* their opportunity rollups with the Engagement Tracker code.
	********************************************************************************************************/	
	public static boolean IsGWBaseInstalled {
		get {
			return true;
		}
	}

	/*******************************************************************************************************
	* @description Static method that takes a string of a potential field name or object name.  
	* If it is a custom object (name ends with __c), it prepends the namespace prefix if required.
	* If we are in a managed package, tokens in dynamic SOQL must include the package namespace prefix.
	* If you ever deploy this package as unmanaged to a client, this routine will do nothing!
	* @param str token name 
	* @return token name, with namespace prefix, if required.
	********************************************************************************************************/
	global static string StrTokenNSPrefix(string str) {
		if (!InManagedPackage) return str;
		if (str.endsWith('__c')) {
			str = 'GWBase__' + str;
		}
		return str;
	}
	
	
	/*******************************************************************************************************
	* @description Static method that takes a string of a multiple potential field names or object names.  
	* If we are in a managed package, tokens in dynamic SOQL must include the package namespace prefix.
	* If you ever deploy this package as unmanaged to a client, this routine will do nothing!
	* @param str string that contains 0 or more token names 
	* @return same string with token names, namespace prefixed, if required.
	********************************************************************************************************/
	global static string StrAllNSPrefix(string str) {
		if (!InManagedPackage) return str;
		Pattern pat = Pattern.Compile('[a-zA-z0-9]*__c');
		Matcher match = pat.matcher(str);
		return match.replaceAll('GWBase__$0');
	}
	
	
	/*******************************************************************************************************
	* @description Static method to lookup a reportId given its Developer Name.  This is useful when creating
	* custom links and buttons in Salesforce, that want to load a report, without having to know its specific
	* id in the given Salesforce instance.
	* @param strDevName DeveloperName of the report 
	* @return reportId
	********************************************************************************************************/
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