global class GW_SCHED_EngagementRollups implements Schedulable {
// Written by Matthew Scholtz, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
   
	global void execute(SchedulableContext SC) {
		
		EngagementTrackerSettings__c settings = EngagementTrackerSettings__c.getOrgDefaults();
		integer batchSize = 50;  // default
		if (settings.Batch_Size__c > 0) {
			batchSize = settings.Batch_Size__c.intvalue(); 
		}
		 
		GW_BATCH_EngagementRollup ladderBatch = new GW_BATCH_EngagementRollup(false);
		id batchinstanceid = database.executeBatch (ladderBatch, batchSize);  
	}
	
}