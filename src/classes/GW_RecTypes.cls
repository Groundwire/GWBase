global class GW_RecTypes {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class is meant to allow for access to Record Type information from within other classes.
*
* It is called statically, and therefore will supply the same information to all calls made from
* within one transaction, or set of trigger calls. This is beneficial because this info should
* be the same for all calls in a transaction, and by calling it statically we reduce the calls
* that are made, making the total transaction more efficient
-----------------------------------------------------------------------------------------------*/
	
	//maps to hold the record type info
	private static Map<String, Schema.SObjectType> gd;
	private static Map<String,Map<Id,Schema.RecordTypeInfo>> recordTypesById = new Map<String,Map<Id,Schema.RecordTypeInfo>>();
	private static Map<String,Map<String,Schema.RecordTypeInfo>> recordTypesByName = new Map<String,Map<String,Schema.RecordTypeInfo>>();
		
	/*******************************************
	* Gets record type maps for a new object
	********************************************/
	static void fillMapsForObject(string objectName) {
		// get the object map the first time
		if (gd==null) gd = Schema.getGlobalDescribe();
		
		// get the object description
		if (gd.containsKey(objectName)) {
			Schema.DescribeSObjectResult d = gd.get(objectName).getDescribe();
			recordTypesByName.put(objectName, d.getRecordTypeInfosByName());
			recordTypesById.put(objectName, d.getRecordTypeInfosById());
		}
	}

	/*******************************************
	* Gives record type Id from a given record type name
	********************************************/
	global static Id GetRecordTypeId(String objectName, String RecordTypeName) {
		// make sure we have this object's record types mapped
		if (!recordTypesByName.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		// now grab and return the requested id	
		Map<String,Schema.RecordTypeInfo> rtMap = recordTypesByName.get(objectName);
		if (rtMap != null && rtMap.containsKey(RecordTypeName)) {
			return rtMap.get(RecordTypeName).getRecordTypeId();
		} else {
			return null;
		}
	}
		
	/*******************************************
	* Gives record type Name from a given record type Id
	********************************************/
	global static String GetRecordTypeName(String objectName, Id RecordTypeId) {
		// make sure we have this object's record types mapped
		if (!recordTypesById.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		// now grab and return the requested id
		Map<Id,Schema.RecordTypeInfo> rtMap = recordTypesById.get(objectName);
		if (rtMap != null && rtMap.containsKey(RecordTypeId)) {
			return rtMap.get(RecordTypeId).getName();
		} else {
			return null;
		}
	}
	
	/*******************************************
	* Gives a set of record type Ids from a given set of names
	********************************************/
	global static set<Id> GetRecordTypeIdSet(String objectName, set<string> RecordTypeNameSet) {
		set<Id> recordTypeIds = new set<Id>();

		// make sure we have this object's record types mapped
		if (!recordTypesByName.containsKey(objectName)) 
			fillMapsForObject(objectName);

		// fill the id set from the name set
		if (recordTypesByName.containsKey(objectName)) { 
			Map<String,Schema.RecordTypeInfo> rtMap = recordTypesByName.get(objectName);
			for (String recTypeName : RecordTypeNameSet) {
				if (rtMap.containsKey(recTypeName)) {
					recordTypeIds.add(rtMap.get(recTypeName).getRecordTypeId());
				}
			}
		}
		return recordTypeIds;
	}
	
	/*******************************************
	* Gives a map of record type Ids from a given set of names
	********************************************/
	global static Map<String, Id> GetRecordTypeIdMap(String objectName) {
		Map<String, Id> recordTypeMap = new Map<String, Id>();  
		// make sure we have this object's record types mapped
		if (!recordTypesByName.containsKey(objectName)) 
			fillMapsForObject(objectName);

		// fill the name to id map
		if (recordTypesByName.containsKey(objectName)) { 
			Map<String,Schema.RecordTypeInfo> rtMap = recordTypesByName.get(objectName);
			for (recordTypeInfo rti : rtMap.values()) {
				if (rti.getName() != 'Master')
					recordTypeMap.put(rti.getName(), rti.getRecordTypeId());
			}
		}
		
		return recordTypeMap;
	}

	/*******************************************
	* Gets record type naming suffix from record type name
	Removed from GWBase since static methods cannot be virtual, but
	client would need to be able to override this with their suffixes,
	if we felt we needed to support this functionality.
	
	global static String GetOppNamingSuffix(String RecordTypeName){
		Map<String,String> OpportunitySufix =  new Map<String,String>();

		//add overrides for naming suffixes
		//OpportunitySufix.put('Gift','Gift Suffix');

		String Suffix;
		Suffix = OpportunitySufix.get(RecordTypeName);
		return (Suffix==null) ? RecordTypeName : Suffix;	
	}
	********************************************/
	
	/****************************************************************
	* function to get a list of select options for a Visualforce picklist of record types. 
	*****************************************************************/
	global static List<SelectOption> getRecordTypesForSelectList(String objectName) {
		
   	 	List<SelectOption> recordTypesOptions = new List<SelectOption>();
		Map<String,Id> availRecordTypes = getRecordTypeIdMap(objectName);
		if (!availRecordTypes.isEmpty()) {
	 		for (string thisRecordType : availRecordTypes.keyset()) {
	 			recordTypesOptions.add(new SelectOption(availRecordTypes.get(thisRecordType), thisRecordType));	
	 		}
		}
   	 	return recordTypesOptions;
    }

	// TEST
	static testmethod void testRecTypes() {
		// try bogus values
		Id reallyBogus = GetRecordTypeId('Bogus', 'Bogus');
		System.assert(reallyBogus == null);
		Id bogus = GetRecordTypeId('Opportunity', 'Bogus');
		System.assert(bogus == null);
		bogus = GetRecordTypeId('Contact', 'Bogus');
		System.assert(bogus == null);
		bogus = GetRecordTypeId('Campaign', 'Bogus');
		System.assert(bogus == null);
		
		// try all the functions
		set<Id> oppRtSet = GetRecordTypeIdSet('Opportunity', (new set<string>{'Bogus', 'Master', 'Grant'}));
		Map<String, Id> oppTypeMap = GetRecordTypeIdMap('Opportunity');
		List<SelectOption> rtOptions = getRecordTypesForSelectList('Opportunity');
		//system.assertEquals('TestName',GetOppNamingSuffix('TestName'));
		
		// check against queried rectypes
		list<recordtype> ort = [select id, name from recordtype where isactive=true and sobjecttype='Opportunity' limit 1];
		if (!ort.isEmpty()) {
			Id rtId = GetRecordTypeId('Opportunity', ort[0].name);
			system.assertEquals(ort[0].id, rtId); 
			String rtName = GetRecordTypeName('Opportunity', ort[0].id);
			system.assertEquals(ort[0].name, rtName); 

			// the sets above should contain something too
			system.assert(oppRtSet.size() > 0);
			system.assert(oppTypeMap.size() > 0);
			system.assert(rtOptions.size() > 0);			
		}		
	}
	
	static testMethod void TestRecordTypes() {

		// we are willing to assume that Gift and Grant recordtypes always exist in our base.	

		ID idGift = GW_RecTypes.GetRecordTypeId('Opportunity', 'Gift' );
		ID idGrant = GW_RecTypes.GetRecordTypeId('Opportunity', 'Grant');
		system.Assert(idGift != idGrant);
		
		Set<String> setStr = new Set<String>{'Gift', 'Grant'};
		Set<Id> setId = GW_RecTypes.GetRecordTypeIdSet('Opportunity', setStr);
		system.Assert(setId.contains(idGift));
		system.Assert(setId.contains(idGrant));
		
		Map<String, Id> mapRCId = GW_RecTypes.GetRecordTypeIdMap('Opportunity');
		system.AssertEquals(idGift, mapRCId.get('Gift'));		
		system.AssertEquals(idGrant, mapRCId.get('Grant'));
		
		system.AssertEquals('Gift', GW_RecTypes.GetRecordTypeName('Opportunity', idGift));		
		system.AssertEquals('Grant', GW_RecTypes.GetRecordTypeName('Opportunity', idGrant));		
		
		//system.AssertEquals(rectype1, GW_RecTypes.GetOppNamingSuffix(rectype1));		

		List<SelectOption> listSO = GW_RecTypes.getRecordTypesForSelectList('Opportunity');
		system.Assert(listSO.IsEmpty() == false);		
	}		
}