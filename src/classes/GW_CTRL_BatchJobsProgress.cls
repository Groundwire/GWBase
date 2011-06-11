public class GW_CTRL_BatchJobsProgress {
/*-----------------------------------------------------------------------------------------------
* Written by Jason Venable, http://www.tehnrd.com/batch-apex-status-bar/ 
*
* This program is released under the GNU General Public License. http://www.gnu.org/licenses/
*
* Controller for component that displays progress for batch apex jobs 
-----------------------------------------------------------------------------------------------*/
 
    public List<BatchJob> batchJobs;
    public Integer numberOfJobs {get; set;}
    public String batchComponentLabel {get; set;}
 
    public List<BatchJob> getBatchJobs() {
        //Create new list of BatchJobs, a wrapper class that includes the job and percent complete.
        batchJobs = new List<BatchJob>();
 
        //If number of jobs was not defined, default to 20
        if(numberOfJobs== null || numberofJobs <= 0) {
            numberofJobs = 20;
        }
        
        if(batchComponentLabel== null) {
            batchComponentLabel = 'Batch Apex Jobs';
        }
 
        //Query the Batch apex jobs
        for(AsyncApexJob a : [select TotalJobItems, Status, NumberOfErrors, MethodName, JobType, JobItemsProcessed, Id, 
        							CreatedDate, CreatedById, CompletedDate, ApexClassId, ApexClass.Name 
        							From AsyncApexJob order by CreatedDate desc limit :numberOfJobs]) {
            Double itemsProcessed = a.JobItemsProcessed;
            Double totalItems = a.TotalJobItems;
 
            BatchJob j = new BatchJob();
            j.job = a;
 
            //Determine the pecent complete based on the number of batches complete
            if(a.status == 'Completed') {
            	j.percentComplete = 100;
            //Determine the pecent complete based on the number of batches complete
            } else if (totalItems == 0) {
                //A little check here as we don't want to divide by 0.
                j.percentComplete = 0;
            } else {
                j.percentComplete = ((itemsProcessed  / totalItems) * 100.0).intValue();
            }
 
            batchJobs.add(j);
        }
        return batchJobs;
    }
 
    //This is the wrapper class the includes the job itself and a value for the percent complete
    public Class BatchJob{
        public AsyncApexJob job {get; set;}
        public Integer percentComplete {get; set;}
    }
 
    //--------------------TEST METHOD------------------------
    static testMethod void batchStatusBarTest(){
        GW_CTRL_BatchJobsProgress controller = new GW_CTRL_BatchJobsProgress();
        controller.getBatchJobs();
    }
    
}