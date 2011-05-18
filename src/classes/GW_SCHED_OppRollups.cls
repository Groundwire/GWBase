global class GW_SCHED_OppRollups implements Schedulable {
// run nightly for snappy opp totals
// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
   
	global void execute(SchedulableContext SC) { 
		GW_OppRollups rg = new GW_OppRollups();
		rg.rollupAll();    
	}
	
}