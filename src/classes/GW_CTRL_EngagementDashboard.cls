public with sharing class GW_CTRL_EngagementDashboard {


	// public list<sobject> aggResults {get;set;}
	public list<aggEngagementRow> rows {get;set;}

	// constructor
	public GW_CTRL_EngagementDashboard () {
		this.rows = new list<aggEngagementRow>();
		queryEngagementCounts();
		
	}
	
	
	public void queryEngagementCounts () {
		
		list<sObject> results;
		
		results = [Select Engagement_Level__c Level, COUNT_DISTINCT(Id) TotalCount 
			FROM Contact WHERE Engagement_Level_Numeric__c > 0 
			GROUP BY Engagement_Level__c];
			
		// aggResults = results;
		
		for (sobject result:results) {
			aggEngagementRow row = new aggEngagementRow();
			row.levelName = (string) result.get('Level');
			row.countCons = (integer) result.get('TotalCount');
			rows.add(row);
		}
		
	}
	
	
	//wrapper class
	public class aggEngagementRow {
		
		public string levelName {get;set;}
		public integer countCons {get;set;} 
		
	}
	

}